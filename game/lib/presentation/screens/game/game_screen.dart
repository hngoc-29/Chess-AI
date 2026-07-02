import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/strings.dart';
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
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          BlocBuilder<GameBloc, GameBlocState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: state is GameInProgress && state.gameState.moveHistory.isNotEmpty
                    ? () => context.read<GameBloc>().add(const UndoMove())
                    : null,
                tooltip: AppStrings.undo,
              );
            },
          ),
          BlocBuilder<GameBloc, GameBlocState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.flip_camera_android),
                onPressed: state is GameInProgress
                    ? () => context.read<GameBloc>().add(const FlipBoard())
                    : null,
                tooltip: AppStrings.flipBoard,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<GameBloc>().add(StartNewGame(vsAI: vsAI));
            },
            tooltip: AppStrings.newGame,
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
    final statusText = state.isAIThinking
        ? AppStrings.aiThinking
        : '${currentPlayer.color == PieceColor.white ? AppStrings.white : AppStrings.black} to move';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (state.isAIThinking)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentPlayer.color == PieceColor.white
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: currentPlayer.color == PieceColor.white
                                ? Colors.grey.shade800
                                : Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
              if (state.gameState.isInCheck)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade700],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.check,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (state.gameState.moveHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Move ${state.gameState.moveHistory.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
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
}
