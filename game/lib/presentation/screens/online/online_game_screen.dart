import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/online/online_game_bloc.dart';
import '../../widgets/online/online_chess_board.dart';
import '../../widgets/online/online_game_info_panel.dart';
import '../../widgets/online/online_chat_panel.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: SafeArea(
        child: BlocConsumer<OnlineGameBloc, OnlineGameState>(
          listener: (context, state) {
            if (state is OnlineGameFinished) {
              _showGameOverDialog(context, state);
            } else if (state is OnlineGameError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is OnlineGamePlaying) {
              return _buildGameView(context, state);
            } else if (state is OnlineGameFinished) {
              return _buildGameView(context, null, finished: state);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildGameView(
    BuildContext context,
    OnlineGamePlaying? playingState, {
    OnlineGameFinished? finished,
  }) {
    final state = playingState ?? finished;
    if (state == null) return const SizedBox();

    final room = playingState?.room ?? finished!.room;
    final playerColor = playingState?.playerColor ?? finished!.playerColor;
    final isMyTurn = playingState?.isMyTurn ?? false;

    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return _buildPortraitLayout(context, room, playerColor, isMyTurn, playingState);
        } else {
          return _buildLandscapeLayout(context, room, playerColor, isMyTurn, playingState);
        }
      },
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    dynamic room,
    String playerColor,
    bool isMyTurn,
    OnlineGamePlaying? state,
  ) {
    return Column(
      children: [
        _buildHeader(context, room, playerColor),
        Expanded(
          child: Column(
            children: [
              OnlineGameInfoPanel(
                room: room,
                playerColor: playerColor,
                opponentColor: playerColor == 'w' ? 'b' : 'w',
                isTop: true,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: OnlineChessBoard(
                    fen: room.fen,
                    playerColor: playerColor,
                    isMyTurn: isMyTurn,
                    onMoveMade: (from, to, promotion) {
                      context.read<OnlineGameBloc>().add(
                            MoveMade(from: from, to: to, promotion: promotion),
                          );
                    },
                  ),
                ),
              ),
              OnlineGameInfoPanel(
                room: room,
                playerColor: playerColor,
                opponentColor: playerColor == 'w' ? 'b' : 'w',
                isTop: false,
              ),
            ],
          ),
        ),
        _buildBottomActions(context, room, playerColor, state),
      ],
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    dynamic room,
    String playerColor,
    bool isMyTurn,
    OnlineGamePlaying? state,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _buildHeader(context, room, playerColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: OnlineChessBoard(
                    fen: room.fen,
                    playerColor: playerColor,
                    isMyTurn: isMyTurn,
                    onMoveMade: (from, to, promotion) {
                      context.read<OnlineGameBloc>().add(
                            MoveMade(from: from, to: to, promotion: promotion),
                          );
                    },
                  ),
                ),
              ),
              _buildBottomActions(context, room, playerColor, state),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              OnlineGameInfoPanel(
                room: room,
                playerColor: playerColor,
                opponentColor: playerColor == 'w' ? 'b' : 'w',
                isTop: true,
              ),
              OnlineGameInfoPanel(
                room: room,
                playerColor: playerColor,
                opponentColor: playerColor == 'w' ? 'b' : 'w',
                isTop: false,
              ),
              if (state != null)
                Expanded(
                  child: OnlineChatPanel(
                    messages: state.chatMessages,
                    onSendMessage: (text) {
                      context.read<OnlineGameBloc>().add(ChatMessageSent(text));
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, dynamic room, String playerColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _confirmExit(context),
          ),
          const SizedBox(width: 16),
          Icon(
            room.rated ? Icons.emoji_events : Icons.handshake,
            color: Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            room.rated ? 'Ranked Game' : 'Casual Game',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: playerColor == 'w' ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              playerColor == 'w' ? 'White' : 'Black',
              style: TextStyle(
                color: playerColor == 'w' ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    dynamic room,
    String playerColor,
    OnlineGamePlaying? state,
  ) {
    if (state == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context,
            icon: Icons.flag,
            label: 'Resign',
            color: Colors.red,
            onPressed: () => _confirmResign(context),
          ),
          _buildActionButton(
            context,
            icon: Icons.handshake,
            label: 'Draw',
            color: Colors.blue,
            onPressed: () => _offerDraw(context),
          ),
          if (room.drawOfferedBy != null && room.drawOfferedBy != playerColor)
            _buildActionButton(
              context,
              icon: Icons.check,
              label: 'Accept Draw',
              color: Colors.green,
              onPressed: () {
                context.read<OnlineGameBloc>().add(const DrawResponseSent(true));
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
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _confirmResign(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign Game'),
        content: const Text('Are you sure you want to resign? You will lose this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<OnlineGameBloc>().add(const ResignRequested());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _offerDraw(BuildContext context) {
    context.read<OnlineGameBloc>().add(const DrawOffered());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draw offer sent')),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Game'),
        content: const Text('Are you sure you want to leave? The game will continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, OnlineGameFinished state) {
    final result = state.room.result;
    if (result == null) return;

    String title = 'Game Over';
    String message = '';

    if (result.winnerColor == null) {
      title = 'Draw';
      message = 'Game ended in a draw';
    } else if (result.winnerColor == state.playerColor) {
      title = 'Victory!';
      message = 'You won the game!';
    } else {
      title = 'Defeat';
      message = 'You lost the game';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text(
              'Result: ${result.resultType.toString().split('.').last}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
