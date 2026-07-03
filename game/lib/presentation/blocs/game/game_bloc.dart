import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/chess_move.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/move_info.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/settings.dart';
import '../../../domain/repositories/i_settings_repository.dart';
import '../../../domain/repositories/i_stats_repository.dart';
import '../../../domain/usecases/load_game.dart';
import '../../../domain/usecases/save_game.dart';
import '../../../services/ai/chess_ai_engine.dart';
import '../../../services/ai/maia_ai_engine.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/game/chess_rules_service.dart';
import '../../../core/utils/fen_utils.dart';
import '../../../core/utils/logger.dart';
import 'game_bloc_state.dart';
import 'game_event.dart';

class GameBloc extends Bloc<GameEvent, GameBlocState> {
  final ChessRulesService _rulesService;
  final AudioService _audioService;
  final ChessAIEngine _aiEngine;
  final ISettingsRepository _settingsRepository;
  final IStatsRepository _statsRepository;
  final SaveGameUseCase _saveGameUseCase;
  final LoadGameUseCase _loadGameUseCase;
  final List<GameState> _history = [];
  final List<GameState> _redoStack = [];

  GameBloc({
    required ChessRulesService rulesService,
    required AudioService audioService,
    required ChessAIEngine aiEngine,
    required ISettingsRepository settingsRepository,
    required IStatsRepository statsRepository,
    required SaveGameUseCase saveGameUseCase,
    required LoadGameUseCase loadGameUseCase,
  })  : _rulesService = rulesService,
        _audioService = audioService,
        _aiEngine = aiEngine,
        _settingsRepository = settingsRepository,
        _statsRepository = statsRepository,
        _saveGameUseCase = saveGameUseCase,
        _loadGameUseCase = loadGameUseCase,
        super(const GameInitial()) {
    on<StartNewGame>(_onStartNewGame);
    on<MakeMove>(_onMakeMove);
    on<SelectSquare>(_onSelectSquare);
    on<UndoMove>(_onUndoMove);
    on<RedoMove>(_onRedoMove);
    on<FlipBoard>(_onFlipBoard);
    on<RequestAIMove>(_onRequestAIMove);
  on<SetFenPosition>(_onSetFenPosition);
    on<SaveCurrentGame>(_onSaveCurrentGame);
    on<LoadSavedGame>(_onLoadSavedGame);
  }

  Future<void> _onSetFenPosition(SetFenPosition event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress && state is! GameOver) return;
    GameState baseState;
    if (state is GameInProgress) {
      baseState = (state as GameInProgress).gameState;
    } else {
      baseState = (state as GameOver).gameState;
    }

