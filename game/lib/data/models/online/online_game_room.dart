import 'package:equatable/equatable.dart';
import 'player_slot.dart';
import 'game_result.dart';

/// Room status
enum RoomStatus {
  waiting,
  active,
  finished;

  static RoomStatus fromString(String value) {
    switch (value) {
      case 'waiting':
        return RoomStatus.waiting;
      case 'active':
        return RoomStatus.active;
      case 'finished':
        return RoomStatus.finished;
      default:
        return RoomStatus.waiting;
    }
  }
}

/// Game mode
enum GameMode {
  ranked,
  custom,
  campaign;

  static GameMode fromString(String value) {
    switch (value) {
      case 'ranked':
        return GameMode.ranked;
      case 'custom':
        return GameMode.custom;
      case 'campaign':
        return GameMode.campaign;
      default:
        return GameMode.custom;
    }
  }
}

/// Time control configuration
class TimeControl extends Equatable {
  final int initialMs;
  final int incrementMs;

  const TimeControl({
    required this.initialMs,
    required this.incrementMs,
  });

  factory TimeControl.fromJson(Map<String, dynamic> json) {
    return TimeControl(
      initialMs: json['initialMs'] as int,
      incrementMs: json['incrementMs'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'initialMs': initialMs,
      'incrementMs': incrementMs,
    };
  }

  @override
  List<Object?> get props => [initialMs, incrementMs];
}

/// Complete online game room state
class OnlineGameRoom extends Equatable {
  final String roomId;
  final RoomStatus status;
  final GameMode mode;
  final bool rated;
  final String fen;
  final String turn; // 'w' or 'b'
  final PlayerSlot white;
  final PlayerSlot black;
  final TimeControl timeControl;
  final int whiteTimeLeftMs;
  final int blackTimeLeftMs;
  final String? drawOfferedBy; // 'w', 'b', or null
  final int spectatorCount;
  final GameResult? result;
  final int createdAt;
  final int? startedAt;
  final int? endedAt;
  final String? joinCode; // For custom rooms
  final bool allowSpectators;
  final int maxSpectators;

  const OnlineGameRoom({
    required this.roomId,
    required this.status,
    required this.mode,
    required this.rated,
    required this.fen,
    required this.turn,
    required this.white,
    required this.black,
    required this.timeControl,
    required this.whiteTimeLeftMs,
    required this.blackTimeLeftMs,
    this.drawOfferedBy,
    required this.spectatorCount,
    this.result,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.joinCode,
    required this.allowSpectators,
    required this.maxSpectators,
  });

  factory OnlineGameRoom.fromJson(Map<String, dynamic> json) {
    return OnlineGameRoom(
      roomId: json['roomId'] as String,
      status: RoomStatus.fromString(json['status'] as String),
      mode: GameMode.fromString(json['mode'] as String),
      rated: json['rated'] as bool,
      fen: json['fen'] as String,
      turn: json['turn'] as String,
      white: PlayerSlot.fromJson(json['white'] as Map<String, dynamic>),
      black: PlayerSlot.fromJson(json['black'] as Map<String, dynamic>),
      timeControl: TimeControl.fromJson(json['timeControl'] as Map<String, dynamic>),
      whiteTimeLeftMs: json['whiteTimeLeftMs'] as int,
      blackTimeLeftMs: json['blackTimeLeftMs'] as int,
      drawOfferedBy: json['drawOfferedBy'] as String?,
      spectatorCount: json['spectatorCount'] as int? ?? 0,
      result: json['result'] != null 
          ? GameResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as int,
      startedAt: json['startedAt'] as int?,
      endedAt: json['endedAt'] as int?,
      joinCode: json['joinCode'] as String?,
      allowSpectators: json['allowSpectators'] as bool? ?? true,
      maxSpectators: json['maxSpectators'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'status': status.name,
      'mode': mode.name,
      'rated': rated,
      'fen': fen,
      'turn': turn,
      'white': white.toJson(),
      'black': black.toJson(),
      'timeControl': timeControl.toJson(),
      'whiteTimeLeftMs': whiteTimeLeftMs,
      'blackTimeLeftMs': blackTimeLeftMs,
      'drawOfferedBy': drawOfferedBy,
      'spectatorCount': spectatorCount,
      'result': result?.toJson(),
      'createdAt': createdAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'joinCode': joinCode,
      'allowSpectators': allowSpectators,
      'maxSpectators': maxSpectators,
    };
  }

  OnlineGameRoom copyWith({
    String? roomId,
    RoomStatus? status,
    GameMode? mode,
    bool? rated,
    String? fen,
    String? turn,
    PlayerSlot? white,
    PlayerSlot? black,
    TimeControl? timeControl,
    int? whiteTimeLeftMs,
    int? blackTimeLeftMs,
    String? drawOfferedBy,
    int? spectatorCount,
    GameResult? result,
    int? createdAt,
    int? startedAt,
    int? endedAt,
    String? joinCode,
    bool? allowSpectators,
    int? maxSpectators,
  }) {
    return OnlineGameRoom(
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      rated: rated ?? this.rated,
      fen: fen ?? this.fen,
      turn: turn ?? this.turn,
      white: white ?? this.white,
      black: black ?? this.black,
      timeControl: timeControl ?? this.timeControl,
      whiteTimeLeftMs: whiteTimeLeftMs ?? this.whiteTimeLeftMs,
      blackTimeLeftMs: blackTimeLeftMs ?? this.blackTimeLeftMs,
      drawOfferedBy: drawOfferedBy ?? this.drawOfferedBy,
      spectatorCount: spectatorCount ?? this.spectatorCount,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      joinCode: joinCode ?? this.joinCode,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      maxSpectators: maxSpectators ?? this.maxSpectators,
    );
  }

  @override
  List<Object?> get props => [
        roomId,
        status,
        mode,
        rated,
        fen,
        turn,
        white,
        black,
        timeControl,
        whiteTimeLeftMs,
        blackTimeLeftMs,
        drawOfferedBy,
        spectatorCount,
        result,
        createdAt,
        startedAt,
        endedAt,
        joinCode,
        allowSpectators,
        maxSpectators,
      ];
}
