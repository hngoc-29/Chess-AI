import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:chess_ai/domain/entities/piece.dart';

class PieceWidget extends StatelessWidget {
  final Piece piece;
  final double size;
  final bool isDragging;
  final String pieceStyle;

  const PieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.isDragging = false,
    this.pieceStyle = 'cburnett',
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDragging ? 0.5 : 1.0,
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          piece.getAssetPath(pieceStyle),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