    try {
      final parsed = fenToBoard(event.fen);
      final newGameState = baseState.copyWith(
        board: parsed.board,
        currentTurn: parsed.currentTurn,
        whiteCanCastleKingside: parsed.whiteCanCastleK,
        whiteCanCastleQueenside: parsed.whiteCanCastleQ,
        blackCanCastleKingside: parsed.blackCanCastleK,
        blackCanCastleQueenside: parsed.blackCanCastleQ,
        enPassantSquare: parsed.enPassant,
        halfMoveClock: parsed.halfMoveClock,
        fullMoveNumber: parsed.fullMoveNumber,
      );

      _history.clear();
      _redoStack.clear();

      emit(GameInProgress(gameState: newGameState));
    } catch (e) {
      AppLogger.warning('Invalid FEN position: ${event.fen}', e);
      emit(GameError('Invalid FEN string: ${e.toString()}'));
    }
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
        final legalMovePositions = _rulesService.getLegalMoves(
          currentState.board,
          position,
          whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
          whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
          blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
          blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
          enPassantSquare: currentState.gameState.enPassantSquare,
        );
        final classifiedMoves = _rulesService.classifyLegalMoves(
          currentState.board,
          position,
          legalMovePositions,
          currentState.gameState.currentTurn,
        );
        final legalMovesMap = <Position, MoveType>{
          for (final moveInfo in classifiedMoves)
            moveInfo.position: moveInfo.type
        };
        emit(currentState.copyWith(
          selectedSquare: position,
          legalMoves: legalMovesMap,
        ));
      }
    } else {
      if (currentState.legalMoves.containsKey(position)) {
        add(MakeMove(from: currentState.selectedSquare!, to: position));
      } else if (piece != null && piece.color == currentState.gameState.currentTurn) {
        final legalMovePositions = _rulesService.getLegalMoves(
          currentState.board,
          position,
          whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
          whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
          blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
          blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
          enPassantSquare: currentState.gameState.enPassantSquare,
        );
        final classifiedMoves = _rulesService.classifyLegalMoves(
          currentState.board,
          position,
          legalMovePositions,
          currentState.gameState.currentTurn,
        );
        final legalMovesMap = <Position, MoveType>{
          for (final moveInfo in classifiedMoves)
            moveInfo.position: moveInfo.type
        };
        emit(currentState.copyWith(
          selectedSquare: position,
          legalMoves: legalMovesMap,
        ));
      } else {
        emit(currentState.copyWith(clearSelection: true, legalMoves: {}));
      }
    }
  }

  Future<void> _onMakeMove(MakeMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    var movingPiece = currentState.board.pieceAt(event.from);
    
    // If there's no piece at the source square, the move is invalid
    if (movingPiece == null) {
      _audioService.playSound(SoundEffect.button);
      return;
    }
    
    // Validate piece belongs to current player
    if (movingPiece.color != currentState.gameState.currentTurn) {
      _audioService.playSound(SoundEffect.button);
      return;
    }

    final legalMoves = _rulesService.getLegalMoves(
      currentState.board,
      event.from,
      whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
      whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
      blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
      blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
      enPassantSquare: currentState.gameState.enPassantSquare,
    );

    if (!legalMoves.contains(event.to)) {
      _audioService.playSound(SoundEffect.button);
      return;
    }

    final capturedPiece = currentState.board.pieceAt(event.to);

    // Check if pawn promotion is needed
    if (movingPiece.isPawn && event.promotion == null) {
      final isPromotionRank = (movingPiece.isWhite && event.to.rank == 7) ||
                              (movingPiece.isBlack && event.to.rank == 0);
      if (isPromotionRank) {
        emit(currentState.copyWith(
          selectedSquare: event.from,
          legalMoves: <Position, MoveType>{event.to: MoveType.safe},
        ));
        return;
      }
    }

    // Save only valid, complete moves to history
    _history.add(currentState.gameState);
    _redoStack.clear();

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
      clearEnPassantSquare: newEnPassantSquare == null,
      updatedAt: DateTime.now(),
    );

    // Calculate evaluation score (from White's perspective)
    final evalScore = _aiEngine.evaluatePosition(newBoard, PieceColor.white);

    // Calculate endangered squares for current player
    final endangeredSquares = _rulesService.getEndangeredSquares(newBoard, nextTurn);

    emit(currentState.copyWith(
      gameState: newGameState,
      clearSelection: true,
      legalMoves: {},
      endangeredSquares: endangeredSquares,
      evaluationScore: evalScore,
    ));

    if (newStatus == GameStatus.checkmate) {
      // Determine winner (opposite of current turn since they're checkmated)
      final winnerColor = currentState.gameState.currentTurn == PieceColor.white 
          ? PieceColor.black 
          : PieceColor.white;
      final winnerName = winnerColor == PieceColor.white ? 'White' : 'Black';
      
      // Check if human won (for stats)
      final humanWon = (winnerColor == PieceColor.white && 
                        currentState.gameState.whitePlayer.type == PlayerType.human) ||
                       (winnerColor == PieceColor.black && 
                        currentState.gameState.blackPlayer.type == PlayerType.human);
      
      // Record game statistics
      await _statsRepository.recordGame(isWin: humanWon, isDraw: false);
      
      emit(GameOver(
        gameState: newGameState,
        message: 'Checkmate! $winnerName wins!',
      ));
      return;
    }

    if (newStatus == GameStatus.stalemate) {
      // Record game statistics for draw
      await _statsRepository.recordGame(isWin: false, isDraw: true);
      
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

  Future<void> _onSaveCurrentGame(SaveCurrentGame event, Emitter<GameBlocState> emit) async {
    if (state is GameInProgress) {
      final currentState = state as GameInProgress;
      await _saveGameUseCase.saveState(currentState.gameState);
    }
  }

  Future<void> _onLoadSavedGame(LoadSavedGame event, Emitter<GameBlocState> emit) async {
    emit(const GameLoading());
    
    final result = await _loadGameUseCase.call(event.gameId);
    result.fold(
      (failure) {
        emit(GameError(failure.message));
      },
      (gameState) {
        _history.clear();
        _redoStack.clear();
        emit(GameInProgress(gameState: gameState));
      },
    );
  }

  Future<void> _onRequestAIMove(RequestAIMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    try {
      // First check if the game is already over (checkmate/stalemate)
      final isCheckmate = _rulesService.isCheckmate(
        currentState.board,
        currentState.gameState.currentTurn,
      );
      final isStalemate = _rulesService.isStalemate(
        currentState.board,
        currentState.gameState.currentTurn,
      );

      if (isCheckmate) {
        // AI is checkmated, human wins
        final winnerColor = currentState.gameState.currentTurn == PieceColor.white
            ? PieceColor.black
            : PieceColor.white;
        final winnerName = winnerColor == PieceColor.white ? 'Trắng' : 'Đen';
        
        await _statsRepository.recordGame(isWin: true, isDraw: false);
        
        emit(GameOver(
          gameState: currentState.gameState.copyWith(status: GameStatus.checkmate),
          message: 'Chiếu hết! $winnerName thắng!',
        ));
        return;
      }

      if (isStalemate) {
        await _statsRepository.recordGame(isWin: false, isDraw: true);
        
        emit(GameOver(
          gameState: currentState.gameState.copyWith(status: GameStatus.stalemate),
          message: 'Hòa cờ!',
        ));
        return;
      }

      // Get current AI difficulty setting
      final difficultyResult = await _settingsRepository.getAIDifficulty();
      final difficultyInt = difficultyResult.fold(
        (failure) => 1, // Default to medium (index 1) if settings can't be loaded
        (value) => value,
      );

      // Convert int to AIDifficulty enum
      final difficulty = _intToAIDifficulty(difficultyInt);

      // Use the AI engine to find the best move
      final bestMove = await _aiEngine.getBestMove(
        board: currentState.board,
        color: currentState.gameState.currentTurn,
        difficulty: difficulty,
        whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
        whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
        blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
        blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
        enPassantSquare: currentState.gameState.enPassantSquare,
        halfMoveClock: currentState.gameState.halfMoveClock,
        fullMoveNumber: currentState.gameState.fullMoveNumber,
      );

      emit(currentState.copyWith(isAIThinking: false));
      add(MakeMove(from: bestMove.from, to: bestMove.to, promotion: bestMove.promotion));
    } catch (e) {
      AppLogger.error('AI move request failed', e);
      
      // If AI fails to find a move, check if game is over
      final isCheckmate = _rulesService.isCheckmate(
        currentState.board,
        currentState.gameState.currentTurn,
      );
      final isStalemate = _rulesService.isStalemate(
        currentState.board,
        currentState.gameState.currentTurn,
      );

      if (isCheckmate) {
        final winnerColor = currentState.gameState.currentTurn == PieceColor.white
            ? PieceColor.black
            : PieceColor.white;
        final winnerName = winnerColor == PieceColor.white ? 'Trắng' : 'Đen';
        
        await _statsRepository.recordGame(isWin: true, isDraw: false);
        
        emit(GameOver(
          gameState: currentState.gameState.copyWith(status: GameStatus.checkmate),
          message: 'Chiếu hết! $winnerName thắng!',
        ));
      } else if (isStalemate) {
        await _statsRepository.recordGame(isWin: false, isDraw: true);
        
        emit(GameOver(
          gameState: currentState.gameState.copyWith(status: GameStatus.stalemate),
          message: 'Hòa cờ!',
        ));
      } else {
        // Try to make any legal move to recover from error
        try {
          final piece = currentState.gameState.currentPlayer;
          for (int file = 0; file < 8; file++) {
            for (int rank = 0; rank < 8; rank++) {
              final pos = Position(file: file, rank: rank);
              final p = currentState.board.pieceAt(pos);
              if (p != null && p.color == piece.color) {
                final legalMoves = _rulesService.getLegalMoves(
                  currentState.board,
                  pos,
                  whiteCanCastleKingside: currentState.gameState.whiteCanCastleKingside,
                  whiteCanCastleQueenside: currentState.gameState.whiteCanCastleQueenside,
                  blackCanCastleKingside: currentState.gameState.blackCanCastleKingside,
                  blackCanCastleQueenside: currentState.gameState.blackCanCastleQueenside,
                  enPassantSquare: currentState.gameState.enPassantSquare,
                );
                if (legalMoves.isNotEmpty) {
                  add(MakeMove(from: pos, to: legalMoves.first));
                  return;
                }
              }
            }
          }
          // If no legal move found, emit error state
          emit(GameError('AI could not find a valid move'));
        } catch (fallbackError) {
          AppLogger.error('AI fallback move failed', fallbackError);
          emit(GameError('AI error - Please start a new game'));
        }
      }
    }
  }

  /// Convert integer difficulty to AIDifficulty enum
  AIDifficulty _intToAIDifficulty(int value) {
    if (value >= 0 && value < AIDifficulty.values.length) {
      return AIDifficulty.values[value];
    }
    return AIDifficulty.medium; // Default to medium for invalid values
  }

  Future<void> _onUndoMove(UndoMove event, Emitter<GameBlocState> emit) async {
    if (state is! GameInProgress) return;
    final currentState = state as GameInProgress;

    if (_history.isEmpty) return;

    // Check if we're playing against AI
    final isVsAI = currentState.gameState.blackPlayer.type == PlayerType.ai ||
                   currentState.gameState.whitePlayer.type == PlayerType.ai;

    // Save current game state to redo stack
    _redoStack.add(currentState.gameState);

    if (isVsAI && _history.length >= 2) {
      // For AI games, undo both player's move and AI's response
      // Pop the last state (which was the state before AI's last move)
      _history.removeLast();
      // If there's a state before that (before player's move), go back to it
      if (_history.isNotEmpty) {
        final previousState = _history.removeLast();
        emit(currentState.copyWith(
          gameState: previousState,
          clearSelection: true,
          legalMoves: {},
          isAIThinking: false,
        ));
      }
    } else {
      // For vs human games or when not enough history, undo single move
      final previousState = _history.removeLast();

      emit(currentState.copyWith(
        gameState: previousState,
        clearSelection: true,
        legalMoves: {},
        isAIThinking: false,
      ));
    }
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

  @override
  Future<void> close() {
    final engine = _aiEngine;
    if (engine is MaiaAIEngine) {
      engine.dispose();
    }
    return super.close();
  }
}
