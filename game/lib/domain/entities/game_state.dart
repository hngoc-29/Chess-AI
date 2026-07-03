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
    bool clearEnPassantSquare = false,
  }) {
    String? finalEnPassantSquare = enPassantSquare;
    if (clearEnPassantSquare) {
      finalEnPassantSquare = null;
    }
    
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
      enPassantSquare: finalEnPassantSquare ?? this.enPassantSquare,
      halfMoveClock: halfMoveClock ?? this.halfMoveClock,
      fullMoveNumber: fullMoveNumber ?? this.fullMoveNumber,
      isInCheck: isInCheck ?? this.isInCheck,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'board': board.toJson(),
      'currentTurn': currentTurn.name,
      'moveHistory': moveHistory.map((m) => m.toJson()).toList(),
      'status': status.name,
      'whitePlayer': whitePlayer.toJson(),
      'blackPlayer': blackPlayer.toJson(),
      'whiteCanCastleKingside': whiteCanCastleKingside,
      'whiteCanCastleQueenside': whiteCanCastleQueenside,
      'blackCanCastleKingside': blackCanCastleKingside,
      'blackCanCastleQueenside': blackCanCastleQueenside,
      'enPassantSquare': enPassantSquare,
      'halfMoveClock': halfMoveClock,
      'fullMoveNumber': fullMoveNumber,
      'isInCheck': isInCheck,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: json['gameId'] as int,
      board: Board.fromJson(json['board'] as Map<String, dynamic>),
      currentTurn: PieceColor.values.firstWhere((e) => e.name == json['currentTurn']),
      moveHistory: (json['moveHistory'] as List)
          .map((m) => ChessMove.fromJson(m as Map<String, dynamic>))
          .toList(),
      status: GameStatus.values.firstWhere((e) => e.name == json['status']),
      whitePlayer: Player.fromJson(json['whitePlayer'] as Map<String, dynamic>),
      blackPlayer: Player.fromJson(json['blackPlayer'] as Map<String, dynamic>),
      whiteCanCastleKingside: json['whiteCanCastleKingside'] as bool? ?? true,
      whiteCanCastleQueenside: json['whiteCanCastleQueenside'] as bool? ?? true,
      blackCanCastleKingside: json['blackCanCastleKingside'] as bool? ?? true,
      blackCanCastleQueenside: json['blackCanCastleQueenside'] as bool? ?? true,
      enPassantSquare: json['enPassantSquare'] as String?,
      halfMoveClock: json['halfMoveClock'] as int? ?? 0,
      fullMoveNumber: json['fullMoveNumber'] as int? ?? 1,
      isInCheck: json['isInCheck'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
