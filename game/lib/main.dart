import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'core/config/injection.dart';
import 'core/utils/logger.dart';
import 'presentation/app/app.dart';
import 'services/audio/audio_service.dart';
import 'services/engine/chess_engine_service.dart';
import 'services/storage/cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await _initializeApp();

  runApp(const ChessAIApp());
}

Future<void> _initializeApp() async {
  try {
    AppLogger.info('Initializing Chess AI...');

    setupDependencies();

    final engineService = getIt<ChessEngineService>();
    await engineService.initialize('models/best_model_traced.pt');
    AppLogger.info('Chess engine initialized');

    final audioService = getIt<AudioService>();
    await audioService.preloadSounds();
    AppLogger.info('Audio service initialized');

    final cacheService = getIt<CacheService>();
    await cacheService.preloadAssets();
    AppLogger.info('Cache service initialized');

    AppLogger.info('Chess AI initialization complete');
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize app', e, stackTrace);
    rethrow;
  }
}
