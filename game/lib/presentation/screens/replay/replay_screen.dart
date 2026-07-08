import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/fen_utils.dart';
import '../../../domain/entities/board.dart';
import '../../../domain/entities/chess_move.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/move_info.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/settings.dart' show BoardStyle;
import '../../../domain/repositories/i_settings_repository.dart';
import '../../widgets/board/chess_board_widget.dart';

class ReplayScreen extends StatefulWidget {
  final GameState gameState;

  const ReplayScreen({
    super.key,
    required this.gameState,
  });

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> with SingleTickerProviderStateMixin {
  late int currentMoveIndex; // -1 = initial position, 0..n = after move n
  late AnimationController _autoPlayController;
  bool isAutoPlaying = false;
  int autoPlayDelayMs = 1000; // Default 1 second between moves

  @override
  void initState() {
    super.initState();
    currentMoveIndex = -1;
    _autoPlayController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _autoPlayController.dispose();
    super.dispose();
  }

  void _onAutoPlayTick() {
    // Auto-play handler - advance to next move only if within bounds
    if (!isAutoPlaying) return;
    
    if (currentMoveIndex < widget.gameState.moveHistory.length - 1) {
      setState(() {
        currentMoveIndex++;
      });
      // Schedule next move with delay
      Future.delayed(Duration(milliseconds: autoPlayDelayMs), () {
        if (mounted && isAutoPlaying) {
          _onAutoPlayTick();
        }
      });
    } else {
      // End of moves - stop auto-play
      setState(() {
        isAutoPlaying = false;
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      isAutoPlaying = !isAutoPlaying;
    });
    
    if (isAutoPlaying) {
      // Start auto-play sequence
      if (currentMoveIndex < widget.gameState.moveHistory.length - 1) {
        _onAutoPlayTick();
      } else {
        // Reset to start if at end
        setState(() {
          currentMoveIndex = 0;
          isAutoPlaying = true;
        });
        _onAutoPlayTick();
      }
    }
  }

  void _nextMove() {
    setState(() {
      if (currentMoveIndex < widget.gameState.moveHistory.length - 1) {
        currentMoveIndex++;
      }
      isAutoPlaying = false;
    });
  }

  void _prevMove() {
    setState(() {
      if (currentMoveIndex > -1) {
        currentMoveIndex--;
      }
      isAutoPlaying = false;
    });
  }

  void _goToStart() {
    setState(() {
      currentMoveIndex = -1;
      isAutoPlaying = false;
    });
  }

  void _goToEnd() {
    setState(() {
      currentMoveIndex = widget.gameState.moveHistory.length - 1;
      isAutoPlaying = false;
    });
  }

  void _setAutoPlaySpeed(int delayMs) {
    setState(() {
      autoPlayDelayMs = delayMs;
    });
  }

  Board _getBoardAtMove(int moveIndex) {
    Board board = widget.gameState.board;
    
    if (moveIndex == -1) {
      // Initial position - reconstruct from move history
      board = Board.initial();
    } else if (moveIndex >= 0 && moveIndex < widget.gameState.moveHistory.length) {
      // Replay moves from beginning
      board = Board.initial();
      for (int i = 0; i <= moveIndex; i++) {
        final move = widget.gameState.moveHistory[i];
        final movingPiece = board.pieceAt(move.from);
        
        if (movingPiece == null) continue;

        // Handle promotions
        if (move.isPromotion && move.promotion != null) {
          board = board.setPiece(move.from, null);
          final promotedPiece = Piece(type: move.promotion!, color: movingPiece.color);
          board = board.setPiece(move.to, promotedPiece);
        } else {
          board = board.movePiece(move.from, move.to);
        }

        // Handle captures
        if (move.isCapture && move.capturedPiece != null) {
          // Already removed by movePiece
        }

        // Handle en passant
        if (move.isEnPassant) {
          final capturedRank = movingPiece.isWhite ? move.to.rank - 1 : move.to.rank + 1;
          final capturedPos = Position(file: move.to.file, rank: capturedRank);
          board = board.setPiece(capturedPos, null);
        }
      }
    }
    
    return board;
  }

  String _getCurrentFen() {
    final board = _getBoardAtMove(currentMoveIndex);
    // currentMoveIndex + 1 = number of moves played so far. White moves
    // first, so White is to move again once an even number of moves have
    // been played (0, 2, 4...) - using currentMoveIndex directly here
    // (instead of +1) had it exactly backwards for every position,
    // including the initial one.
    final movesPlayed = currentMoveIndex + 1;
    final turn = movesPlayed % 2 == 0 ? PieceColor.white : PieceColor.black;
    
    return boardToFen(
      board,
      turn,
      whiteCanCastleK: widget.gameState.whiteCanCastleKingside,
      whiteCanCastleQ: widget.gameState.whiteCanCastleQueenside,
      blackCanCastleK: widget.gameState.blackCanCastleKingside,
      blackCanCastleQ: widget.gameState.blackCanCastleQueenside,
    );
  }

  void _copyCurrentFen() async {
    final fen = _getCurrentFen();
    await Clipboard.setData(ClipboardData(text: fen));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FEN copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = _getBoardAtMove(currentMoveIndex);
    final moveCount = widget.gameState.moveHistory.length;
    final displayMoveNum = currentMoveIndex == -1 ? 0 : currentMoveIndex + 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Replay Game'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Move: $displayMoveNum / $moveCount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (currentMoveIndex >= 0 && currentMoveIndex < moveCount)
                    Text(
                      '${widget.gameState.moveHistory[currentMoveIndex].toNotation()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // Board
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FutureBuilder<List<String>>(
                      future: Future.wait([
                        getIt<ISettingsRepository>().getPieceSet().then(
                          (result) => result.getOrElse(() => 'cburnett'),
                        ),
                        getIt<ISettingsRepository>().getBoardTheme().then(
                          (result) => result.getOrElse(() => 'classic'),
                        ),
                      ]),
                      builder: (context, snapshot) {
                        final pieceStyle = snapshot.data?[0] ?? 'cburnett';
                        final boardStyle = BoardStyle.values.firstWhere(
                          (e) => e.name == (snapshot.data?[1] ?? 'classic'),
                          orElse: () => BoardStyle.classic,
                        );
                        final boardColors = AppColors.boardStyleColors[boardStyle]!;
                        return ChessBoardWidget(
                          board: board,
                          flipped: false,
                          selectedSquare: null,
                          legalMoves: {},
                          endangeredSquares: {},
                          pieceStyle: pieceStyle,
                          lightSquareColor: boardColors.lightSquare,
                          darkSquareColor: boardColors.darkSquare,
                          onSquareTap: null,
                          onMove: null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Speed slider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto Play Speed: ${autoPlayDelayMs}ms',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: autoPlayDelayMs.toDouble(),
                    min: 200,
                    max: 3000,
                    divisions: 14,
                    label: '${autoPlayDelayMs}ms',
                    onChanged: (value) {
                      _setAutoPlaySpeed(value.toInt());
                    },
                  ),
                ],
              ),
            ),
            // Control buttons
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildIconButton(
                        icon: Icons.skip_previous,
                        label: 'Start',
                        onTap: currentMoveIndex > -1 ? _goToStart : null,
                      ),
                      _buildIconButton(
                        icon: Icons.navigate_before,
                        label: 'Back',
                        onTap: currentMoveIndex > -1 ? _prevMove : null,
                      ),
                      _buildIconButton(
                        icon: isAutoPlaying ? Icons.pause : Icons.play_arrow,
                        label: isAutoPlaying ? 'Pause' : 'Play',
                        onTap: _toggleAutoPlay,
                        isHighlighted: isAutoPlaying,
                      ),
                      _buildIconButton(
                        icon: Icons.navigate_next,
                        label: 'Next',
                        onTap: currentMoveIndex < moveCount - 1 ? _nextMove : null,
                      ),
                      _buildIconButton(
                        icon: Icons.skip_next,
                        label: 'End',
                        onTap: currentMoveIndex < moveCount - 1 ? _goToEnd : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyCurrentFen,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy FEN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Move list
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: moveCount,
                  itemBuilder: (context, index) {
                    final move = widget.gameState.moveHistory[index];
                    final isSelected = index == currentMoveIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          currentMoveIndex = index;
                          isAutoPlaying = false;
                          _autoPlayController.stop();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${index + 1}. ${move.toNotation()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimaryDark,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isEnabled
                  ? (isHighlighted ? AppColors.primary : AppColors.textPrimaryDark)
                  : AppColors.textSecondaryDark.withOpacity(0.5),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isEnabled
                  ? (isHighlighted ? AppColors.primary : AppColors.textPrimaryDark)
                  : AppColors.textSecondaryDark.withOpacity(0.5),
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
