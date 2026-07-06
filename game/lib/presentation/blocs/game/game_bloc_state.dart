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
  final Set<Position> movablePiecesInCheck;
  final bool flipped;
  final bool isAIThinking;
  final double evaluationScore;
  final bool canRedo;

  const GameInProgress({
    required this.gameState,
    this.selectedSquare,
    this.legalMoves = const {},
    this.endangeredSquares = const {},
    this.movablePiecesInCheck = const {},
    this.flipped = false,
    this.isAIThinking = false,
    this.evaluationScore = 0.0,
    this.canRedo = false,
  });

  Board get board => gameState.board;

  GameInProgress copyWith({
    GameState? gameState,
    Position? selectedSquare,
    Map<Position, MoveType>? legalMoves,
    Set<Position>? endangeredSquares,
    Set<Position>? movablePiecesInCheck,
    bool? flipped,
    bool? isAIThinking,
    double? evaluationScore,
    bool? canRedo,
    bool clearSelection = false,
  }) {
    return GameInProgress(
      gameState: gameState ?? this.gameState,
      selectedSquare: clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? const {} : (legalMoves ?? this.legalMoves),
      endangeredSquares: endangeredSquares ?? this.endangeredSquares,
      movablePiecesInCheck: movablePiecesInCheck ?? this.movablePiecesInCheck,
      flipped: flipped ?? this.flipped,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      evaluationScore: evaluationScore ?? this.evaluationScore,
      canRedo: canRedo ?? this.canRedo,
    );
  }

  @override
  List<Object?> get props => [gameState, selectedSquare, legalMoves, endangeredSquares, movablePiecesInCheck, flipped, isAIThinking, evaluationScore, canRedo];
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

  /// True when the current match is still perfectly playable and the UI
  /// should just surface [message] (e.g. a toast) - for example a single
  /// move application that hit an unexpected exception but was safely
  /// rolled back. False (default) means the error is unrecoverable (e.g.
  /// the AI could not produce any move at all) and starting a new game is
  /// the only sane option.
  final bool recoverable;

  const GameError(this.message, {this.recoverable = false});

  @override
  List<Object?> get props => [message, recoverable];
}
