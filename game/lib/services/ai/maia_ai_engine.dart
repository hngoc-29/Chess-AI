import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
// pub.dev lists the package as lowercase `leela_chess_zero` (pub.dev
// enforces lowercase package names), but the package's own README shows
// `import 'package:LeelaChessZero/lc0.dart';`. If this import fails to
// resolve after `flutter pub get`, try the capitalized form instead -
// check the installed package's `lib/` folder under
// .pub-cache/hosted/pub.dev/leela_chess_zero-*/lib/ to see which file
// actually exists.
import 'package:leela_chess_zero/lc0.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/fen_utils.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/board.dart';
import '../../domain/entities/chess_move.dart';
import '../../domain/entities/piece.dart';
import '../../domain/entities/position.dart';
import '../../domain/entities/settings.dart';
import '../game/chess_rules_service.dart';
import 'chess_ai_engine.dart';

/// Which Maia network (rated Elo strength) and how many MCTS nodes to use
/// for a given [AIDifficulty]. Maia networks are trained to imitate human
/// play at a specific rating and are meant to be used with `nodes = 1`
/// (i.e. no search) - see https://github.com/CSSLab/maia-chess.
///
/// For [AIDifficulty.expert] we reuse the strongest bundled net
/// (maia-1900) but let it search many more nodes, which pushes it well
/// past "plays like a 1900" and into "hard to beat" territory, without
/// needing to bundle an extra, larger, non-human network.
class _MaiaProfile {
  final String weightsAsset;
  final int nodes;
  const _MaiaProfile(this.weightsAsset, this.nodes);
}

const Map<AIDifficulty, _MaiaProfile> _kMaiaProfiles = {
  AIDifficulty.beginner: _MaiaProfile('maia-1100.pb.gz', 1),
  AIDifficulty.easy: _MaiaProfile('maia-1300.pb.gz', 1),
  AIDifficulty.medium: _MaiaProfile('maia-1500.pb.gz', 1),
  AIDifficulty.hard: _MaiaProfile('maia-1700.pb.gz', 1),
  AIDifficulty.veryHard: _MaiaProfile('maia-1900.pb.gz', 1),
  AIDifficulty.expert: _MaiaProfile('maia-1900.pb.gz', 800),
};

/// Drop-in replacement for [ChessAIEngine] that plays using the Maia
/// human-like neural networks, run through the bundled `lc0` engine
/// (via the `leela_chess_zero` plugin).
///
/// If the native engine fails to start for any reason (unsupported
/// device ABI, plugin not installed correctly, etc.) this transparently
/// falls back to the original minimax engine so the game never gets
/// stuck without an opponent.
class MaiaAIEngine extends ChessAIEngine {
  MaiaAIEngine(ChessRulesService rulesService) : super(rulesService);

  Lc0? _engine;
  Future<Lc0>? _engineStartup;
  String? _loadedWeightsAsset;
  bool _permanentlyUnavailable = false;

  Future<Lc0> _ensureEngine() {
    if (_permanentlyUnavailable) {
      throw StateError('Maia engine marked unavailable on this device');
    }
    if (_engine != null) return Future.value(_engine!);
    return _engineStartup ??= _startEngine();
  }

  Future<Lc0> _startEngine() async {
    final engine = await lc0Async().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('lc0 engine did not start in time'),
    );
    engine.stdin = 'uci';
    _engine = engine;
    return engine;
  }

  /// Copies the requested Maia weights file out of the app bundle into a
  /// real path on disk the native engine can open, the first time it's
  /// needed. Subsequent calls reuse the cached copy.
  Future<String> _weightsPathFor(String assetFileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final destFile = File('${dir.path}/maia_weights/$assetFileName');

    if (!await destFile.exists()) {
      await destFile.parent.create(recursive: true);
      final data = await rootBundle.load('assets/weights/$assetFileName');
      await destFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    return destFile.path;
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
  }) async {
    try {
      final profile = _kMaiaProfiles[difficulty] ?? _kMaiaProfiles[AIDifficulty.medium]!;
      final engine = await _ensureEngine();

      if (_loadedWeightsAsset != profile.weightsAsset) {
        final weightsPath = await _weightsPathFor(profile.weightsAsset);
        engine.stdin = 'setoption name WeightsFile value $weightsPath';
        await _waitForReadyOk(engine);
        _loadedWeightsAsset = profile.weightsAsset;
      }

      final fen = boardToFen(
        board,
        color,
        whiteCanCastleK: whiteCanCastleKingside,
        whiteCanCastleQ: whiteCanCastleQueenside,
        blackCanCastleK: blackCanCastleKingside,
        blackCanCastleQ: blackCanCastleQueenside,
        enPassant: enPassantSquare,
        halfMove: halfMoveClock,
        fullMove: fullMoveNumber,
      );

      final bestMoveUci = await _requestBestMove(engine, fen, profile.nodes);
      return _parseUciMove(bestMoveUci);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Maia engine unavailable, falling back to local minimax AI',
        e,
        stackTrace,
      );
      // Avoid retrying a broken native engine on every single move.
      _permanentlyUnavailable = true;
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

  /// UCI handshake: confirms the engine has actually finished loading the
  /// network we just pointed it at before we ask it to search a position.
  Future<void> _waitForReadyOk(Lc0 engine) {
    final completer = Completer<void>();
    late final StreamSubscription<String> sub;

    sub = engine.stdout.listen((line) {
      if (line.trim() == 'readyok') {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      }
    });

    engine.stdin = 'isready';

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('Maia engine did not confirm readyok in time');
      },
    );
  }

  Future<String> _requestBestMove(Lc0 engine, String fen, int nodes) {
    final completer = Completer<String>();
    late final StreamSubscription<String> sub;

    sub = engine.stdout.listen((line) {
      if (line.startsWith('bestmove')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 && !completer.isCompleted) {
          completer.complete(parts[1]);
        }
        sub.cancel();
      }
    });

    engine.stdin = 'position fen $fen';
    engine.stdin = 'go nodes $nodes';

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('Maia engine did not reply with bestmove in time');
      },
    );
  }

  ChessMove _parseUciMove(String uci) {
    if (uci == '(none)' || uci.length < 4) {
      throw FormatException('Invalid UCI move from Maia engine: "$uci"');
    }

    final from = Position.fromAlgebraic(uci.substring(0, 2));
    final to = Position.fromAlgebraic(uci.substring(2, 4));

    PieceType? promotion;
    if (uci.length >= 5) {
      const promotionChars = {
        'q': PieceType.queen,
        'r': PieceType.rook,
        'b': PieceType.bishop,
        'n': PieceType.knight,
      };
      promotion = promotionChars[uci[4].toLowerCase()];
    }

    return ChessMove(from: from, to: to, promotion: promotion);
  }

  /// Releases the native engine process. Safe to call even if the engine
  /// was never started.
  void dispose() {
    _engine?.dispose();
    _engine = null;
    _engineStartup = null;
    _loadedWeightsAsset = null;
  }
}
