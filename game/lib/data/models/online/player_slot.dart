import 'package:equatable/equatable.dart';

/// Represents a player slot in an online game
class PlayerSlot extends Equatable {
  final String userId;
  final String? socketId;
  final String color; // 'w' or 'b'
  final String displayName;
  final int elo;
  final bool connected;
  final DateTime? disconnectedAt;

  const PlayerSlot({
    required this.userId,
    this.socketId,
    required this.color,
    required this.displayName,
    required this.elo,
    required this.connected,
    this.disconnectedAt,
  });

  factory PlayerSlot.fromJson(Map<String, dynamic> json) {
    return PlayerSlot(
      userId: json['userId'] as String,
      socketId: json['socketId'] as String?,
      color: json['color'] as String,
      displayName: json['displayName'] as String,
      elo: json['elo'] as int,
      connected: json['connected'] as bool,
      disconnectedAt: json['disconnectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['disconnectedAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'socketId': socketId,
      'color': color,
      'displayName': displayName,
      'elo': elo,
      'connected': connected,
      'disconnectedAt': disconnectedAt?.millisecondsSinceEpoch,
    };
  }

  PlayerSlot copyWith({
    String? userId,
    String? socketId,
    String? color,
    String? displayName,
    int? elo,
    bool? connected,
    DateTime? disconnectedAt,
  }) {
    return PlayerSlot(
      userId: userId ?? this.userId,
      socketId: socketId ?? this.socketId,
      color: color ?? this.color,
      displayName: displayName ?? this.displayName,
      elo: elo ?? this.elo,
      connected: connected ?? this.connected,
      disconnectedAt: disconnectedAt ?? this.disconnectedAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        socketId,
        color,
        displayName,
        elo,
        connected,
        disconnectedAt,
      ];
}
