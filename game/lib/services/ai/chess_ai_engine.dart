import 'dart:math';

import 'package:kings_gambit_ai/domain/entities/board.dart';
import 'package:kings_gambit_ai/domain/entities/chess_move.dart';
import 'package:kings_gambit_ai/domain/entities/piece.dart';
import 'package:kings_gambit_ai/domain/entities/position.dart';
import 'package:kings_gambit_ai/domain/entities/settings.dart';
import 'package:kings_gambit_ai/services/game/chess_rules_service.dart';

/// Advanced Chess AI Engine with Minimax and Alpha-Beta Pruning
class ChessAIEngine {
  final ChessRulesService _rulesService;
  final Random _random = Random();

  ChessAIEngine(this._rulesService);

  /// Get the best move for the current position
  Future<ChessMove> getBestMove({
    required Board board,
    required PieceColor color,
    required AIDifficulty difficulty,
    required bool whiteCanCastleKingside,
    required bool whiteCanCastleQueenside,
    required bool blackCanCastleKingside,
    required bool blackCanCastleQueenside,
    required String? enPassantSquare,
    // Unused by this local minimax engine, but part of the shared
    // interface so callers can pass full FEN context to subclasses
    // (e.g. MaiaAIEngine) without caring about the runtime type.
    int halfMoveClock = 0,
    int fullMoveNumber = 1,
  }) async {
    // Add thinking delay based on difficulty
    final thinkingTime = _getThinkingTime(difficulty);
    await Future.delayed(thinkingTime);

    final depth = _getSearchDepth(difficulty);
    final allMoves = _getAllLegalMoves(
      board,
      color,
      whiteCanCastleKingside,
      whiteCanCastleQueenside,
      blackCanCastleKingside,
      blackCanCastleQueenside,
      enPassantSquare,
    );

    if (allMoves.isEmpty) {
      throw Exception('No legal moves available');
    }

    // For easy difficulty, just pick a random move
    if (difficulty == AIDifficulty.easy) {
      return allMoves[_random.nextInt(allMoves.length)];
    }

    // For medium and above, use minimax with alpha-beta pruning
    ChessMove? bestMove;
    double bestScore = double.negativeInfinity;

    // Add some randomness for medium difficulty
    final useRandomness = difficulty == AIDifficulty.medium;

    for (final move in allMoves) {
      final newBoard = _makeMove(board, move);
      final score = -_minimax(
        newBoard,
        depth - 1,
        double.negativeInfinity,
        double.infinity,
        color == PieceColor.white ? PieceColor.black : PieceColor.white,
        whiteCanCastleKingside,
        whiteCanCastleQueenside,
        blackCanCastleKingside,
        blackCanCastleQueenside,
        enPassantSquare,
      );

      // Add randomness for medium difficulty
      final adjustedScore = useRandomness
          ? score + (_random.nextDouble() - 0.5) * 0.5
          : score;

      if (adjustedScore > bestScore) {
        bestScore = adjustedScore;
        bestMove = move;
      }
    }

    return bestMove ?? allMoves[0];
  }

  /// Minimax algorithm with alpha-beta pruning
  double _minimax(
    Board board,
    int depth,
    double alpha,
    double beta,
    PieceColor color,
    bool whiteCanCastleKingside,
    bool whiteCanCastleQueenside,
    bool blackCanCastleKingside,
    bool blackCanCastleQueenside,
    String? enPassantSquare,
  ) {
    // Base case: reached max depth or game over
    if (depth == 0) {
      return evaluatePosition(board, color);
    }

    // Check for checkmate or stalemate
    if (_rulesService.isCheckmate(board, color)) {
      return -10000.0 + depth; // Prefer faster checkmates
    }
    if (_rulesService.isStalemate(board, color)) {
      return 0.0;
    }

    final moves = _getAllLegalMoves(
      board,
      color,
      whiteCanCastleKingside,
      whiteCanCastleQueenside,
      blackCanCastleKingside,
      blackCanCastleQueenside,
      enPassantSquare,
    );

    if (moves.isEmpty) {
      return 0.0;
    }

    double maxScore = double.negativeInfinity;

    for (final move in moves) {
      final newBoard = _makeMove(board, move);
      final score = -_minimax(
        newBoard,
        depth - 1,
        -beta,
        -alpha,
        color == PieceColor.white ? PieceColor.black : PieceColor.white,
        whiteCanCastleKingside,
        whiteCanCastleQueenside,
        blackCanCastleKingside,
        blackCanCastleQueenside,
        enPassantSquare,
      );

      maxScore = max(maxScore, score);
      alpha = max(alpha, score);

      // Alpha-beta pruning
      if (alpha >= beta) {
        break;
      }
    }

    return maxScore;
  }

  /// Evaluate the position from the perspective of the given color
  /// Returns a score where positive values favor the given color
  double evaluatePosition(Board board, PieceColor color) {
    double score = 0.0;

    // Material evaluation
    score += _evaluateMaterial(board, color);

    // Positional evaluation
    score += _evaluatePositional(board, color);

    // Mobility evaluation
    score += _evaluateMobility(board, color);

    // King safety
    score += _evaluateKingSafety(board, color);

    return score;
  }

