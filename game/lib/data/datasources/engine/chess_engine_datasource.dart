import '../../services/engine/chess_engine_service.dart';

class ChessEngineDataSource {
  final ChessEngineService _engineService;

  ChessEngineDataSource(this._engineService);

  Future<int> createNewGame() async {
    return await _engineService.newGame();
  }

  Future<void> makeMove(int gameId, String from, String to, {String? promotion}) async {
    return await _engineService.makeMove(gameId, from, to, promotion: promotion);
  }

  Future<bool> undo(int gameId) async {
    return await _engineService.undo(gameId);
  }

  Future<bool> redo(int gameId) async {
    return await _engineService.redo(gameId);
  }

  Future<List<String>> getLegalMoves(int gameId, String square) async {
    return await _engineService.getLegalMoves(gameId, square);
  }

  Future<String> getFen(int gameId) async {
    return await _engineService.getFen(gameId);
  }

  Future<void> setPosition(int gameId, String fen) async {
    return await _engineService.setPosition(gameId, fen);
  }
}
