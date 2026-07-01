import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/entities/piece.dart';

class PromotionDialog extends StatelessWidget {
  final PieceColor color;
  final Function(PieceType) onSelected;

  const PromotionDialog({
    super.key,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Promotion'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPieceOption(context, PieceType.queen),
          _buildPieceOption(context, PieceType.rook),
          _buildPieceOption(context, PieceType.bishop),
          _buildPieceOption(context, PieceType.knight),
        ],
      ),
    );
  }

  Widget _buildPieceOption(BuildContext context, PieceType type) {
    final piece = Piece(type: type, color: color);
    return InkWell(
      onTap: () {
        onSelected(type);
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 60,
          height: 60,
          child: SvgPicture.asset(
            piece.assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
