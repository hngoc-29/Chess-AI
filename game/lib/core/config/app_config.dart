class AppConfig {
  AppConfig._();

  static const String appName = 'Chess AI';
  static const String appVersion = '1.0.0';

  static const String modelPath = 'models/best_model_traced.pt';

  static const bool enableLogging = true;
  static const bool enableAnalytics = false;

  static const String defaultLanguage = 'en';
  static const List<String> supportedLanguages = ['en', 'vi'];

  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration autoSaveInterval = Duration(minutes: 5);

  static const int maxSavedGames = 100;

  static const bool debugMode = false;
}
