import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:chess_ai/domain/entities/piece.dart';

class PromotionDialog extends StatelessWidget {
  final PieceColor color;
  final Function(PieceType) onSelected;
  final String pieceStyle;

  const PromotionDialog({
    super.key,
    required this.color,
    required this.onSelected,
    required this.pieceStyle,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Center(
        child: Text(
          'Phong cấp',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      content: SizedBox(
        width: screenW * 0.7,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _buildPieceOption(context, PieceType.queen, 'Hậu'),
            _buildPieceOption(context, PieceType.rook, 'Xe'),
            _buildPieceOption(context, PieceType.bishop, 'Tượng'),
            _buildPieceOption(context, PieceType.knight, 'Mã'),
          ],
        ),
      ),
    );
  }

  Widget _buildPieceOption(BuildContext context, PieceType type, String label) {
    final piece = Piece(type: type, color: color);
    return Material(
      color: const Color(0xFF2D2D44),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(type),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SvgPicture.asset(
                  piece.getAssetPath(pieceStyle),
                  fit: BoxFit.contain,
                  width: 50,
                  height: 50,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
