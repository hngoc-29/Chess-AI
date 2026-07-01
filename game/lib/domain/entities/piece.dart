import 'package:equatable/equatable.dart';

enum PieceType {
  king,
  queen,
  rook,
  bishop,
  knight,
  pawn,
}

enum PieceColor {
  white,
  black,
}

class Piece extends Equatable {
  final PieceType type;
  final PieceColor color;

  const Piece({
    required this.type,
    required this.color,
  });

  bool get isWhite => color == PieceColor.white;
  bool get isBlack => color == PieceColor.black;

  bool get isKing => type == PieceType.king;
  bool get isQueen => type == PieceType.queen;
  bool get isRook => type == PieceType.rook;
  bool get isBishop => type == PieceType.bishop;
  bool get isKnight => type == PieceType.knight;
  bool get isPawn => type == PieceType.pawn;

  String toFenChar() {
    final chars = {
      PieceType.king: 'k',
      PieceType.queen: 'q',
      PieceType.rook: 'r',
      PieceType.bishop: 'b',
      PieceType.knight: 'n',
      PieceType.pawn: 'p',
    };
    final char = chars[type]!;
    return isWhite ? char.toUpperCase() : char;
  }

  static Piece? fromFenChar(String char) {
    if (char == '.') return null;

    final color = char == char.toUpperCase() ? PieceColor.white : PieceColor.black;
    final lowerChar = char.toLowerCase();

    final typeMap = {
      'k': PieceType.king,
      'q': PieceType.queen,
      'r': PieceType.rook,
      'b': PieceType.bishop,
      'n': PieceType.knight,
      'p': PieceType.pawn,
    };

    final type = typeMap[lowerChar];
    if (type == null) return null;

    return Piece(type: type, color: color);
  }

  String get assetPath {
    final colorPrefix = isWhite ? 'w' : 'b';
    final typeChar = {
      PieceType.king: 'K',
      PieceType.queen: 'Q',
      PieceType.rook: 'R',
      PieceType.bishop: 'B',
      PieceType.knight: 'N',
      PieceType.pawn: 'P',
    }[type]!;
    return 'assets/images/pieces/cburnett/$colorPrefix$typeChar.svg';
  }

  @override
  List<Object?> get props => [type, color];

  @override
  String toString() => toFenChar();
}
