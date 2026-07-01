import 'package:equatable/equatable.dart';

import 'piece.dart';
import 'position.dart';

class ChessMove extends Equatable {
  final Position from;
  final Position to;
  final PieceType? promotion;
  final Piece? capturedPiece;
  final bool isCheck;
  final bool isCheckmate;
  final bool isCastle;
  final bool isEnPassant;

  const ChessMove({
    required this.from,
    required this.to,
    this.promotion,
    this.capturedPiece,
    this.isCheck = false,
    this.isCheckmate = false,
    this.isCastle = false,
    this.isEnPassant = false,
  });

  ChessMove copyWith({
    Position? from,
    Position? to,
    PieceType? promotion,
    Piece? capturedPiece,
    bool? isCheck,
    bool? isCheckmate,
    bool? isCastle,
    bool? isEnPassant,
  }) {
    return ChessMove(
      from: from ?? this.from,
      to: to ?? this.to,
      promotion: promotion ?? this.promotion,
      capturedPiece: capturedPiece ?? this.capturedPiece,
      isCheck: isCheck ?? this.isCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
      isCastle: isCastle ?? this.isCastle,
      isEnPassant: isEnPassant ?? this.isEnPassant,
    );
  }

  bool get isCapture => capturedPiece != null;
  bool get isPromotion => promotion != null;

  String toAlgebraic() {
    return '${from.toAlgebraic()}${to.toAlgebraic()}${_promotionSuffix()}';
  }

  String _promotionSuffix() {
    if (promotion == null) return '';
    final chars = {
      PieceType.queen: 'q',
      PieceType.rook: 'r',
      PieceType.bishop: 'b',
      PieceType.knight: 'n',
    };
    return chars[promotion] ?? '';
  }

  String toNotation() {
    final buffer = StringBuffer();
    buffer.write(from.toAlgebraic());
    if (isCapture) buffer.write('x');
    buffer.write(to.toAlgebraic());
    if (promotion != null) {
      buffer.write('=');
      buffer.write(_promotionSuffix().toUpperCase());
    }
    if (isCheckmate) {
      buffer.write('#');
    } else if (isCheck) {
      buffer.write('+');
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [
        from,
        to,
        promotion,
        capturedPiece,
        isCheck,
        isCheckmate,
        isCastle,
        isEnPassant,
      ];

  @override
  String toString() => toNotation();
}
