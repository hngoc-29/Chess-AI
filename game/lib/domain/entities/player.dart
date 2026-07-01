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

  @override
  List<Object?> get props => [id, name, color, type, elo, avatarUrl];

  @override
  String toString() => '$name (${color.name})';
}
