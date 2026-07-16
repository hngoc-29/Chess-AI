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
///
/// 4. Point at any backend without touching source (e.g. a local server
///    while testing, or a temporary staging URL) - takes priority over
///    whichever of the three presets above ENVIRONMENT would otherwise
///    select:
///    flutter run --dart-define=BACKEND_URL_OVERRIDE=http://192.168.1.23:8080

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
    backendUrl: 'https://chess-ai-backend-c0au.onrender.com',
    enableLogging: true,
    enableDebugMode: false,
  );

  /// Production environment - live deployment
  static const production = EnvironmentConfig(
    environment: Environment.production,
    backendUrl: 'https://chess-ai-backend-c0au.onrender.com',
    enableLogging: false,
    enableDebugMode: false,
  );

  /// Get current environment from dart-define or default to development.
  /// BACKEND_URL_OVERRIDE, if set, wins regardless of ENVIRONMENT - see
  /// the usage note above.
  static EnvironmentConfig get current {
    const envString = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    const urlOverride = String.fromEnvironment('BACKEND_URL_OVERRIDE', defaultValue: '');

    final EnvironmentConfig base;
    switch (envString.toLowerCase()) {
      case 'production':
      case 'prod':
        base = production;
        break;
      case 'staging':
      case 'stage':
        base = staging;
        break;
      case 'development':
      case 'dev':
      default:
        base = development;
    }

    if (urlOverride.isEmpty) return base;
    return EnvironmentConfig(
      environment: base.environment,
      backendUrl: urlOverride,
      enableLogging: base.enableLogging,
      enableDebugMode: base.enableDebugMode,
    );
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}
