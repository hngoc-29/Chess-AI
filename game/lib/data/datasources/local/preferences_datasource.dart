import 'package:shared_preferences/shared_preferences.dart';

class PreferencesDataSource {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _volumeKey = 'volume';
  static const String _boardThemeKey = 'board_theme';
  static const String _pieceSetKey = 'piece_set';
  static const String _darkModeKey = 'dark_mode';
  static const String _aiDifficultyKey = 'ai_difficulty';

  Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
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
}
