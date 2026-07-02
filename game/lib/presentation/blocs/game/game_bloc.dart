import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/chess_move.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/position.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/game/chess_rules_service.dart';
import 'game_bloc_state.dart';
import 'game_event.dart';

class GameBloc extends Bloc<GameEvent, GameBlocState> {
  final ChessRulesService _rulesService;
  final AudioService _audioService;
  final List<GameState> _history = [];
  final List<GameState> _redoStack = [];

  GameBloc({
    required ChessRulesService rulesService,
    required AudioService audioService,
  })  : _rulesService = rulesService,
        _audioService = audioService,
        super(const GameInitial()) {
    on<StartNewGame>(_onStartNewGame);
    on<MakeMove>(_onMakeMove);
    on<SelectSquare>(_onSelectSquare);
    on<UndoMove>(_onUndoMove);
    on<RedoMove>(_onRedoMove);
    on<FlipBoard>(_onFlipBoard);
    on<RequestAIMove>(_onRequestAIMove);
  }

  Future<void> _onStartNewGame(StartNewGame event, Emitter<GameBlocState> emit) async {
    emit(const GameLoading());

    final whitePlayer = Player(
      id: 'white',
      name: 'Player',
      color: PieceColor.white,
      type: PlayerType.human,
    );

    final blackPlayer = Player(
      id: 'black',
      name: event.vsAI ? 'AI' : 'Player 2',
      color: PieceColor.black,
      type: event.vsAI ? PlayerType.ai : PlayerType.human,
    );

    final gameState = GameState.initial(
      gameId: DateTime.now().millisecondsSinceEpoch,
      whitePlayer: whitePlayer,
      blackPlayer: blackPlayer,
    );

    // Clear history for new game
    _history.clear();
    _redoStack.clear();

    emit(GameInProgress(gameState: gameState));
  }

  Future<void> _onSelectSquare(SelectSquare event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    if (currentState.isAIThinking) return;

    if (event.position == null) {
      emit(currentState.copyWith(clearSelection: true, legalMoves: {}));
      return;
    }

    final position = event.position!;
    final piece = currentState.board.pieceAt(position);

    if (currentState.selectedSquare == null) {
      if (piece != null && piece.color == currentState.gameState.currentTurn) {
        final legalMoves = _rulesService.getLegalMoves(
          currentState.board,
          position,
          whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
          whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
          blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
          blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
          enPassantSquare: currentState.gameState.enPassantSquare,
        );
        emit(currentState.copyWith(
          selectedSquare: position,
          legalMoves: legalMoves.toSet(),
        ));
      }
    } else {
      if (currentState.legalMoves.contains(position)) {
        add(MakeMove(from: currentState.selectedSquare!, to: position));
      } else if (piece != null && piece.color == currentState.gameState.currentTurn) {
        final legalMoves = _rulesService.getLegalMoves(
          currentState.board,
          position,
          whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
          whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
          blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
          blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
          enPassantSquare: currentState.gameState.enPassantSquare,
        );
        emit(currentState.copyWith(
          selectedSquare: position,
          legalMoves: legalMoves.toSet(),
        ));
      } else {
        emit(currentState.copyWith(clearSelection: true, legalMoves: {}));
      }
    }
  }