  /// Evaluate material balance
  double _evaluateMaterial(Board board, PieceColor color) {
    double score = 0.0;

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = board.pieceAt(Position(file: file, rank: rank));
        if (piece != null) {
          final value = _getPieceValue(piece.type);
          if (piece.color == color) {
            score += value;
          } else {
            score -= value;
          }
        }
      }
    }

    return score;
  }

  /// Evaluate positional factors
  double _evaluatePositional(Board board, PieceColor color) {
    double score = 0.0;

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final position = Position(file: file, rank: rank);
        final piece = board.pieceAt(position);
        if (piece != null) {
          final positionValue = _getPositionValue(piece, position);
          if (piece.color == color) {
            score += positionValue;
          } else {
            score -= positionValue;
          }
        }
      }
    }

    return score;
  }

  /// Evaluate mobility (number of legal moves)
  double _evaluateMobility(Board board, PieceColor color) {
    int myMoves = 0;
    int opponentMoves = 0;

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final position = Position(file: file, rank: rank);
        final piece = board.pieceAt(position);
        if (piece != null) {
          final moves = _rulesService.getLegalMoves(board, position);
          if (piece.color == color) {
            myMoves += moves.length;
          } else {
            opponentMoves += moves.length;
          }
        }
      }
    }

    return (myMoves - opponentMoves) * 0.1;
  }

  /// Evaluate king safety
  double _evaluateKingSafety(Board board, PieceColor color) {
    double score = 0.0;

    // Find king positions
    final myKing = board.findKing(color);
    final opponentKing = board.findKing(
      color == PieceColor.white ? PieceColor.black : PieceColor.white,
    );

    if (myKing != null) {
      // Penalize exposed king
      if (_rulesService.isInCheck(board, color)) {
        score -= 0.5;
      }
    }

    if (opponentKing != null) {
      // Bonus for attacking opponent king
      final opponentColor = color == PieceColor.white ? PieceColor.black : PieceColor.white;
      if (_rulesService.isInCheck(board, opponentColor)) {
        score += 0.5;
      }
    }

    return score;
  }

  /// Get piece value
  double _getPieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 1.0;
      case PieceType.knight:
        return 3.0;
      case PieceType.bishop:
        return 3.2;
      case PieceType.rook:
        return 5.0;
      case PieceType.queen:
        return 9.0;
      case PieceType.king:
        return 0.0; // King has infinite value, handled separately
    }
  }

  /// Get position value bonus
  double _getPositionValue(Piece piece, Position position) {
    // Center control bonus
    final centerDistance = ((position.file - 3.5).abs() + (position.rank - 3.5).abs()) / 2;
    double score = (3.5 - centerDistance) * 0.05;

    // Piece-specific bonuses
    if (piece.isPawn) {
      // Pawns are stronger when advanced
      final advancementRank = piece.isWhite ? position.rank : (7 - position.rank);
      score += advancementRank * 0.1;
    } else if (piece.isKnight || piece.isBishop) {
      // Knights and bishops prefer center
      score += (3.5 - centerDistance) * 0.1;
    }

    return score;
  }

  /// Get all legal moves for a color
  List<ChessMove> _getAllLegalMoves(
    Board board,
    PieceColor color,
    bool whiteCanCastleKingside,
    bool whiteCanCastleQueenside,
    bool blackCanCastleKingside,
    bool blackCanCastleQueenside,
    String? enPassantSquare,
  ) {
    final moves = <ChessMove>[];

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final from = Position(file: file, rank: rank);
        final piece = board.pieceAt(from);
        if (piece != null && piece.color == color) {
          final legalMoves = _rulesService.getLegalMoves(
            board,
            from,
            whiteCanCastleKingside: whiteCanCastleKingside,
            whiteCanCastleQueenside: whiteCanCastleQueenside,
            blackCanCastleKingside: blackCanCastleKingside,
            blackCanCastleQueenside: blackCanCastleQueenside,
            enPassantSquare: enPassantSquare,
          );
          for (final to in legalMoves) {
            moves.add(ChessMove(from: from, to: to));
          }
        }
      }
    }

    return moves;
  }

  /// Make a move and return new board
  Board _makeMove(Board board, ChessMove move) {
    return board.movePiece(move.from, move.to);
  }

  /// Get search depth based on difficulty
  int _getSearchDepth(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.beginner:
        return 1;
      case AIDifficulty.easy:
        return 1;
      case AIDifficulty.medium:
        return 2;
      case AIDifficulty.hard:
        return 3;
      case AIDifficulty.veryHard:
        return 4;
      case AIDifficulty.expert:
        return 4;
    }
  }

  /// Get thinking time based on difficulty
  Duration _getThinkingTime(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.beginner:
        return const Duration(milliseconds: 300);
      case AIDifficulty.easy:
        return const Duration(milliseconds: 500);
      case AIDifficulty.medium:
        return const Duration(milliseconds: 1000);
      case AIDifficulty.hard:
        return const Duration(milliseconds: 1500);
      case AIDifficulty.veryHard:
        return const Duration(milliseconds: 1800);
      case AIDifficulty.expert:
        return const Duration(milliseconds: 2000);
    }
  }
}
