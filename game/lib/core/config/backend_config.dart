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
