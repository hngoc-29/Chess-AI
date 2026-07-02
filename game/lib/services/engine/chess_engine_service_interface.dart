abstract class ChessEngineService {
  bool get isInitialized;

  Future<void> initialize(String modelPath);

  Future<int> newGame();

  Future<void> deleteGame(int gameId);

  Future<void> resetGame(int gameId);

  Future<void> setPosition(int gameId, String fen);

  Future<String> getFen(int gameId);

  Future<void> makeMove(int gameId, String from, String to, {String? promotion});

  Future<bool> undo(int gameId);

  Future<bool> redo(int gameId);

  Future<List<String>> getLegalMoves(int gameId, String square);

  Future<List<Map<String, dynamic>>> getAllLegalMoves(int gameId);

  void dispose();
}
