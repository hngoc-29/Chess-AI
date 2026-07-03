import 'package:equatable/equatable.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/move_info.dart';
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
  final Map<Position, MoveType> legalMoves;
  final Set<Position> endangeredSquares;
  final bool flipped;
  final bool isAIThinking;
  final double evaluationScore;

  const GameInProgress({
    required this.gameState,
    this.selectedSquare,
    this.legalMoves = const {},
    this.endangeredSquares = const {},
    this.flipped = false,
    this.isAIThinking = false,
    this.evaluationScore = 0.0,
  });

  Board get board => gameState.board;

  GameInProgress copyWith({
    GameState? gameState,
    Position? selectedSquare,
    Map<Position, MoveType>? legalMoves,
    Set<Position>? endangeredSquares,
    bool? flipped,
    bool? isAIThinking,
    double? evaluationScore,
    bool clearSelection = false,
  }) {
    return GameInProgress(
      gameState: gameState ?? this.gameState,
      selectedSquare: clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? const {} : (legalMoves ?? this.legalMoves),
      endangeredSquares: endangeredSquares ?? this.endangeredSquares,
      flipped: flipped ?? this.flipped,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      evaluationScore: evaluationScore ?? this.evaluationScore,
    );
  }

  @override
  List<Object?> get props => [gameState, selectedSquare, legalMoves, endangeredSquares, flipped, isAIThinking, evaluationScore];
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
