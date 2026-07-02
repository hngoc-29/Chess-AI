import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/strings.dart';
import '../../../core/constants/colors.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/repositories/i_settings_repository.dart';
import '../../../services/ai/chess_ai_engine.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/game/chess_rules_service.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_bloc_state.dart';
import '../../blocs/game/game_event.dart';
import '../../widgets/board/chess_board_widget.dart';
import '../../widgets/dialogs/promotion_dialog.dart';

class GameScreen extends StatelessWidget {
  final bool vsAI;

  const GameScreen({
    super.key,
    this.vsAI = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameBloc(
        rulesService: getIt<ChessRulesService>(),
        audioService: getIt<AudioService>(),
        aiEngine: getIt<ChessAIEngine>(),
        settingsRepository: getIt<ISettingsRepository>(),
      )..add(StartNewGame(vsAI: vsAI)),
      child: _GameView(vsAI: vsAI),
    );
  }
}

class _GameView extends StatelessWidget {
  final bool vsAI;

  const _GameView({required this.vsAI});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Chess AI'),
        centerTitle: false,
        actions: [
          BlocBuilder<GameBloc, GameBlocState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: state is GameInProgress && state.gameState.moveHistory.isNotEmpty
                    ? () => context.read<GameBloc>().add(const UndoMove())
                    : null,
              );
            },
          ),
          BlocBuilder<GameBloc, GameBlocState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state is GameInProgress
                    ? () => context.read<GameBloc>().add(const FlipBoard())
                    : null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: BlocConsumer<GameBloc, GameBlocState>(
        listener: (context, state) {
          if (state is GameOver) {
            _showGameOverDialog(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is GameLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GameInProgress) {
            return SafeArea(
              child: Column(
                children: [
                  _buildStatusBar(context, state),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                          child: ChessBoardWidget(
                            board: state.board,
                            flipped: state.flipped,
                            selectedSquare: state.selectedSquare,
                            legalMoves: state.legalMoves,
                            onSquareTap: (position) {
                              _handleSquareTap(context, state, position);
                            },
                            onMove: (from, to) {
                              _handleMove(context, state, from, to);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildActionButtons(context, state),
                  _buildEvaluation(context, state),
                ],
              ),
            );
          }

          return const Center(child: Text('Press New Game to start'));
        },
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, GameInProgress state) {
    final currentPlayer = state.gameState.currentPlayer;
    final isWhite = currentPlayer.color == PieceColor.white;
    final playerName = isWhite ? 'White' : 'Black';
    final moveCount = (state.gameState.moveHistory.length ~/ 2) + 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary.withOpacity(0.3),
            AppColors.secondary.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left side - Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isWhite 
                            ? Colors.white.withOpacity(0.9)
                            : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person,
                        color: isWhite ? Colors.black : Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$playerName to move',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        if (state.isAIThinking)
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: AppColors.primary,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI đang suy nghĩ...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right side - Move info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.textPrimaryDark,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Move $moveCount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sicilian Defense',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSquareTap(BuildContext context, GameInProgress state, Position position) {
    context.read<GameBloc>().add(SelectSquare(position));
  }

  Future<void> _handleMove(BuildContext context, GameInProgress state, Position from, Position to) async {
    final movingPiece = state.board.pieceAt(from);

    // Check if this is a pawn promotion
    if (movingPiece?.isPawn == true) {
      final isPromotionRank = (movingPiece!.isWhite && to.rank == 7) ||
                              (movingPiece.isBlack && to.rank == 0);

      if (isPromotionRank) {
        // Show promotion dialog
        final promotion = await showDialog<PieceType>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PromotionDialog(
            color: movingPiece.color,
            onSelected: (type) => Navigator.of(dialogContext).pop(type),
          ),
        );

        if (promotion != null) {
          context.read<GameBloc>().add(MakeMove(from: from, to: to, promotion: promotion));
        }
        return;
      }
    }

    // Regular move
    context.read<GameBloc>().add(MakeMove(from: from, to: to));
  }

  void _showGameOverDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.gameOver),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<GameBloc>().add(StartNewGame(vsAI: vsAI));
            },
            child: const Text(AppStrings.newGame),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text(AppStrings.exit),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, GameInProgress state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context,
            icon: Icons.lightbulb_outline,
            label: 'Gợi ý',
            onTap: state.legalMoves.isNotEmpty
                ? () {
                    // Show hint: highlight a random legal move
                    final moves = state.legalMoves.keys.toList();
                    if (moves.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gợi ý: Hãy thử nước đi tới ${moves.first.toString()}'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }
                : null,
          ),
          _buildActionButton(
            context,
            icon: Icons.search,
            label: 'Phân tích',
            onTap: () {
              // Show analysis info
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tính năng phân tích đang được phát triển'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppColors.info,
                ),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.refresh,
            label: 'Đánh lại',
            isHighlighted: true,
            onTap: () {
              // Start new game
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Ván mới'),
                  content: const Text('Bạn có muốn bắt đầu ván mới không?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.read<GameBloc>().add(StartNewGame(vsAI: vsAI));
                      },
                      child: const Text('Đồng ý'),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.undo,
            label: 'Lùi lại',
            onTap: state.gameState.moveHistory.isNotEmpty
                ? () => context.read<GameBloc>().add(const UndoMove())
                : null,
          ),
          _buildActionButton(
            context,
            icon: Icons.arrow_forward,
            label: 'Tiến',
            onTap: () {
              // Redo move
              context.read<GameBloc>().add(const RedoMove());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? (isHighlighted ? AppColors.primary : AppColors.textPrimaryDark)
                  : AppColors.textSecondaryDark.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled
                    ? (isHighlighted ? AppColors.primary : AppColors.textPrimaryDark)
                    : AppColors.textSecondaryDark.withOpacity(0.5),
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluation(BuildContext context, GameInProgress state) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Đánh giá vị trí',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+0.32',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CustomPaint(
                    painter: _EvaluationGraphPainter(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Lợi thế nhẹ cho Trắng',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Sample evaluation data points
    final points = [0.0, 0.1, 0.15, 0.2, 0.25, 0.32];
    final stepX = size.width / (points.length - 1);
    
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height / 2 - (points[i] * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw center line
    final centerPaint = Paint()
      ..color = AppColors.textSecondaryDark.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
