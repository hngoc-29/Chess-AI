import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../services/online/socket_io_service.dart';
import '../../../data/models/online/online_game_room.dart';
import '../../../data/models/online/move_record.dart';
import '../../../data/models/online/chat_models.dart';
import '../../../core/utils/logger.dart';

// Events
abstract class OnlineGameEvent extends Equatable {
  const OnlineGameEvent();
  @override
  List<Object?> get props => [];
}

class GameInitialized extends OnlineGameEvent {
  final OnlineGameRoom room;
  final String playerColor;
  const GameInitialized({required this.room, required this.playerColor});
  @override
  List<Object?> get props => [room, playerColor];
}

class MoveMade extends OnlineGameEvent {
  final String from;
  final String to;
  final String? promotion;
  const MoveMade({required this.from, required this.to, this.promotion});
  @override
  List<Object?> get props => [from, to, promotion];
}

class GameStateUpdated extends OnlineGameEvent {
  final OnlineGameRoom room;
  const GameStateUpdated(this.room);
  @override
  List<Object?> get props => [room];
}

class MoveAppliedReceived extends OnlineGameEvent {
  final MoveRecord move;
  final OnlineGameRoom state;
  const MoveAppliedReceived({required this.move, required this.state});
  @override
  List<Object?> get props => [move, state];
}

class GameOverReceived extends OnlineGameEvent {
  final Map<String, dynamic> data;
  const GameOverReceived(this.data);
  @override
  List<Object?> get props => [data];
}

class ResignRequested extends OnlineGameEvent {
  const ResignRequested();
}

class DrawOffered extends OnlineGameEvent {
  const DrawOffered();
}

class DrawResponseSent extends OnlineGameEvent {
  final bool accept;
  const DrawResponseSent(this.accept);
  @override
  List<Object?> get props => [accept];
}

class ChatMessageSent extends OnlineGameEvent {
  final String text;
  const ChatMessageSent(this.text);
  @override
  List<Object?> get props => [text];
}

class ChatMessageReceived extends OnlineGameEvent {
  final ChatMessage message;
  const ChatMessageReceived(this.message);
  @override
  List<Object?> get props => [message];
}

// States
abstract class OnlineGameState extends Equatable {
  const OnlineGameState();
  @override
  List<Object?> get props => [];
}

class OnlineGameInitial extends OnlineGameState {
  const OnlineGameInitial();
}

class OnlineGamePlaying extends OnlineGameState {
  final OnlineGameRoom room;
  final String playerColor;
  final List<MoveRecord> moves;
  final List<ChatMessage> chatMessages;
  final bool isMyTurn;

  const OnlineGamePlaying({
    required this.room,
    required this.playerColor,
    required this.moves,
    required this.chatMessages,
    required this.isMyTurn,
  });

  @override
  List<Object?> get props => [room, playerColor, moves, chatMessages, isMyTurn];

  OnlineGamePlaying copyWith({
    OnlineGameRoom? room,
    String? playerColor,
    List<MoveRecord>? moves,
    List<ChatMessage>? chatMessages,
    bool? isMyTurn,
  }) {
    return OnlineGamePlaying(
      room: room ?? this.room,
      playerColor: playerColor ?? this.playerColor,
      moves: moves ?? this.moves,
      chatMessages: chatMessages ?? this.chatMessages,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }
}

class OnlineGameFinished extends OnlineGameState {
  final OnlineGameRoom room;
  final String playerColor;
  final List<MoveRecord> moves;
  final String pgn;
  final String finalFen;

  const OnlineGameFinished({
    required this.room,
    required this.playerColor,
    required this.moves,
    required this.pgn,
    required this.finalFen,
  });

