import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/injection.dart';
import 'core/utils/logger.dart';
import 'presentation/app/app.dart';
import 'services/audio/audio_service.dart';
import 'services/storage/cache_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await _initializeApp();

    // Catch every uncaught Flutter framework/widget error (build, layout,
    // gesture callbacks, etc.) from here on. Previously these only showed
    // the red error screen / got silently swallowed in release mode -
    // nothing was written to the log file, so a widget-layer crash (as
    // opposed to one inside GameBloc's own try-catch) was invisible to us.
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        'Uncaught Flutter error: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
      FlutterError.presentError(details);
    };

    runApp(const KingsGambitAIApp());
  }, (error, stackTrace) {
    // Catches anything FlutterError.onError doesn't (e.g. errors thrown
    // from async gaps / microtasks outside the widget tree).
    AppLogger.error('Uncaught zone error', error, stackTrace);
  });
}

Future<void> _initializeApp() async {
  try {
    // Initialize logger FIRST để log tất cả các bước tiếp theo
    await AppLogger.initialize();

    AppLogger.info('Initializing King\'s Gambit AI...');

    setupDependencies();

    // Initialize audio service (non-critical)
    try {
      final audioService = getIt<AudioService>();
      await audioService.preloadSounds();
      AppLogger.info('Audio service initialized');
    } catch (e, stackTrace) {
      AppLogger.error('Audio service initialization failed (non-critical)', e, stackTrace);
      // Continue without audio
    }

    // Initialize cache service (non-critical)
    try {
      final cacheService = getIt<CacheService>();
      await cacheService.preloadAssets();
      AppLogger.info('Cache service initialized');
    } catch (e, stackTrace) {
      AppLogger.error('Cache service initialization failed (non-critical)', e, stackTrace);
      // Continue without cache
    }

    AppLogger.info('King\'s Gambit AI initialization complete');
  } catch (e, stackTrace) {
    AppLogger.error('Critical initialization error', e, stackTrace);
    // Don't rethrow - let app start even with errors
  }
}
