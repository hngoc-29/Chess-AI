import 'package:equatable/equatable.dart';

import 'piece.dart';
import 'position.dart';

class Board extends Equatable {
  final List<List<Piece?>> squares;

  const Board(this.squares);

  factory Board.initial() {
    final squares = List.generate(8, (rank) {
      return List.generate(8, (file) {
        return _initialPiece(rank, file);
      });
    });
    return Board(squares);
  }

  factory Board.empty() {
    final squares = List.generate(8, (_) => List.filled(8, null));
    return Board(squares);
  }

  static Piece? _initialPiece(int rank, int file) {
    const backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    if (rank == 0) {
      return Piece(type: backRank[file], color: PieceColor.white);
    } else if (rank == 1) {
      return const Piece(type: PieceType.pawn, color: PieceColor.white);
    } else if (rank == 6) {
      return const Piece(type: PieceType.pawn, color: PieceColor.black);
    } else if (rank == 7) {
      return Piece(type: backRank[file], color: PieceColor.black);
    }
    return null;
  }

  Piece? pieceAt(Position position) {
    if (!position.isValid) return null;
    return squares[position.rank][position.file];
  }

  Board setPiece(Position position, Piece? piece) {
    final newSquares = List.generate(8, (rank) {
      return List.generate(8, (file) {
        if (rank == position.rank && file == position.file) {
          return piece;
        }
        return squares[rank][file];
      });
    });
    return Board(newSquares);
  }

  Board movePiece(Position from, Position to) {
    final piece = pieceAt(from);
    return setPiece(from, null).setPiece(to, piece);
  }

  List<Position> findPieces(PieceType type, PieceColor color) {
    final positions = <Position>[];
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = squares[rank][file];
        if (piece != null && piece.type == type && piece.color == color) {
          positions.add(Position(file: file, rank: rank));
        }
      }
    }
    return positions;
  }

  Position? findKing(PieceColor color) {
    final kings = findPieces(PieceType.king, color);
    return kings.isEmpty ? null : kings.first;
  }

  @override
  List<Object?> get props => [squares];

  Board copy() {
    final newSquares = List.generate(8, (rank) {
      return List.generate(8, (file) {
        return squares[rank][file];
      });
    });
    return Board(newSquares);
  }

  Map<String, dynamic> toJson() {
    return {
      'squares': squares.map((rank) => 
        rank.map((piece) => piece?.toJson()).toList()
      ).toList(),
    };
  }

  factory Board.fromJson(Map<String, dynamic> json) {
    final squaresJson = json['squares'] as List;
    final squares = squaresJson.map((rankJson) {
      final rank = rankJson as List;
      return rank.map((pieceJson) {
        if (pieceJson == null) return null;
        return Piece.fromJson(pieceJson as Map<String, dynamic>);
      }).toList();
    }).toList();
    return Board(List<List<Piece?>>.from(squares.map((e) => List<Piece?>.from(e))));
  }
}
