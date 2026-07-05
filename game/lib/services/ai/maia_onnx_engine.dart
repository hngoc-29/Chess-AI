import 'dart:math';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/chess_move.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/settings.dart';
import '../../../core/utils/logger.dart';
import '../../game/chess_rules_service.dart';
import '../chess_ai_engine.dart';
import 'maia/maia_board_encoder.dart';
import 'maia/maia_move_index.dart';
import 'maia/maia_position_snapshot.dart';

/// Which Maia network (rated Elo strength) to use for a given difficulty.
/// Maia networks are trained to imitate human play at a specific rating;
/// unlike a traditional engine, playing them with search would work
/// against their whole design, so we always use a single forward pass
/// (their designed use case - see https://github.com/CSSLab/maia-chess)
/// and pick the move by sampling from the resulting policy distribution.
///
/// There's no "expert / deeper search" tier in this version: the previous
/// lc0-based implementation could ask the search engine for more nodes,
/// but running raw ONNX inference has no search of its own to lean on.
/// [AIDifficulty.expert] currently reuses the 1900 net with the sampling
/// temperature lowered instead (more consistently picks its top choice,
/// closer to "this net's strongest self" than to genuine deep search).
/// A real replacement (e.g. a small minimax on top of the value head)
/// is a reasonable future enhancement - see game/docs/maia_integration.md.
const Map<AIDifficulty, String> _kMaiaAsset = {
  AIDifficulty.beginner: 'assets/onnx/maia-1100.onnx',
  AIDifficulty.easy: 'assets/onnx/maia-1300.onnx',
  AIDifficulty.medium: 'assets/onnx/maia-1500.onnx',
  AIDifficulty.hard: 'assets/onnx/maia-1700.onnx',
  AIDifficulty.veryHard: 'assets/onnx/maia-1900.onnx',
  AIDifficulty.expert: 'assets/onnx/maia-1900.onnx',
};

/// Softmax temperature applied to the legal-move policy distribution
/// before sampling a move. Lower = more consistently picks the top move,
/// higher = more variety. 1.0 reproduces Maia's own training distribution
/// as-is.
const Map<AIDifficulty, double> _kSamplingTemperature = {
  AIDifficulty.beginner: 1.0,
  AIDifficulty.easy: 1.0,
  AIDifficulty.medium: 1.0,
  AIDifficulty.hard: 1.0,
  AIDifficulty.veryHard: 1.0,
  AIDifficulty.expert: 0.3,
};

/// Drop-in replacement for [ChessAIEngine] that plays using the Maia
/// human-like neural networks, run directly via ONNX Runtime (no external
/// engine process, no UCI, no native subprocess).
///
/// Falls back to the original minimax engine if a model fails to load or
/// inference throws, so the game never gets stuck without an opponent.
class MaiaOnnxEngine extends ChessAIEngine {
  MaiaOnnxEngine(ChessRulesService rulesService)
      : _rules = rulesService,
        super(rulesService);

  final ChessRulesService _rules;
  final OnnxRuntime _ort = OnnxRuntime();
  final Map<String, OrtSession> _sessions = {};
  MaiaMoveIndex? _moveIndex;
  final Random _random = Random();

  Future<OrtSession> _sessionFor(String assetPath) async {
    final cached = _sessions[assetPath];
    if (cached != null) return cached;
    final session = await _ort.createSessionFromAsset(assetPath);
    _sessions[assetPath] = session;
    return session;
  }

  Future<MaiaMoveIndex> _ensureMoveIndex() async {
    return _moveIndex ??= await MaiaMoveIndex.load();
  }

