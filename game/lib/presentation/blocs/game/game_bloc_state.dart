import 'package:equatable/equatable.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/position.dart';

abstract class GameBlocState extends Equatable {
  const GameBlocState();

  @override
  List<Object?> get props => [];
}

class GameInitial extends GameBlocState {
  const GameInitial();
}

class GameLoading extends GameBlocState {
  const GameLoading();
}

class GameInProgress extends GameBlocState {
  final GameState gameState;
  final Position? selectedSquare;
  final Set<Position> legalMoves;
  final bool flipped;
  final bool isAIThinking;

  const GameInProgress({
    required this.gameState,
    this.selectedSquare,
    this.legalMoves = const {},
    this.flipped = false,
    this.isAIThinking = false,
  });

  Board get board => gameState.board;

  GameInProgress copyWith({
    GameState? gameState,
    Position? selectedSquare,
    Set<Position>? legalMoves,
    bool? flipped,
    bool? isAIThinking,
    bool clearSelection = false,
  }) {
    return GameInProgress(
      gameState: gameState ?? this.gameState,
      selectedSquare: clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: legalMoves ?? this.legalMoves,
      flipped: flipped ?? this.flipped,
      isAIThinking: isAIThinking ?? this.isAIThinking,
    );
  }

  @override
  List<Object?> get props => [gameState, selectedSquare, legalMoves, flipped, isAIThinking];
}

class GameOver extends GameBlocState {
  final GameState gameState;
  final String message;

  const GameOver({
    required this.gameState,
    required this.message,
  });

  @override
  List<Object?> get props => [gameState, message];
}

class GameError extends GameBlocState {
  final String message;

  const GameError(this.message);

  @override
  List<Object?> get props => [message];
}