  Future<void> _onMakeMove(MakeMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    // Save current state to history before making move
    _history.add(currentState.gameState);
    // Clear redo stack when new move is made
    _redoStack.clear();

    if (!_rulesService.isMoveLegal(currentState.board, event.from, event.to)) {
      _audioService.playSound(SoundEffect.button);
      return;
    }

    final movingPiece = currentState.board.pieceAt(event.from);
    final capturedPiece = currentState.board.pieceAt(event.to);

    // Check if pawn promotion is needed
    if (movingPiece?.isPawn == true && event.promotion == null) {
      final isPromotionRank = (movingPiece!.isWhite && event.to.rank == 7) ||
                              (movingPiece.isBlack && event.to.rank == 0);
      if (isPromotionRank) {
        emit(currentState.copyWith(
          selectedSquare: event.from,
          legalMoves: {event.to},
        ));
        return;
      }
    }

    Board newBoard;
    bool isCastle = false;
    bool isEnPassant = false;

    // Check if this is a castling move
    if (movingPiece?.isKing == true) {
      final fileDiff = (event.to.file - event.from.file).abs();
      if (fileDiff == 2) {
        isCastle = true;
        final isKingside = event.to.file > event.from.file;
        final rank = event.from.rank;

        newBoard = currentState.board.setPiece(event.from, null);
        newBoard = newBoard.setPiece(event.to, movingPiece);

        if (isKingside) {
          final rookFrom = Position(file: 7, rank: rank);
          final rookTo = Position(file: 5, rank: rank);
          final rook = newBoard.pieceAt(rookFrom);
          newBoard = newBoard.setPiece(rookFrom, null);
          newBoard = newBoard.setPiece(rookTo, rook);
        } else {
          final rookFrom = Position(file: 0, rank: rank);
          final rookTo = Position(file: 3, rank: rank);
          final rook = newBoard.pieceAt(rookFrom);
          newBoard = newBoard.setPiece(rookFrom, null);
          newBoard = newBoard.setPiece(rookTo, rook);
        }
      } else {
        if (event.promotion != null && movingPiece?.isPawn == true) {
          newBoard = currentState.board.setPiece(event.from, null);
          final promotedPiece = Piece(type: event.promotion!, color: movingPiece!.color);
          newBoard = newBoard.setPiece(event.to, promotedPiece);
        } else {
          newBoard = currentState.board.movePiece(event.from, event.to);
        }
      }
    } else if (movingPiece?.isPawn == true &&
               capturedPiece == null &&
               event.from.file != event.to.file) {
      // En passant: pawn moves diagonally but no piece on target square
      isEnPassant = true;
      newBoard = currentState.board.setPiece(event.from, null);
      newBoard = newBoard.setPiece(event.to, movingPiece);

      // Remove captured pawn
      final capturedPawnRank = movingPiece!.isWhite ? event.to.rank - 1 : event.to.rank + 1;
      final capturedPawnPos = Position(file: event.to.file, rank: capturedPawnRank);
      newBoard = newBoard.setPiece(capturedPawnPos, null);
    } else {
      if (event.promotion != null && movingPiece?.isPawn == true) {
        newBoard = currentState.board.setPiece(event.from, null);
        final promotedPiece = Piece(type: event.promotion!, color: movingPiece!.color);
        newBoard = newBoard.setPiece(event.to, promotedPiece);
      } else {
        newBoard = currentState.board.movePiece(event.from, event.to);
      }
    }

    if (capturedPiece != null) {
      _audioService.playSound(SoundEffect.capture);
    } else {
      _audioService.playSound(SoundEffect.move);
    }

    // Update castling rights
    var whiteCanCastleKingside = currentState.gameState.whiteCanCastleKingside;
    var whiteCanCastleQueenside = currentState.gameState.whiteCanCastleQueenside;
    var blackCanCastleKingside = currentState.gameState.blackCanCastleKingside;
    var blackCanCastleQueenside = currentState.gameState.blackCanCastleQueenside;

    if (movingPiece?.isKing == true) {
      if (movingPiece!.isWhite) {
        whiteCanCastleKingside = false;
        whiteCanCastleQueenside = false;
      } else {
        blackCanCastleKingside = false;
        blackCanCastleQueenside = false;
      }
    } else if (movingPiece?.isRook == true) {
      if (event.from == const Position(file: 0, rank: 0)) {
        whiteCanCastleQueenside = false;
      } else if (event.from == const Position(file: 7, rank: 0)) {
        whiteCanCastleKingside = false;
      } else if (event.from == const Position(file: 0, rank: 7)) {
        blackCanCastleQueenside = false;
      } else if (event.from == const Position(file: 7, rank: 7)) {
        blackCanCastleKingside = false;
      }
    }

    // Update en passant square
    String? newEnPassantSquare;
    if (movingPiece?.isPawn == true) {
      final rankDiff = (event.to.rank - event.from.rank).abs();
      if (rankDiff == 2) {
        // Pawn moved 2 squares, set en passant square
        final epRank = movingPiece!.isWhite ? event.from.rank + 1 : event.from.rank - 1;
        newEnPassantSquare = Position(file: event.from.file, rank: epRank).toAlgebraic();
      }
    }

    final move = ChessMove(
      from: event.from,
      to: event.to,
      capturedPiece: capturedPiece,
      promotion: event.promotion,
      isCastle: isCastle,
      isEnPassant: isEnPassant,
    );
    final newMoveHistory = [...currentState.gameState.moveHistory, move];

    final nextTurn = currentState.gameState.currentTurn == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    final isInCheck = _rulesService.isInCheck(newBoard, nextTurn);
    if (isInCheck) {
      _audioService.playSound(SoundEffect.check);
    }

    final isCheckmate = _rulesService.isCheckmate(newBoard, nextTurn);
    final isStalemate = _rulesService.isStalemate(newBoard, nextTurn);

    GameStatus newStatus = GameStatus.ongoing;
    if (isCheckmate) {
      newStatus = GameStatus.checkmate;
      _audioService.playSound(SoundEffect.checkmate);
    } else if (isStalemate) {
      newStatus = GameStatus.stalemate;
    }

    final newGameState = currentState.gameState.copyWith(
      board: newBoard,
      currentTurn: nextTurn,
      moveHistory: newMoveHistory,
      isInCheck: isInCheck,
      status: newStatus,
      whiteCanCastleKingside: whiteCanCastleKingside,
      whiteCanCastleQueenside: whiteCanCastleQueenside,
      blackCanCastleKingside: blackCanCastleKingside,
      blackCanCastleQueenside: blackCanCastleQueenside,
      enPassantSquare: newEnPassantSquare,
      updatedAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      gameState: newGameState,
      clearSelection: true,
      legalMoves: {},
    ));

