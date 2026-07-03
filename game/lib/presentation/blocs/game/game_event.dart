import 'package:equatable/equatable.dart';

import '../../../domain/entities/position.dart';
import '../../../domain/entities/piece.dart';

abstract class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

class StartNewGame extends GameEvent {
  final bool vsAI;

  const StartNewGame({this.vsAI = true});

  @override
  List<Object?> get props => [vsAI];
}

class MakeMove extends GameEvent {
  final Position from;
  final Position to;
  final PieceType? promotion;

  const MakeMove({
    required this.from,
    required this.to,
    this.promotion,
  });

  @override
  List<Object?> get props => [from, to, promotion];
}

class SelectSquare extends GameEvent {
  final Position? position;

  const SelectSquare(this.position);

  @override
  List<Object?> get props => [position];
}

class UndoMove extends GameEvent {
  const UndoMove();
}

class RedoMove extends GameEvent {
  const RedoMove();
}

class FlipBoard extends GameEvent {
  const FlipBoard();
}

class RequestAIMove extends GameEvent {
  const RequestAIMove();
}

class SaveCurrentGame extends GameEvent {
  const SaveCurrentGame();
}

class LoadSavedGame extends GameEvent {
  final String gameId;

  const LoadSavedGame(this.gameId);

  @override
  List<Object?> get props => [gameId];
}
