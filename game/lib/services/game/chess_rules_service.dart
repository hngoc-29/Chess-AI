import 'package:chess_ai/domain/entities/board.dart';
import 'package:chess_ai/domain/entities/move_info.dart';
import 'package:chess_ai/domain/entities/piece.dart';
import 'package:chess_ai/domain/entities/position.dart';

class ChessRulesService {
  List<Position> getLegalMoves(Board board, Position from, {
    bool whiteCanCastleKingside = true,
    bool whiteCanCastleQueenside = true,
    bool blackCanCastleKingside = true,
    bool blackCanCastleQueenside = true,
    String? enPassantSquare,
  }) {
    final piece = board.pieceAt(from);
    if (piece == null) return [];

    List<Position> moves;
    switch (piece.type) {
      case PieceType.pawn:
        moves = _getPawnMoves(board, from, piece.color, enPassantSquare);
        break;
      case PieceType.knight:
        moves = _getKnightMoves(board, from, piece.color);
        break;
      case PieceType.bishop:
        moves = _getBishopMoves(board, from, piece.color);
        break;
      case PieceType.rook:
        moves = _getRookMoves(board, from, piece.color);
        break;
      case PieceType.queen:
        moves = _getQueenMoves(board, from, piece.color);
        break;
      case PieceType.king:
        moves = _getKingMoves(board, from, piece.color);
        moves.addAll(_getCastlingMoves(
          board,
          from,
          piece.color,
          whiteCanCastleKingside,
          whiteCanCastleQueenside,
          blackCanCastleKingside,
          blackCanCastleQueenside,
        ));
        break;
    }

    return moves.where((to) => !_wouldBeInCheck(board, from, to, piece.color)).toList();
  }

  bool isMoveLegal(Board board, Position from, Position to) {
    return getLegalMoves(board, from).contains(to);
  }

