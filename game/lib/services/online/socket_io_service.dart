import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/config/backend_config.dart';
import '../../../core/utils/logger.dart';
import '../../models/online/online_game_room.dart';
import '../../models/online/move_record.dart';
import '../../models/online/chat_models.dart';

/// Socket connection states
enum SocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Socket.IO service for real-time online gameplay
class SocketIOService {
  io.Socket? _socket;
  SocketState _state = SocketState.disconnected;
  String? _accessToken;

  // Stream controllers for events
  final _stateController = StreamController<SocketState>.broadcast();
  final _matchFoundController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStateController = StreamController<OnlineGameRoom>.broadcast();
  final _moveAppliedController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameOverController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController = StreamController<ChatMessage>.broadcast();
  final _chatReactionController = StreamController<ChatReaction>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Public streams
  Stream<SocketState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get matchFoundStream => _matchFoundController.stream;
  Stream<OnlineGameRoom> get gameStateStream => _gameStateController.stream;
  Stream<Map<String, dynamic>> get moveAppliedStream => _moveAppliedController.stream;
  Stream<Map<String, dynamic>> get gameOverStream => _gameOverController.stream;
  Stream<ChatMessage> get chatMessageStream => _chatMessageController.stream;
  Stream<ChatReaction> get chatReactionStream => _chatReactionController.stream;
  Stream<String> get errorStream => _errorController.stream;

  SocketState get state => _state;
  bool get isConnected => _state == SocketState.connected;

  /// Connect to backend with access token
  Future<void> connect(String accessToken) async {
    if (_socket != null && _socket!.connected) {
      AppLogger.info('Socket already connected');
      return;
    }

    _accessToken = accessToken;
    _updateState(SocketState.connecting);

    try {
      _socket = io.io(
        BackendConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(BackendConfig.maxReconnectAttempts)
            .setReconnectionDelay(BackendConfig.reconnectDelay.inMilliseconds)
            .setAuth({'token': accessToken})
            .build(),
      );

      _registerEventListeners();
      AppLogger.info('Socket.IO connecting...');
    } catch (e, stackTrace) {
      AppLogger.error('Socket connection error', e, stackTrace);
      _updateState(SocketState.error);
      _errorController.add('Connection failed: $e');
    }
  }

  /// Register all event listeners
  void _registerEventListeners() {
    _socket!.onConnect((_) {
      AppLogger.info('Socket connected');
      _updateState(SocketState.connected);
    });

    _socket!.onDisconnect((_) {
      AppLogger.info('Socket disconnected');
      _updateState(SocketState.disconnected);
    });

    _socket!.onConnectError((error) {
      AppLogger.error('Socket connect error', error, StackTrace.current);
      _updateState(SocketState.error);
      _errorController.add('Connection error: $error');
    });

    _socket!.onReconnect((_) {
      AppLogger.info('Socket reconnected');
      _updateState(SocketState.connected);
    });

    _socket!.onReconnecting((_) {
      AppLogger.info('Socket reconnecting...');
      _updateState(SocketState.reconnecting);
    });

    // Game events
    _socket!.on('match:found', (data) {
      AppLogger.info('Match found: $data');
      _matchFoundController.add(data as Map<String, dynamic>);
    });

    _socket!.on('game:state', (data) {
      try {
        final room = OnlineGameRoom.fromJson(data as Map<String, dynamic>);
        _gameStateController.add(room);
      } catch (e, stackTrace) {
        AppLogger.error('Failed to parse game state', e, stackTrace);
      }
    });

    _socket!.on('game:move_applied', (data) {
      _moveAppliedController.add(data as Map<String, dynamic>);
    });

    _socket!.on('game:over', (data) {
      AppLogger.info('Game over: $data');
      _gameOverController.add(data as Map<String, dynamic>);
    });

    // Chat events
    _socket!.on('chat:message_received', (data) {
      try {
        final message = ChatMessage.fromJson(data as Map<String, dynamic>);
        _chatMessageController.add(message);
      } catch (e, stackTrace) {
        AppLogger.error('Failed to parse chat message', e, stackTrace);
      }
    });

    _socket!.on('chat:reaction_received', (data) {
      try {
        final reaction = ChatReaction.fromJson(data as Map<String, dynamic>);
        _chatReactionController.add(reaction);
      } catch (e, stackTrace) {
        AppLogger.error('Failed to parse chat reaction', e, stackTrace);
      }
    });

    // Error events
    _socket!.on('queue:timeout', (data) {
      _errorController.add('Matchmaking timeout');
    });

    _socket!.on('room:error', (data) {
      final message = (data as Map<String, dynamic>)['message'] as String;
      _errorController.add(message);
    });

    _socket!.on('game:error', (data) {
      final message = (data as Map<String, dynamic>)['message'] as String;
      _errorController.add(message);
    });
  }

  /// Join matchmaking queue
  Future<Map<String, dynamic>> joinQueue({
    required int timeControlMinutes,
    required int incrementSeconds,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('queue:join', {
      'timeControlMinutes': timeControlMinutes,
      'incrementSeconds': incrementSeconds,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Leave matchmaking queue
  void leaveQueue() {
    _socket!.emit('queue:leave');
  }

  /// Make a move
  Future<Map<String, dynamic>> makeMove({
    required String roomId,
    required String from,
    required String to,
    String? promotion,
    int? expectedMoveIndex,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('game:move', {
      'roomId': roomId,
      'from': from,
      'to': to,
      'promotion': promotion,
      'expectedMoveIndex': expectedMoveIndex,
      'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Resign game
  Future<Map<String, dynamic>> resign(String roomId) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('game:resign', {
      'roomId': roomId,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Offer draw
  Future<Map<String, dynamic>> offerDraw(String roomId) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('game:draw_offer', {
      'roomId': roomId,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Respond to draw offer
  Future<Map<String, dynamic>> respondDraw({
    required String roomId,
    required bool accept,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('game:draw_respond', {
      'roomId': roomId,
      'accept': accept,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Send chat message
  Future<Map<String, dynamic>> sendChatMessage({
    required String roomId,
    required String text,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('chat:message', {
      'roomId': roomId,
      'text': text,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Send chat reaction
  Future<Map<String, dynamic>> sendChatReaction({
    required String roomId,
    required String emoji,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    
    _socket!.emitWithAck('chat:reaction', {
      'roomId': roomId,
      'emoji': emoji,
    }, ack: (response) {
      completer.complete(response as Map<String, dynamic>);
    });

    return completer.future;
  }

  /// Update state and notify listeners
  void _updateState(SocketState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Disconnect socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateState(SocketState.disconnected);
    AppLogger.info('Socket disconnected manually');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _stateController.close();
    _matchFoundController.close();
    _gameStateController.close();
    _moveAppliedController.close();
    _gameOverController.close();
    _chatMessageController.close();
    _chatReactionController.close();
    _errorController.close();
  }
}