  @override
  List<Object?> get props => [room, playerColor, moves, pgn, finalFen];
}

class OnlineGameError extends OnlineGameState {
  final String message;
  const OnlineGameError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class OnlineGameBloc extends Bloc<OnlineGameEvent, OnlineGameState> {
  final SocketIOService _socketService;
  StreamSubscription? _gameStateSubscription;
  StreamSubscription? _moveAppliedSubscription;
  StreamSubscription? _gameOverSubscription;
  StreamSubscription? _chatSubscription;

  OnlineGameBloc({required SocketIOService socketService})
      : _socketService = socketService,
        super(const OnlineGameInitial()) {
    on<GameInitialized>(_onGameInitialized);
    on<MoveMade>(_onMoveMade);
    on<GameStateUpdated>(_onGameStateUpdated);
    on<MoveAppliedReceived>(_onMoveAppliedReceived);
    on<GameOverReceived>(_onGameOverReceived);
    on<ResignRequested>(_onResignRequested);
    on<DrawOffered>(_onDrawOffered);
    on<DrawResponseSent>(_onDrawResponseSent);
    on<ChatMessageSent>(_onChatMessageSent);
    on<ChatMessageReceived>(_onChatMessageReceived);

    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _gameStateSubscription = _socketService.gameStateStream.listen((room) {
      add(GameStateUpdated(room));
    });

    _moveAppliedSubscription = _socketService.moveAppliedStream.listen((data) {
      final move = MoveRecord.fromJson(data['move'] as Map<String, dynamic>);
      final state = OnlineGameRoom.fromJson(data['state'] as Map<String, dynamic>);
      add(MoveAppliedReceived(move: move, state: state));
    });

    _gameOverSubscription = _socketService.gameOverStream.listen((data) {
      add(GameOverReceived(data));
    });

    _chatSubscription = _socketService.chatMessageStream.listen((message) {
      add(ChatMessageReceived(message));
    });
  }

  Future<void> _onGameInitialized(GameInitialized event, Emitter<OnlineGameState> emit) async {
    final isMyTurn = event.room.turn == event.playerColor;
    emit(OnlineGamePlaying(
      room: event.room,
      playerColor: event.playerColor,
      moves: [],
      chatMessages: [],
      isMyTurn: isMyTurn,
    ));
  }

  Future<void> _onMoveMade(MoveMade event, Emitter<OnlineGameState> emit) async {
    if (state is! OnlineGamePlaying) return;
    final currentState = state as OnlineGamePlaying;

    try {
      final result = await _socketService.makeMove(
        roomId: currentState.room.roomId,
        from: event.from,
        to: event.to,
        promotion: event.promotion,
        expectedMoveIndex: currentState.moves.length,
      );

      if (result['ok'] != true) {
        AppLogger.error('Move failed', result['error'], StackTrace.current);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Move error', e, stackTrace);
    }
  }

  Future<void> _onGameStateUpdated(GameStateUpdated event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      final isMyTurn = event.room.turn == currentState.playerColor;
      emit(currentState.copyWith(room: event.room, isMyTurn: isMyTurn));
    }
  }

  Future<void> _onMoveAppliedReceived(MoveAppliedReceived event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      final updatedMoves = [...currentState.moves, event.move];
      final isMyTurn = event.state.turn == currentState.playerColor;
      emit(currentState.copyWith(
        room: event.state,
        moves: updatedMoves,
        isMyTurn: isMyTurn,
      ));
    }
  }

  Future<void> _onGameOverReceived(GameOverReceived event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      final room = OnlineGameRoom.fromJson(event.data['room'] as Map<String, dynamic>? ?? currentState.room.toJson());
      emit(OnlineGameFinished(
        room: room,
        playerColor: currentState.playerColor,
        moves: currentState.moves,
        pgn: event.data['pgn'] as String? ?? '',
        finalFen: event.data['finalFen'] as String? ?? room.fen,
      ));
    }
  }

  Future<void> _onResignRequested(ResignRequested event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      await _socketService.resign(currentState.room.roomId);
    }
  }

  Future<void> _onDrawOffered(DrawOffered event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      await _socketService.offerDraw(currentState.room.roomId);
    }
  }

  Future<void> _onDrawResponseSent(DrawResponseSent event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      await _socketService.respondDraw(
        roomId: currentState.room.roomId,
        accept: event.accept,
      );
    }
  }

  Future<void> _onChatMessageSent(ChatMessageSent event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      await _socketService.sendChatMessage(
        roomId: currentState.room.roomId,
        text: event.text,
      );
    }
  }

  Future<void> _onChatMessageReceived(ChatMessageReceived event, Emitter<OnlineGameState> emit) async {
    if (state is OnlineGamePlaying) {
      final currentState = state as OnlineGamePlaying;
      final updatedMessages = [...currentState.chatMessages, event.message];
      emit(currentState.copyWith(chatMessages: updatedMessages));
    }
  }

  @override
  Future<void> close() {
    _gameStateSubscription?.cancel();
    _moveAppliedSubscription?.cancel();
    _gameOverSubscription?.cancel();
    _chatSubscription?.cancel();
    return super.close();
  }
}
