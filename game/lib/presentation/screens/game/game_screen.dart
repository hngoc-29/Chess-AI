import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/fen_utils.dart';
import '../../../core/constants/colors.dart';
import '../replay/replay_screen.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/move_info.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/repositories/i_settings_repository.dart';
import '../../../domain/repositories/i_stats_repository.dart';
import '../../../domain/usecases/load_game.dart';
import '../../../domain/usecases/save_game.dart';
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
  final String? initialFEN;

  const GameScreen({
    super.key,
    this.vsAI = true,
    this.initialFEN,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameBloc(
        rulesService: getIt<ChessRulesService>(),
        audioService: getIt<AudioService>(),
        aiEngine: getIt<ChessAIEngine>(),
        settingsRepository: getIt<ISettingsRepository>(),
        statsRepository: getIt<IStatsRepository>(),
        saveGameUseCase: getIt<SaveGameUseCase>(),
        loadGameUseCase: getIt<LoadGameUseCase>(),
      ),
      child: _GameView(vsAI: vsAI, initialFEN: initialFEN),
    );
  }
}

class _GameView extends StatefulWidget {
  final bool vsAI;
  final String? initialFEN;

  const _GameView({
    required this.vsAI,
    this.initialFEN,
  });

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> with WidgetsBindingObserver {
  // Guards against a second showDialog() being pushed while the promotion
  // dialog from an earlier tap is still awaiting a response. Without this,
  // rapidly tapping the promotion square twice stacks two dialog routes;
  // picking a piece only pops the top one, leaving the first dialog's
  // invisible modal barrier over the board, silently swallowing every tap
  // afterwards (looks exactly like "board is stuck").
  bool _isShowingPromotionDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // If initialFEN is provided, load the FEN position
      if (widget.initialFEN != null && widget.initialFEN!.isNotEmpty) {
        context.read<GameBloc>().add(StartNewGame(vsAI: widget.vsAI));
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            context.read<GameBloc>().add(SetFenPosition(widget.initialFEN!));
          }
        });
      } else {
        // Otherwise, load the saved game session
        final sessionKey = widget.vsAI ? 'current_session_ai' : 'current_session_local';
        context.read<GameBloc>().add(LoadSavedGame(sessionKey));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      context.read<GameBloc>().add(const SaveCurrentGame());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<GameBloc>().add(const SaveCurrentGame());
            Navigator.of(context).pop();
          },
        ),
        title: const Text('King\'s Gambit AI'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.fiber_new),
            tooltip: 'New Game',
            onPressed: () {
              context.read<GameBloc>().add(StartNewGame(vsAI: widget.vsAI));
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy FEN',
            onPressed: () async {
              final state = context.read<GameBloc>().state;
              GameState? gs;
              if (state is GameInProgress) gs = state.gameState;
              if (state is GameOver) gs = state.gameState;
              if (gs != null) {
                final fen = boardToFen(
                  gs.board,
                  gs.currentTurn,
                  whiteCanCastleK: gs.whiteCanCastleKingside,
                  whiteCanCastleQ: gs.whiteCanCastleQueenside,
                  blackCanCastleK: gs.blackCanCastleKingside,
                  blackCanCastleQ: gs.blackCanCastleQueenside,
                  enPassant: gs.enPassantSquare,
                  halfMove: gs.halfMoveClock,
                  fullMove: gs.fullMoveNumber,
                );
                await Clipboard.setData(ClipboardData(text: fen));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FEN copied')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.input),
            tooltip: 'Load FEN',
            onPressed: () async {
              final controller = TextEditingController();
              try {
                final result = await showDialog<String?>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Load FEN'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'Enter FEN string'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(controller.text.trim()), child: const Text('Load')),
                    ],
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  context.read<GameBloc>().add(SetFenPosition(result));
                }
              } finally {
                controller.dispose();
              }
            },
          ),
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
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
        body: BlocConsumer<GameBloc, GameBlocState>(
        listener: (context, state) {
          if (state is GameOver) {
            _showGameOverDialog(context, state.message);
          } else if (state is GameError) {
            if (state.recoverable) {
              // The match itself is still intact (the bloc already rolled
              // back to a valid state) - just let the player know, don't
              // throw away their game.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), duration: const Duration(seconds: 2)),
              );
            } else {
              context.read<GameBloc>().add(StartNewGame(vsAI: widget.vsAI));
            }
          }
        },
        builder: (context, state) {
          if (state is GameLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // Show board both for in-progress and game-over so user can inspect and undo
          if (state is GameInProgress || state is GameOver) {
            final bool isGameOver = state is GameOver;
            final GameState gs = state is GameInProgress ? state.gameState : (state as GameOver).gameState;
            final Position? selected = state is GameInProgress ? state.selectedSquare : null;
            final legalMoves = state is GameInProgress ? state.legalMoves : <Position, MoveType>{};
            final endangered = state is GameInProgress ? state.endangeredSquares : <Position>{};
            final movableInCheck = state is GameInProgress ? state.movablePiecesInCheck : <Position>{};
            final flipped = state is GameInProgress ? state.flipped : false;
            final isAIThinking = state is GameInProgress ? state.isAIThinking : false;
            final evaluationScore = state is GameInProgress ? state.evaluationScore : 0.0;

            return SafeArea(
              child: Column(
                children: [
                  _buildStatusBar(context, state is GameInProgress ? state as GameInProgress : GameInProgress(gameState: gs)),
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
                          child: FutureBuilder<String>(
                            future: getIt<ISettingsRepository>().getPieceSet().then(
                              (result) => result.getOrElse(() => 'cburnett'),
                            ),
                            builder: (context, snapshot) {
                              final pieceStyle = snapshot.data ?? 'cburnett';
                              return ChessBoardWidget(
                                board: gs.board,
                                flipped: flipped,
                                selectedSquare: selected,
                                legalMoves: legalMoves,
                                endangeredSquares: endangered,
                                movablePiecesInCheck: movableInCheck,
                                pieceStyle: pieceStyle,
                                onSquareTap: isGameOver ? null : (position) {
                                  if (!isGameOver && state is GameInProgress) _handleSquareTap(context, state as GameInProgress, position);
                                },
                                onMove: isGameOver ? null : (from, to) {
                                  if (!isGameOver && state is GameInProgress) _handleMove(context, state as GameInProgress, from, to);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (state is GameInProgress) _buildActionButtons(context, state as GameInProgress),
                  if (state is GameInProgress && widget.vsAI) _buildEvaluation(context, state as GameInProgress),
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
    // If a piece is selected and this is a legal move, handle it as a move
    if (state.selectedSquare != null && state.legalMoves.containsKey(position)) {
      _handleMove(context, state, state.selectedSquare!, position);
    } else {
      // Otherwise, just select the square
      context.read<GameBloc>().add(SelectSquare(position));
    }
  }

  Future<void> _handleMove(BuildContext context, GameInProgress state, Position from, Position to) async {
    final movingPiece = state.board.pieceAt(from);

    // Check if this is a pawn promotion
    if (movingPiece?.isPawn == true) {
      final isPromotionRank = (movingPiece!.isWhite && to.rank == 7) ||
                              (movingPiece.isBlack && to.rank == 0);

      if (isPromotionRank) {
        // Prevent stacking a second dialog on top of one that's already
        // awaiting a response (see field doc comment above).
        if (_isShowingPromotionDialog) return;
        _isShowingPromotionDialog = true;

        // Get piece style from settings
        final pieceStyleResult = await getIt<ISettingsRepository>().getPieceSet();
        final pieceStyle = pieceStyleResult.getOrElse(() => 'cburnett');

        PieceType? promotion;
        try {
          // Show promotion dialog. PopScope blocks the system/gesture back
          // button from dismissing it - the player must pick a piece so a
          // validated move can never be silently dropped.
          promotion = await showDialog<PieceType>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => PopScope(
              canPop: false,
              child: PromotionDialog(
                color: movingPiece.color,
                pieceStyle: pieceStyle,
                onSelected: (type) => Navigator.of(dialogContext).pop(type),
              ),
            ),
          );
        } finally {
          _isShowingPromotionDialog = false;
        }

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
              final state = context.read<GameBloc>().state;
              if (state is GameOver) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReplayScreen(gameState: state.gameState),
                  ),
                );
              }
            },
            child: const Text('View Replay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<GameBloc>().add(StartNewGame(vsAI: widget.vsAI));
            },
            child: const Text(AppStrings.newGame),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text(AppStrings.home),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, GameInProgress state) {
    // Hide hints and analysis for human vs human games
    final isHumanVsHuman = !widget.vsAI;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Only show Hint button for AI games
          if (!isHumanVsHuman)
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
          // Only show Analysis button for AI games
          if (!isHumanVsHuman)
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
                        context.read<GameBloc>().add(StartNewGame(vsAI: widget.vsAI));
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
                state.evaluationScore > 0 
                    ? '+${state.evaluationScore.toStringAsFixed(2)}' 
                    : state.evaluationScore.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: state.evaluationScore > 0 
                      ? AppColors.success 
                      : (state.evaluationScore < 0 ? AppColors.error : AppColors.textPrimaryDark),
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