  bool isInCheck(Board board, PieceColor color) {
    final kingPos = board.findKing(color);
    if (kingPos == null) return false;

    final opponentColor = color == PieceColor.white ? PieceColor.black : PieceColor.white;

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.pieceAt(pos);
        if (piece != null && piece.color == opponentColor) {
          final attacks = _getPieceAttacks(board, pos, piece);
          if (attacks.contains(kingPos)) return true;
        }
      }
    }

    return false;
  }

  bool isCheckmate(Board board, PieceColor color) {
    if (!isInCheck(board, color)) return false;
    return !_hasLegalMoves(board, color);
  }

  bool isStalemate(Board board, PieceColor color) {
    if (isInCheck(board, color)) return false;
    return !_hasLegalMoves(board, color);
  }

  bool _hasLegalMoves(Board board, PieceColor color) {
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.pieceAt(pos);
        if (piece != null && piece.color == color) {
          if (getLegalMoves(board, pos).isNotEmpty) return true;
        }
      }
    }
    return false;
  }

  bool _wouldBeInCheck(Board board, Position from, Position to, PieceColor color) {
    final testBoard = board.movePiece(from, to);
    return isInCheck(testBoard, color);
  }

  List<Position> _getPieceAttacks(Board board, Position from, Piece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnAttacks(board, from, piece.color);
      case PieceType.knight:
        return _getKnightMoves(board, from, piece.color);
      case PieceType.bishop:
        return _getBishopMoves(board, from, piece.color);
      case PieceType.rook:
        return _getRookMoves(board, from, piece.color);
      case PieceType.queen:
        return _getQueenMoves(board, from, piece.color);
      case PieceType.king:
        return _getKingMoves(board, from, piece.color);
    }
  }

  List<Position> _getPawnMoves(Board board, Position from, PieceColor color, String? enPassantSquare) {
    final moves = <Position>[];
    final direction = color == PieceColor.white ? 1 : -1;
    final startRank = color == PieceColor.white ? 1 : 6;

    final forward = Position(file: from.file, rank: from.rank + direction);
    if (forward.isValid && board.pieceAt(forward) == null) {
      moves.add(forward);

      if (from.rank == startRank) {
        final doubleForward = Position(file: from.file, rank: from.rank + 2 * direction);
        if (board.pieceAt(doubleForward) == null) {
          moves.add(doubleForward);
        }
      }
    }

    for (final fileOffset in [-1, 1]) {
      final capture = Position(file: from.file + fileOffset, rank: from.rank + direction);
      if (capture.isValid) {
        final target = board.pieceAt(capture);
        if (target != null && target.color != color) {
          moves.add(capture);
        }

        // En passant
        if (enPassantSquare != null) {
          try {
            final epPos = Position.fromAlgebraic(enPassantSquare);
            if (capture == epPos) {
              moves.add(capture);
            }
          } catch (e) {
            // Invalid en passant square, ignore
          }
        }
      }
    }

    return moves;
  }

  List<Position> _getPawnAttacks(Board board, Position from, PieceColor color) {
    final attacks = <Position>[];
    final direction = color == PieceColor.white ? 1 : -1;

    for (final fileOffset in [-1, 1]) {
      final attack = Position(file: from.file + fileOffset, rank: from.rank + direction);
      if (attack.isValid) {
        attacks.add(attack);
      }
    }

    return attacks;
  }

  List<Position> _getKnightMoves(Board board, Position from, PieceColor color) {
    final moves = <Position>[];
    final offsets = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1],
    ];

    for (final offset in offsets) {
      final to = Position(file: from.file + offset[0], rank: from.rank + offset[1]);
      if (to.isValid) {
        final target = board.pieceAt(to);
        if (target == null || target.color != color) {
          moves.add(to);
        }
      }
    }

    return moves;
  }

  List<Position> _getBishopMoves(Board board, Position from, PieceColor color) {
    return _getSlidingMoves(board, from, color, [[-1, -1], [-1, 1], [1, -1], [1, 1]]);
  }

  List<Position> _getRookMoves(Board board, Position from, PieceColor color) {
    return _getSlidingMoves(board, from, color, [[0, -1], [0, 1], [-1, 0], [1, 0]]);
  }

  List<Position> _getQueenMoves(Board board, Position from, PieceColor color) {
    return _getSlidingMoves(board, from, color, [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1], [0, 1],
      [1, -1], [1, 0], [1, 1],
    ]);
  }

  List<Position> _getKingMoves(Board board, Position from, PieceColor color) {
    final moves = <Position>[];
    final offsets = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1], [0, 1],
      [1, -1], [1, 0], [1, 1],
    ];

    for (final offset in offsets) {
      final to = Position(file: from.file + offset[0], rank: from.rank + offset[1]);
      if (to.isValid) {
        final target = board.pieceAt(to);
        if (target == null || target.color != color) {
          moves.add(to);
        }
      }
    }

    return moves;
  }

  List<Position> _getSlidingMoves(
    Board board,
    Position from,
    PieceColor color,
    List<List<int>> directions,
  ) {
    final moves = <Position>[];

    for (final dir in directions) {
      int file = from.file + dir[0];
      int rank = from.rank + dir[1];

      while (file >= 0 && file < 8 && rank >= 0 && rank < 8) {
        final to = Position(file: file, rank: rank);
        final target = board.pieceAt(to);

        if (target == null) {
          moves.add(to);
        } else {
          if (target.color != color) {
            moves.add(to);
          }
          break;
        }

        file += dir[0];
        rank += dir[1];
      }
    }

    return moves;
  }

  List<Position> _getCastlingMoves(
    Board board,
    Position kingPos,
    PieceColor color,
    bool whiteCanCastleKingside,
    bool whiteCanCastleQueenside,
    bool blackCanCastleKingside,
    bool blackCanCastleQueenside,
  ) {
    final moves = <Position>[];

    // King must be on starting square
    final startRank = color == PieceColor.white ? 0 : 7;
    if (kingPos.rank != startRank || kingPos.file != 4) return moves;

    // King must not be in check
    if (isInCheck(board, color)) return moves;

    final canKingside = color == PieceColor.white
        ? whiteCanCastleKingside
        : blackCanCastleKingside;
    final canQueenside = color == PieceColor.white
        ? whiteCanCastleQueenside
        : blackCanCastleQueenside;

    // Kingside castling (O-O)
    if (canKingside) {
      final f1 = Position(file: 5, rank: startRank);
      final g1 = Position(file: 6, rank: startRank);
      final h1 = Position(file: 7, rank: startRank);

      // Check squares are empty
      if (board.pieceAt(f1) == null && board.pieceAt(g1) == null) {
        // Check rook is present
        final rook = board.pieceAt(h1);
        if (rook != null && rook.isRook && rook.color == color) {
          // King doesn't pass through check
          if (!_wouldBeInCheck(board, kingPos, f1, color) &&
              !_wouldBeInCheck(board, kingPos, g1, color)) {
            moves.add(g1);
          }
        }
      }
    }

    // Queenside castling (O-O-O)
    if (canQueenside) {
      final d1 = Position(file: 3, rank: startRank);
      final c1 = Position(file: 2, rank: startRank);
      final b1 = Position(file: 1, rank: startRank);
      final a1 = Position(file: 0, rank: startRank);

      // Check squares are empty
      if (board.pieceAt(d1) == null &&
          board.pieceAt(c1) == null &&
          board.pieceAt(b1) == null) {
        // Check rook is present
        final rook = board.pieceAt(a1);
        if (rook != null && rook.isRook && rook.color == color) {
          // King doesn't pass through check (only d1 and c1, not b1)
          if (!_wouldBeInCheck(board, kingPos, d1, color) &&
              !_wouldBeInCheck(board, kingPos, c1, color)) {
            moves.add(c1);
          }
        }
      }
    }

    return moves;
  }

  /// Classifies legal moves into capture, safe, or dangerous moves
  List<MoveInfo> classifyLegalMoves(
    Board board,
    Position from,
    List<Position> legalMoves,
    PieceColor movingColor,
  ) {
    final movingPiece = board.pieceAt(from);
    if (movingPiece == null) return [];

    final opponentColor = movingColor == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    final classifiedMoves = <MoveInfo>[];

    for (final to in legalMoves) {
      final targetPiece = board.pieceAt(to);

      // Check if it's a capture move
      if (targetPiece != null && targetPiece.color == opponentColor) {
        classifiedMoves.add(MoveInfo(position: to, type: MoveType.capture));
        continue;
      }

      // Check if the square would be under attack after moving
      final testBoard = board.movePiece(from, to);
      final isUnderAttack = _isSquareUnderAttack(testBoard, to, opponentColor);

      if (isUnderAttack) {
        classifiedMoves.add(MoveInfo(position: to, type: MoveType.dangerous));
      } else {
        classifiedMoves.add(MoveInfo(position: to, type: MoveType.safe));
      }
    }

    return classifiedMoves;
  }

  /// Checks if a square is under attack by a given color
  bool _isSquareUnderAttack(Board board, Position square, PieceColor attackingColor) {
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = board.pieceAt(pos);
        if (piece != null && piece.color == attackingColor) {
          final attacks = _getPieceAttacks(board, pos, piece);
          if (attacks.contains(square)) return true;
        }
      }
    }
    return false;
  }
}
