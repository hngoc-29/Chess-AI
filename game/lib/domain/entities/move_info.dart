import 'package:equatable/equatable.dart';

import 'position.dart';

/// Type of chess move based on safety and capture
enum MoveType {
  /// Move captures an opponent's piece
  capture,

  /// Move to a square that is safe (not under attack)
  safe,

  /// Move to a square that is under attack (dangerous)
  dangerous,
}

/// Information about a legal move including its type
class MoveInfo extends Equatable {
  final Position position;
  final MoveType type;

  const MoveInfo({
    required this.position,
    required this.type,
  });

  @override
  List<Object?> get props => [position, type];

  @override
  String toString() => 'MoveInfo(position: $position, type: $type)';
}
