import 'package:equatable/equatable.dart';

/// User profile data from backend
class OnlineUserProfile extends Equatable {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final int elo;
  final int gamesPlayed;
  final int gamesWon;
  final int gamesDrawn;
  final int gamesLost;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OnlineUserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.elo,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.gamesDrawn,
    required this.gamesLost,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OnlineUserProfile.fromJson(Map<String, dynamic> json) {
    return OnlineUserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      elo: json['elo'] as int,
      gamesPlayed: json['games_played'] as int,
      gamesWon: json['games_won'] as int,
      gamesDrawn: json['games_drawn'] as int,
      gamesLost: json['games_lost'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'elo': elo,
      'games_played': gamesPlayed,
      'games_won': gamesWon,
      'games_drawn': gamesDrawn,
      'games_lost': gamesLost,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get winRate {
    if (gamesPlayed == 0) return 0.0;
    return gamesWon / gamesPlayed;
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        avatarUrl,
        elo,
        gamesPlayed,
        gamesWon,
        gamesDrawn,
        gamesLost,
        createdAt,
        updatedAt,
      ];
}