    if (newStatus == GameStatus.checkmate) {
      final winner = currentState.gameState.currentTurn == PieceColor.white ? 'White' : 'Black';
      emit(GameOver(
        gameState: newGameState,
        message: 'Checkmate! $winner wins!',
      ));
      return;
    }

    if (newStatus == GameStatus.stalemate) {
      emit(GameOver(
        gameState: newGameState,
        message: 'Stalemate! Draw.',
      ));
      return;
    }

    if (newGameState.currentPlayer.type == PlayerType.ai) {
      emit(currentState.copyWith(
        gameState: newGameState,
        isAIThinking: true,
        clearSelection: true,
        legalMoves: {},
      ));
      add(const RequestAIMove());
    }
  }

  Future<void> _onRequestAIMove(RequestAIMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    await Future.delayed(const Duration(milliseconds: 500));

    final allMoves = <ChessMove>[];
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final from = Position(file: file, rank: rank);
        final piece = currentState.board.pieceAt(from);
        if (piece != null && piece.color == currentState.gameState.currentTurn) {
          final legalMoves = _rulesService.getLegalMoves(currentState.board, from);
          for (final to in legalMoves) {
            allMoves.add(ChessMove(from: from, to: to));
          }
        }
      }
    }

    if (allMoves.isEmpty) {
      emit(currentState.copyWith(isAIThinking: false));
      return;
    }

    final random = Random();
    final selectedMove = allMoves[random.nextInt(allMoves.length)];

    emit(currentState.copyWith(isAIThinking: false));
    add(MakeMove(from: selectedMove.from, to: selectedMove.to));
  }

  Future<void> _onUndoMove(UndoMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    if (_history.isEmpty) return;

    // Save current state to redo stack
    _redoStack.add(currentState.gameState);

    // Restore previous state from history
    final previousState = _history.removeLast();

    emit(currentState.copyWith(
      gameState: previousState,
      clearSelection: true,
      legalMoves: {},
      isAIThinking: false,
    ));
  }

  Future<void> _onRedoMove(RedoMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    if (_redoStack.isEmpty) return;

    // Save current state to history
    _history.add(currentState.gameState);

    // Restore next state from redo stack
    final nextState = _redoStack.removeLast();

    emit(currentState.copyWith(
      gameState: nextState,
      clearSelection: true,
      legalMoves: {},
      isAIThinking: false,
    ));
  }

  Future<void> _onFlipBoard(FlipBoard event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    emit(currentState.copyWith(flipped: !currentState.flipped));
  }
}