  @override
  Future<ChessMove> getBestMove({
    required Board board,
    required PieceColor color,
    required AIDifficulty difficulty,
    required bool whiteCanCastleKingside,
    required bool whiteCanCastleQueenside,
    required bool blackCanCastleKingside,
    required bool blackCanCastleQueenside,
    required String? enPassantSquare,
    int halfMoveClock = 0,
    int fullMoveNumber = 1,
    List<MaiaPositionSnapshot>? history,
  }) async {
    try {
      final effectiveHistory = (history != null && history.isNotEmpty)
          ? history
          : [
              MaiaPositionSnapshot(
                board: board,
                currentTurn: color,
                whiteCanCastleKingside: whiteCanCastleKingside,
                whiteCanCastleQueenside: whiteCanCastleQueenside,
                blackCanCastleKingside: blackCanCastleKingside,
                blackCanCastleQueenside: blackCanCastleQueenside,
                enPassantSquare: enPassantSquare,
                halfMoveClock: halfMoveClock,
              ),
            ];

      final legalMoves = _enumerateLegalMoves(
        board: board,
        color: color,
        whiteCanCastleKingside: whiteCanCastleKingside,
        whiteCanCastleQueenside: whiteCanCastleQueenside,
        blackCanCastleKingside: blackCanCastleKingside,
        blackCanCastleQueenside: blackCanCastleQueenside,
        enPassantSquare: enPassantSquare,
      );
      if (legalMoves.isEmpty) {
        throw StateError('No legal moves available for Maia to choose from');
      }

      final assetPath = _kMaiaAsset[difficulty] ?? _kMaiaAsset[AIDifficulty.medium]!;
      final session = await _sessionFor(assetPath);
      final moveIndex = await _ensureMoveIndex();

      final inputData = MaiaBoardEncoder.encode(effectiveHistory);
      final inputTensor = await OrtValue.fromList(
        inputData,
        [1, MaiaBoardEncoder.planeCount, MaiaBoardEncoder.boardSize, MaiaBoardEncoder.boardSize],
      );

      final outputs = await session.run({'/input/planes': inputTensor});
      await inputTensor.dispose();

      final policyFlat = (await outputs['/output/policy']!.asFlattenedList()).cast<num>();
      for (final tensor in outputs.values) {
        await tensor.dispose();
      }

      final whiteToMove = color == PieceColor.white;
      final usHasAnyCastlingRights = whiteToMove
          ? (whiteCanCastleKingside || whiteCanCastleQueenside)
          : (blackCanCastleKingside || blackCanCastleQueenside);

      final legalUci = legalMoves.map((m) => m.toAlgebraic()).toList();
      final indices = moveIndex.indicesFor(
        legalUci,
        whiteToMove: whiteToMove,
        usHasAnyCastlingRights: usHasAnyCastlingRights,
      );

      final temperature = _kSamplingTemperature[difficulty] ?? 1.0;
      final logits = indices.map((i) => policyFlat[i].toDouble() / temperature).toList();
      final probabilities = MaiaMoveIndex.softmax(logits);

      final chosenIndex = _sampleFromDistribution(probabilities);
      return legalMoves[chosenIndex];
    } catch (e, stackTrace) {
      AppLogger.error(
        'Maia ONNX inference failed, falling back to local minimax AI',
        e,
        stackTrace,
      );
      return super.getBestMove(
        board: board,
        color: color,
        difficulty: difficulty,
        whiteCanCastleKingside: whiteCanCastleKingside,
        whiteCanCastleQueenside: whiteCanCastleQueenside,
        blackCanCastleKingside: blackCanCastleKingside,
        blackCanCastleQueenside: blackCanCastleQueenside,
        enPassantSquare: enPassantSquare,
      );
    }
  }

  int _sampleFromDistribution(List<double> probabilities) {
    final r = _random.nextDouble();
    double cumulative = 0.0;
    for (int i = 0; i < probabilities.length; i++) {
      cumulative += probabilities[i];
      if (r <= cumulative) return i;
    }
    return probabilities.length - 1; // floating point safety net
  }

  /// Enumerates every legal move for [color], expanding pawn promotions
  /// into their 4 distinct piece choices (queen/rook/bishop/knight) since
  /// Maia's policy output scores them as genuinely separate moves.
  List<ChessMove> _enumerateLegalMoves({
    required Board board,
    required PieceColor color,
    required bool whiteCanCastleKingside,
    required bool whiteCanCastleQueenside,
    required bool blackCanCastleKingside,
    required bool blackCanCastleQueenside,
    required String? enPassantSquare,
  }) {
    final moves = <ChessMove>[];
    final promotionRank = color == PieceColor.white ? 7 : 0;

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final from = Position(file: file, rank: rank);
        final piece = board.pieceAt(from);
        if (piece == null || piece.color != color) continue;

        final destinations = _rules.getLegalMoves(
          board,
          from,
          whiteCanCastleKingside: whiteCanCastleKingside,
          whiteCanCastleQueenside: whiteCanCastleQueenside,
          blackCanCastleKingside: blackCanCastleKingside,
          blackCanCastleQueenside: blackCanCastleQueenside,
          enPassantSquare: enPassantSquare,
        );

        for (final to in destinations) {
          if (piece.type == PieceType.pawn && to.rank == promotionRank) {
            for (final promo in const [
              PieceType.queen,
              PieceType.rook,
              PieceType.bishop,
              PieceType.knight,
            ]) {
              moves.add(ChessMove(from: from, to: to, promotion: promo));
            }
          } else {
            moves.add(ChessMove(from: from, to: to));
          }
        }
      }
    }
    return moves;
  }

  /// Releases all cached ONNX sessions. Safe to call even if none were
  /// ever created.
  Future<void> dispose() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }
}
