import '../../services/storage/storage_service.dart';

class GameLocalDataSource {
  final StorageService _storageService;

  GameLocalDataSource(this._storageService);

  Future<void> saveGame(String gameId, Map<String, dynamic> data) async {
    return await _storageService.saveGame(gameId, data);
  }

  Future<Map<String, dynamic>?> loadGame(String gameId) async {
    return await _storageService.loadGame(gameId);
  }

  Future<List<String>> listSavedGames() async {
    return await _storageService.listSavedGames();
  }

  Future<void> deleteGame(String gameId) async {
    return await _storageService.deleteGame(gameId);
  }
}
