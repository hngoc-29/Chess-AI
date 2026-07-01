import 'package:equatable/equatable.dart';

import 'board.dart';
import 'chess_move.dart';
import 'piece.dart';
import 'player.dart';

enum GameStatus {
  ongoing,
  checkmate,
  stalemate,
  drawByRepetition,
  drawByFiftyMoveRule,
  drawByInsufficientMaterial,
  resigned,
}

class GameState extends Equatable {
  final int gameId;
  final Board board;
  final PieceColor currentTurn;
  final List<ChessMove> moveHistory;
  final GameStatus status;
  final Player whitePlayer;
  final Player blackPlayer;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final String? enPassantSquare;
  final int halfMoveClock;
  final int fullMoveNumber;
  final bool isInCheck;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GameState({
    required this.gameId,
    required this.board,
    required this.currentTurn,
    required this.moveHistory,
    required this.status,
    required this.whitePlayer,
    required this.blackPlayer,
    this.whiteCanCastleKingside = true,
    this.whiteCanCastleQueenside = true,
    this.blackCanCastleKingside = true,
    this.blackCanCastleQueenside = true,
    this.enPassantSquare,
    this.halfMoveClock = 0,
    this.fullMoveNumber = 1,
    this.isInCheck = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameState.initial({
    required int gameId,
    required Player whitePlayer,
    required Player blackPlayer,
  }) {
    final now = DateTime.now();
    return GameState(
      gameId: gameId,
      board: Board.initial(),
      currentTurn: PieceColor.white,
      moveHistory: const [],
      status: GameStatus.ongoing,
      whitePlayer: whitePlayer,
      blackPlayer: blackPlayer,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get isGameOver => status != GameStatus.ongoing;
  bool get isWhiteTurn => currentTurn == PieceColor.white;
  bool get isBlackTurn => currentTurn == PieceColor.black;

  Player get currentPlayer => isWhiteTurn ? whitePlayer : blackPlayer;
  Player get opponentPlayer => isWhiteTurn ? blackPlayer : whitePlayer;

  ChessMove? get lastMove => moveHistory.isEmpty ? null : moveHistory.last;

  GameState copyWith({
    int? gameId,
    Board? board,
    PieceColor? currentTurn,
    List<ChessMove>? moveHistory,
    GameStatus? status,
    Player? whitePlayer,
    Player? blackPlayer,
    bool? whiteCanCastleKingside,
    bool? whiteCanCastleQueenside,
    bool? blackCanCastleKingside,
    bool? blackCanCastleQueenside,
    String? enPassantSquare,
    int? halfMoveClock,
    int? fullMoveNumber,
    bool? isInCheck,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      board: board ?? this.board,
      currentTurn: currentTurn ?? this.currentTurn,
      moveHistory: moveHistory ?? this.moveHistory,
      status: status ?? this.status,
      whitePlayer: whitePlayer ?? this.whitePlayer,
      blackPlayer: blackPlayer ?? this.blackPlayer,
      whiteCanCastleKingside: whiteCanCastleKingside ?? this.whiteCanCastleKingside,
      whiteCanCastleQueenside: whiteCanCastleQueenside ?? this.whiteCanCastleQueenside,
      blackCanCastleKingside: blackCanCastleKingside ?? this.blackCanCastleKingside,
      blackCanCastleQueenside: blackCanCastleQueenside ?? this.blackCanCastleQueenside,
      enPassantSquare: enPassantSquare ?? this.enPassantSquare,
      halfMoveClock: halfMoveClock ?? this.halfMoveClock,
      fullMoveNumber: fullMoveNumber ?? this.fullMoveNumber,
      isInCheck: isInCheck ?? this.isInCheck,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        gameId,
        board,
        currentTurn,
        moveHistory,
        status,
        whitePlayer,
        blackPlayer,
        whiteCanCastleKingside,
        whiteCanCastleQueenside,
        blackCanCastleKingside,
        blackCanCastleQueenside,
        enPassantSquare,
        halfMoveClock,
        fullMoveNumber,
        isInCheck,
        createdAt,
        updatedAt,
      ];
}
