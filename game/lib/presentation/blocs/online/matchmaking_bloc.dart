import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../services/online/socket_io_service.dart';
import '../../../data/models/online/online_game_room.dart';
import '../../../core/utils/logger.dart';

// Events
abstract class MatchmakingEvent extends Equatable {
  const MatchmakingEvent();

  @override
  List<Object?> get props => [];
}

class JoinQueueRequested extends MatchmakingEvent {
  final int timeControlMinutes;
  final int incrementSeconds;

  const JoinQueueRequested({
    required this.timeControlMinutes,
    required this.incrementSeconds,
  });

  @override
  List<Object?> get props => [timeControlMinutes, incrementSeconds];
}

class LeaveQueueRequested extends MatchmakingEvent {
  const LeaveQueueRequested();
}

class MatchFound extends MatchmakingEvent {
  final OnlineGameRoom room;
  final String yourColor;

  const MatchFound({
    required this.room,
    required this.yourColor,
  });

  @override
  List<Object?> get props => [room, yourColor];
}

class QueueTimeout extends MatchmakingEvent {
  const QueueTimeout();
}

class MatchmakingErrorOccurred extends MatchmakingEvent {
  final String error;

  const MatchmakingErrorOccurred(this.error);

  @override
  List<Object?> get props => [error];
}

// States
abstract class MatchmakingState extends Equatable {
  const MatchmakingState();

  @override
  List<Object?> get props => [];
}

class MatchmakingIdle extends MatchmakingState {
  const MatchmakingIdle();
}

class MatchmakingSearching extends MatchmakingState {
  final int timeControlMinutes;
  final int incrementSeconds;
  final DateTime startedAt;

  const MatchmakingSearching({
    required this.timeControlMinutes,
    required this.incrementSeconds,
    required this.startedAt,
  });

  Duration get searchDuration => DateTime.now().difference(startedAt);

  @override
  List<Object?> get props => [timeControlMinutes, incrementSeconds, startedAt];
}

class MatchmakingMatchFound extends MatchmakingState {
  final OnlineGameRoom room;
  final String yourColor;

  const MatchmakingMatchFound({
    required this.room,
    required this.yourColor,
  });

  @override
  List<Object?> get props => [room, yourColor];
}

class MatchmakingTimedOut extends MatchmakingState {
  const MatchmakingTimedOut();
}

class MatchmakingError extends MatchmakingState {
  final String message;

  const MatchmakingError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class MatchmakingBloc extends Bloc<MatchmakingEvent, MatchmakingState> {
  final SocketIOService _socketService;
  StreamSubscription? _matchFoundSubscription;
  StreamSubscription? _errorSubscription;

  MatchmakingBloc({
    required SocketIOService socketService,
  })  : _socketService = socketService,
        super(const MatchmakingIdle()) {
    on<JoinQueueRequested>(_onJoinQueueRequested);
    on<LeaveQueueRequested>(_onLeaveQueueRequested);
    on<MatchFound>(_onMatchFound);
    on<QueueTimeout>(_onQueueTimeout);
    on<MatchmakingErrorOccurred>(_onMatchmakingErrorOccurred);

    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Listen for match found events
    _matchFoundSubscription = _socketService.matchFoundStream.listen((data) {
      try {
        final room = OnlineGameRoom.fromJson(data['room'] as Map<String, dynamic>);
        final yourColor = data['yourColor'] as String;
        add(MatchFound(room: room, yourColor: yourColor));
      } catch (e, stackTrace) {
        AppLogger.error('Failed to parse match found data', e, stackTrace);
        add(MatchmakingErrorOccurred('Failed to process match data'));
      }
    });

    // Listen for errors
    _errorSubscription = _socketService.errorStream.listen((error) {
      if (error.contains('timeout')) {
        add(const QueueTimeout());
      } else {
        add(MatchmakingErrorOccurred(error));
      }
    });
  }

  Future<void> _onJoinQueueRequested(
    JoinQueueRequested event,
    Emitter<MatchmakingState> emit,
  ) async {
    try {
      AppLogger.info('Joining matchmaking queue: ${event.timeControlMinutes}+${event.incrementSeconds}');

      final result = await _socketService.joinQueue(
        timeControlMinutes: event.timeControlMinutes,
        incrementSeconds: event.incrementSeconds,
      );

      if (result['ok'] == true) {
        emit(MatchmakingSearching(
          timeControlMinutes: event.timeControlMinutes,
          incrementSeconds: event.incrementSeconds,
          startedAt: DateTime.now(),
        ));
        AppLogger.info('Joined matchmaking queue successfully');
      } else {
        final error = result['error'] as String? ?? 'Failed to join queue';
        emit(MatchmakingError(error));
        AppLogger.error('Failed to join queue', error, StackTrace.current);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Join queue error', e, stackTrace);
      emit(MatchmakingError('Failed to join queue: $e'));
    }
  }

  Future<void> _onLeaveQueueRequested(
    LeaveQueueRequested event,
    Emitter<MatchmakingState> emit,
  ) async {
    try {
      _socketService.leaveQueue();
      emit(const MatchmakingIdle());
      AppLogger.info('Left matchmaking queue');
    } catch (e, stackTrace) {
      AppLogger.error('Leave queue error', e, stackTrace);
    }
  }

  Future<void> _onMatchFound(
    MatchFound event,
    Emitter<MatchmakingState> emit,
  ) async {
    emit(MatchmakingMatchFound(
      room: event.room,
      yourColor: event.yourColor,
    ));
    AppLogger.info('Match found: ${event.room.roomId}, playing as ${event.yourColor}');
  }

  Future<void> _onQueueTimeout(
    QueueTimeout event,
    Emitter<MatchmakingState> emit,
  ) async {
    emit(const MatchmakingTimedOut());
    AppLogger.info('Matchmaking timed out');
  }

  Future<void> _onMatchmakingErrorOccurred(
    MatchmakingErrorOccurred event,
    Emitter<MatchmakingState> emit,
  ) async {
    emit(MatchmakingError(event.error));
    AppLogger.error('Matchmaking error', event.error, StackTrace.current);
  }

  @override
  Future<void> close() {
    _matchFoundSubscription?.cancel();
    _errorSubscription?.cancel();
    return super.close();
  }
}
