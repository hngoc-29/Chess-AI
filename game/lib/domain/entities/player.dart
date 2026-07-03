import 'package:equatable/equatable.dart';

import 'piece.dart';

enum PlayerType {
  human,
  ai,
}

class Player extends Equatable {
  final String id;
  final String name;
  final PieceColor color;
  final PlayerType type;
  final int? elo;
  final String? avatarUrl;

  const Player({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    this.elo,
    this.avatarUrl,
  });

  bool get isHuman => type == PlayerType.human;
  bool get isAI => type == PlayerType.ai;

  Player copyWith({
    String? id,
    String? name,
    PieceColor? color,
    PlayerType? type,
    int? elo,
    String? avatarUrl,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      type: type ?? this.type,
      elo: elo ?? this.elo,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.name,
      'type': type.name,
      'elo': elo,
      'avatarUrl': avatarUrl,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      color: PieceColor.values.firstWhere((e) => e.name == json['color']),
      type: PlayerType.values.firstWhere((e) => e.name == json['type']),
      elo: json['elo'] as int?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, color, type, elo, avatarUrl];

  @override
  String toString() => '$name (${color.name})';
}
