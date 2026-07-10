import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnlineGameInfoPanel extends StatelessWidget {
  final dynamic room;
  final String playerColor;
  final String opponentColor;
  final bool isTop;

  const OnlineGameInfoPanel({
    super.key,
    required this.room,
    required this.playerColor,
    required this.opponentColor,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final player = isTop
        ? (playerColor == 'w' ? room.black : room.white)
        : (playerColor == 'w' ? room.white : room.black);
    
    final timeLeftMs = isTop
        ? (playerColor == 'w' ? room.blackTimeLeftMs : room.whiteTimeLeftMs)
        : (playerColor == 'w' ? room.whiteTimeLeftMs : room.blackTimeLeftMs);

    final isActive = room.turn == (isTop ? opponentColor : playerColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).primaryColor.withOpacity(0.2)
            : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? Theme.of(context).primaryColor
              : Colors.white.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(player),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.displayName,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getEloColor(player.elo),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        player.elo.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildConnectionStatus(player),
              ],
            ),
          ),
          _buildTimer(timeLeftMs, isActive),
        ],
      ),
    );
  }

  Widget _buildAvatar(dynamic player) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: player.color == 'w' ? Colors.white : Colors.black,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          color: player.color == 'w' ? Colors.black : Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(dynamic player) {
    if (!player.connected) {
      return Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: 14,
            color: Colors.red.shade300,
          ),
          const SizedBox(width: 4),
          Text(
            'Disconnected',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Online',
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTimer(int timeLeftMs, bool isActive) {
    final seconds = (timeLeftMs / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    
    final timeText = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    final isLowTime = seconds < 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLowTime ? Colors.red.shade900 : Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Text(
        timeText,
        style: GoogleFonts.robotoMono(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getEloColor(int elo) {
    if (elo >= 2000) return Colors.purple;
    if (elo >= 1800) return Colors.blue;
    if (elo >= 1600) return Colors.green;
    if (elo >= 1400) return Colors.orange;
    return Colors.grey;
  }
}
