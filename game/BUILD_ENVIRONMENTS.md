# Environment Configuration Guide

## Overview

This project uses environment-based configuration to support multiple deployment environments (development, staging, production) with different backend URLs and Supabase credentials.

## Environment Files

### `lib/core/config/environment.dart`
Contains configuration for all environments:
- **Development**: Local backend (http://localhost:8080)
- **Staging**: Test deployment backend
- **Production**: Live production backend

### `lib/core/config/backend_config.dart`
Automatically uses the correct environment configuration based on build settings.

## Configuration Steps

### 1. Update Environment URLs

Edit `lib/core/config/environment.dart` and replace placeholder values:

```dart
// Development environment
static const development = EnvironmentConfig(
  environment: Environment.development,
  backendUrl: 'http://localhost:8080',  // Local backend
  supabaseUrl: 'https://your-dev-project.supabase.co',
  supabaseAnonKey: 'your_dev_anon_key_here',
  enableLogging: true,
  enableDebugMode: true,
);

// Staging environment
static const staging = EnvironmentConfig(
  environment: Environment.staging,
  backendUrl: 'https://your-staging-backend.railway.app',
  supabaseUrl: 'https://your-staging-project.supabase.co',
  supabaseAnonKey: 'your_staging_anon_key_here',
  enableLogging: true,
  enableDebugMode: false,
);

// Production environment
static const production = EnvironmentConfig(
  environment: Environment.production,
  backendUrl: 'https://your-production-backend.railway.app',
  supabaseUrl: 'https://your-prod-project.supabase.co',
  supabaseAnonKey: 'your_prod_anon_key_here',
  enableLogging: false,
  enableDebugMode: false,
);
```

## Building for Different Environments

### Development Build (Default)

```bash
# Run locally with development backend
flutter run

# Build debug APK
flutter build apk --debug
```

### Staging Build

```bash
# Run with staging backend
flutter run --dart-define=ENVIRONMENT=staging

# Build staging release APK
flutter build apk --release --dart-define=ENVIRONMENT=staging

# Build staging AAB for Google Play (internal testing)
flutter build appbundle --release --dart-define=ENVIRONMENT=staging
```

### Production Build

```bash
# Run with production backend
flutter run --dart-define=ENVIRONMENT=production

# Build production release APK
flutter build apk --release --dart-define=ENVIRONMENT=production

# Build production AAB for Google Play
flutter build appbundle --release --dart-define=ENVIRONMENT=production

# Build iOS (requires Mac)
flutter build ios --release --dart-define=ENVIRONMENT=production
```

## Security Notes

### ⚠️ URLs Cannot Be Completely Hidden

**Important**: In Flutter mobile apps, backend URLs and API keys cannot be completely hidden from users because:

1. **Compiled Code**: Flutter compiles to native code, but strings can still be extracted from the binary
2. **Network Inspection**: API calls can be intercepted using network sniffing tools (Charles Proxy, Wireshark)
3. **Reverse Engineering**: APK/IPA files can be decompiled

### 🔒 Security Best Practices

Instead of hiding URLs, implement proper security:

1. **Use Authentication**: All API calls require valid JWT tokens
2. **Rate Limiting**: Backend enforces rate limits to prevent abuse
3. **API Key Rotation**: Regularly rotate Supabase anon keys
4. **Server-Side Validation**: Never trust client-side data
5. **HTTPS Only**: All API calls use encrypted HTTPS
6. **Obfuscation**: Use Flutter's code obfuscation for production builds:
   ```bash
   flutter build apk --release --obfuscate --split-debug-info=./debug-info
   ```

### ℹ️ Supabase Anon Key

The Supabase `anon` key is **meant to be public** and safe to include in client apps. It provides:
- Read access to public tables only
- RLS (Row Level Security) policies control data access
- Requires user authentication for protected data

The `service_role` key (used in backend) must NEVER be exposed to clients.

## Environment Detection

Check current environment in code:

```dart
import 'package:kings_gambit_ai/core/config/environment.dart';

if (EnvironmentConfig.current.isDevelopment) {
  print('Running in development mode');
}

if (EnvironmentConfig.current.isProduction) {
  print('Running in production mode');
}

// Access configuration
final backendUrl = EnvironmentConfig.current.backendUrl;
final enableLogs = EnvironmentConfig.current.enableLogging;
```

## Automated Build Scripts

Create scripts to simplify builds:

### `scripts/build_staging.sh`
```bash
#!/bin/bash
flutter build appbundle --release --dart-define=ENVIRONMENT=staging
```

### `scripts/build_production.sh`
```bash
#!/bin/bash
flutter build appbundle --release --obfuscate --split-debug-info=./debug-info --dart-define=ENVIRONMENT=production
```

Make scripts executable:
```bash
chmod +x scripts/build_*.sh
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Build Production APK
  run: flutter build apk --release --dart-define=ENVIRONMENT=production
  
- name: Build Production AAB
  run: flutter build appbundle --release --dart-define=ENVIRONMENT=production
```

## Troubleshooting

### Environment Not Switching
- Ensure you use `--dart-define=ENVIRONMENT=production` flag
- Clean build: `flutter clean && flutter pub get`
- Check `environment.dart` has correct URLs for each environment

### Backend Connection Failed
- Verify backend URL is accessible (try in browser)
- Check CORS settings on backend allow your app domain
- Ensure Supabase credentials are correct
- Check network connectivity and firewall settings

### Supabase Auth Failed
- Verify Supabase project URL and anon key
- Check OAuth providers are enabled in Supabase Dashboard
- Ensure redirect URLs are configured correctly
