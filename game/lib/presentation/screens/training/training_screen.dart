import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../game/game_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TextEditingController _fenController = TextEditingController();
  String? _fenError;
  bool _isValidFEN = false;

  // FEN validation regex (simplified)
  bool _validateFEN(String fen) {
    if (fen.isEmpty) return false;
    
    // Basic FEN validation
    final parts = fen.split(' ');
    if (parts.length < 6) return false;
    
    // Piece placement validation
    final placement = parts[0];
    final rows = placement.split('/');
    if (rows.length != 8) return false;

    for (var row in rows) {
      int squareCount = 0;
      for (var char in row.split('')) {
        if (int.tryParse(char) != null) {
          squareCount += int.parse(char);
        } else if ('pnbrqkPNBRQK'.contains(char)) {
          squareCount += 1;
        } else {
          return false;
        }
      }
      if (squareCount != 8) return false;
    }

    // Active color validation
    if (!['w', 'b'].contains(parts[1])) return false;

    return true;
  }

  void _onFENChanged(String value) {
    setState(() {
      _isValidFEN = _validateFEN(value);
      if (_isValidFEN) {
        _fenError = null;
      }
    });
  }

  void _startTraining() {
    if (!_isValidFEN) {
      setState(() {
        _fenError = 'Invalid FEN string';
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          vsAI: true,
          initialFEN: _fenController.text.trim(),
        ),
      ),
    );
  }

  void _clearFEN() {
    _fenController.clear();
    setState(() {
      _isValidFEN = false;
      _fenError = null;
    });
  }

  void _pasteExample() {
    _fenController.text = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    _onFENChanged(_fenController.text);
  }

  @override
  void dispose() {
    _fenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Training Mode',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Load a FEN position to analyze and practice',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // FEN Input Label
            Text(
              'FEN Position',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),
            // FEN Input Field
            TextField(
              controller: _fenController,
              onChanged: _onFENChanged,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Paste FEN here...\nExample: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                hintStyle: TextStyle(
                  color: AppColors.textSecondaryDark.withOpacity(0.6),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _fenError != null
                        ? Colors.red.withOpacity(0.5)
                        : AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _fenError != null
                        ? Colors.red.withOpacity(0.5)
                        : (_isValidFEN
                            ? AppColors.primary.withOpacity(0.5)
                            : AppColors.primary.withOpacity(0.3)),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _fenError != null
                        ? Colors.red
                        : AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            // Error or validation message
            if (_fenError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _fenError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              )
            else if (_isValidFEN)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '✓ Valid FEN',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteExample,
                    icon: Icon(Icons.paste, color: AppColors.secondary),
                    label: Text(
                      'Example',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppColors.secondary.withOpacity(0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearFEN,
                    icon: Icon(Icons.clear, color: AppColors.textSecondaryDark),
                    label: Text(
                      'Clear',
                      style: TextStyle(color: AppColors.textSecondaryDark),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppColors.textSecondaryDark.withOpacity(0.3),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Start Training Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isValidFEN ? _startTraining : null,
                icon: Icon(Icons.play_arrow, color: Colors.white),
                label: const Text(
                  'Start Training',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // FEN Format Help
            _buildHelpSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FEN Format Help',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'FEN (Forsyth-Edwards Notation) consists of 6 space-separated fields:\n\n'
            '1. Piece placement (from white\'s perspective)\n'
            '2. Active color (w or b)\n'
            '3. Castling availability (KQkq or -)\n'
            '4. En passant target square (- or e3)\n'
            '5. Halfmove clock\n'
            '6. Fullmove number',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
