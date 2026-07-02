import '../../core/utils/logger.dart';
import 'chess_engine_service_interface.dart';

/// Web implementation of ChessEngineService
/// Since dart:ffi is not available on web, this provides a stub implementation
class ChessEngineServiceImpl implements ChessEngineService {
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize(String modelPath) async {
    try {
      AppLogger.info('Initializing chess engine (web stub)...');
      AppLogger.warning('Native chess engine is not available on web platform');
      _isInitialized = true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize chess engine', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> newGame() async {
    return 1;
  }

  @override
  Future<void> deleteGame(int gameId) async {
    // Web stub implementation
  }

  @override
  Future<void> resetGame(int gameId) async {
    // Web stub implementation
  }

  @override
  Future<void> setPosition(int gameId, String fen) async {
    // Web stub implementation
  }

  @override
  Future<String> getFen(int gameId) async {
    return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  }

  @override
  Future<void> makeMove(int gameId, String from, String to, {String? promotion}) async {
    // Web stub implementation
  }

  @override
  Future<bool> undo(int gameId) async {
    return true;
  }

  @override
  Future<bool> redo(int gameId) async {
    return true;
  }

  @override
  Future<List<String>> getLegalMoves(int gameId, String square) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllLegalMoves(int gameId) async {
    return [];
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _isInitialized = false;
    }
  }
}
