import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:kings_gambit_ai/core/utils/logger.dart';

class StorageService {
  Future<String> getStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/kings_gambit_ai';
  }

  Future<void> saveGame(String gameId, Map<String, dynamic> data) async {
    try {
      final path = await getStoragePath();
      final directory = Directory(path);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final file = File('$path/game_$gameId.json');
      await file.writeAsString(jsonEncode(data));
      AppLogger.info('Game saved: $gameId');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save game', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> loadGame(String gameId) async {
    try {
      final path = await getStoragePath();
      final file = File('$path/game_$gameId.json');

      if (!file.existsSync()) {
        return null;
      }

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load game', e, stackTrace);
      return null;
    }
  }

  Future<List<String>> listSavedGames() async {
    try {
      final path = await getStoragePath();
      final directory = Directory(path);

      if (!directory.existsSync()) {
        return [];
      }

      final files = await directory.list().toList();
      return files
          .where((f) => f.path.endsWith('.json'))
          .map((f) => f.path.split('/').last.replaceAll('game_', '').replaceAll('.json', ''))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to list saved games', e, stackTrace);
      return [];
    }
  }

  Future<void> deleteGame(String gameId) async {
    try {
      final path = await getStoragePath();
      final file = File('$path/game_$gameId.json');

      if (file.existsSync()) {
        file.deleteSync();
        AppLogger.info('Game deleted: $gameId');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete game', e, stackTrace);
      rethrow;
    }
  }
}
