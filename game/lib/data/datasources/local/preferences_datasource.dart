import 'package:shared_preferences/shared_preferences.dart';

class PreferencesDataSource {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _volumeKey = 'volume';
  static const String _boardThemeKey = 'board_theme';
  static const String _pieceSetKey = 'piece_set';
  static const String _darkModeKey = 'dark_mode';
  static const String _aiDifficultyKey = 'ai_difficulty';

  // Statistics keys
  static const String _totalGamesKey = 'total_games';
  static const String _winsKey = 'wins';
  static const String _lossesKey = 'losses';
  static const String _drawsKey = 'draws';

  Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }

  Future<bool> getMusicEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_musicEnabledKey) ?? true;
  }

  Future<void> setMusicEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, enabled);
  }

  Future<double> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_volumeKey) ?? 1.0;
  }

  Future<void> setVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, volume);
  }

  Future<String> getBoardTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_boardThemeKey) ?? 'brown';
  }

  Future<void> setBoardTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boardThemeKey, theme);
  }

  Future<String> getPieceSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pieceSetKey) ?? 'cburnett';
  }

  Future<void> setPieceSet(String pieceSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pieceSetKey, pieceSet);
  }

  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<int> getAIDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_aiDifficultyKey) ?? 5;
  }

  Future<void> setAIDifficulty(int difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiDifficultyKey, difficulty);
  }

  // Statistics methods
  Future<int> getTotalGames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalGamesKey) ?? 0;
  }

  Future<int> getWins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_winsKey) ?? 0;
  }

  Future<int> getLosses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lossesKey) ?? 0;
  }

  Future<int> getDraws() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_drawsKey) ?? 0;
  }

  Future<void> incrementTotalGames() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalGamesKey) ?? 0;
    await prefs.setInt(_totalGamesKey, current + 1);
  }

  Future<void> incrementWins() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_winsKey) ?? 0;
    await prefs.setInt(_winsKey, current + 1);
  }

  Future<void> incrementLosses() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_lossesKey) ?? 0;
    await prefs.setInt(_lossesKey, current + 1);
  }

  Future<void> incrementDraws() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_drawsKey) ?? 0;
    await prefs.setInt(_drawsKey, current + 1);
  }

  Future<void> resetStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalGamesKey, 0);
    await prefs.setInt(_winsKey, 0);
    await prefs.setInt(_lossesKey, 0);
    await prefs.setInt(_drawsKey, 0);
  }
}
