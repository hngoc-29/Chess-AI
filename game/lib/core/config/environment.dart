/// Environment configuration for different build flavors
/// 
/// Usage:
/// 1. Development build (default):
///    flutter run
/// 
/// 2. Production build:
///    flutter build apk --release --dart-define=ENVIRONMENT=production
/// 
/// 3. Staging build:
///    flutter build apk --release --dart-define=ENVIRONMENT=staging

enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  final Environment environment;
  final String backendUrl;
  final bool enableLogging;
  final bool enableDebugMode;

  const EnvironmentConfig({
    required this.environment,
    required this.backendUrl,
    required this.enableLogging,
    required this.enableDebugMode,
  });

  /// Development environment - local/test backend
  static const development = EnvironmentConfig(
    environment: Environment.development,
    backendUrl: 'https://chess-ai-backend-c0au.onrender.com',
    enableLogging: true,
    enableDebugMode: true,
  );

  /// Staging environment - test deployment
  static const staging = EnvironmentConfig(
    environment: Environment.staging,
    backendUrl: 'https://your-staging-backend.railway.app',
    enableLogging: true,
    enableDebugMode: false,
  );

  /// Production environment - live deployment
  static const production = EnvironmentConfig(
    environment: Environment.production,
    backendUrl: 'https://your-production-backend.railway.app',
    enableLogging: false,
    enableDebugMode: false,
  );

  /// Get current environment from dart-define or default to development
  static EnvironmentConfig get current {
    const envString = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    
    switch (envString.toLowerCase()) {
      case 'production':
      case 'prod':
        return production;
      case 'staging':
      case 'stage':
        return staging;
      case 'development':
      case 'dev':
      default:
        return development;
    }
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}
