import 'environment.dart';

/// Backend API configuration
/// Uses EnvironmentConfig to automatically select correct URLs based on build environment
class BackendConfig {
  // Backend URL - automatically set based on environment (dev/staging/prod)
  static String get backendUrl => EnvironmentConfig.current.backendUrl;
  
  // API endpoints - dynamically built from backendUrl
  static String get apiBase => '$backendUrl/api';
  static String get authEndpoint => '$apiBase/auth';
  static String get matchesEndpoint => '$apiBase/matches';
  static String get campaignEndpoint => '$apiBase/campaign';
  static String get healthEndpoint => '$backendUrl/health';

  /// The **Web application** OAuth client ID from Google Cloud Console -
  /// NOT the Android or iOS one. Passed as GoogleSignIn's `serverClientId`
  /// so the ID token it returns has this as its audience, which is the
  /// same value the backend checks against (GOOGLE_OAUTH_CLIENT_ID env
  /// var - see game/docs/OAUTH_SETUP.md). The Android/iOS OAuth clients
  /// still need to exist in the same Cloud project (package name/SHA-1,
  /// Bundle ID) for native sign-in to work at all, but their IDs aren't
  /// referenced anywhere in this app's code or config - Google matches
  /// them automatically at runtime.
  ///
  /// Set at build/run time so this doesn't need editing per environment:
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  
  // Socket.IO configuration
  static String get socketUrl => backendUrl;
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 5;
  
  // Game configuration
  static const Duration matchmakingTimeout = Duration(seconds: 60);
  static const Duration reconnectGracePeriod = Duration(seconds: 30);
  
  // Rate limiting (client-side hints)
  static const int maxMovesPerSecond = 10;
  static const int maxChatMessagesPerWindow = 3;
  static const Duration chatRateLimitWindow = Duration(seconds: 2);
}
