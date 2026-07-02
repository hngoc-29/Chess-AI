import '../../core/utils/logger.dart';
import '../engine/chess_engine_service.dart';

class AIMove {
  final String from;
  final String to;
  final String? promotion;
  final int nodesSearched;
  final int depth;
  final double evaluation;

  const AIMove({
    required this.from,
    required this.to,
    this.promotion,
    required this.nodesSearched,
    required this.depth,
    required this.evaluation,
  });
}

class AIService {
  final ChessEngineService _engineService;

  AIService(this._engineService);

  Future<AIMove> getAIMove(
    int gameId, {
    int difficulty = 5,
    Duration? maxTime,
  }) async {
    try {
      AppLogger.info('AI thinking... (difficulty: $difficulty)');

      await Future.delayed(maxTime ?? const Duration(seconds: 2));

      return const AIMove(
        from: 'e7',
        to: 'e5',
        nodesSearched: 10000,
        depth: 10,
        evaluation: 0.0,
      );
    } catch (e, stackTrace) {
      AppLogger.error('AI move generation failed', e, stackTrace);
      rethrow;
    }
  }

  Future<int> startAIThinking(
    int gameId, {
    int difficulty = 5,
    Duration? maxTime,
  }) async {
    return 1;
  }

  Future<void> cancelAIThinking(int thinkingId) async {
  }

  Future<bool> isAIThinking(int thinkingId) async {
    return false;
  }

  Stream<Map<String, dynamic>> getAIProgress(int thinkingId) async* {
    yield {
      'nodesSearched': 5000,
      'depth': 8,
      'progress': 0.5,
    };
  }
}
