import 'package:get_it/get_it.dart';

import '../../data/datasources/engine/chess_engine_datasource.dart';
import '../../data/datasources/local/game_local_datasource.dart';
import '../../data/datasources/local/preferences_datasource.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../domain/repositories/i_game_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_stats_repository.dart';
import '../../domain/usecases/evaluate_position.dart';
import '../../domain/usecases/export_pgn.dart';
import '../../domain/usecases/get_ai_move.dart';
import '../../domain/usecases/get_legal_moves.dart';
import '../../domain/usecases/load_game.dart';
import '../../domain/usecases/make_move.dart';
import '../../domain/usecases/new_game.dart';
import '../../domain/usecases/redo_move.dart';
import '../../domain/usecases/save_game.dart';
import '../../domain/usecases/undo_move.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/chess_ai_engine.dart';
import '../../services/ai/maia_onnx_engine.dart';
import '../../services/audio/audio_service.dart';
import '../../services/engine/chess_engine_service.dart';
import '../../services/game/chess_rules_service.dart';
import '../../services/navigation/navigation_service.dart';
import '../../services/storage/cache_service.dart';
import '../../services/storage/storage_service.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  _setupServices();
  _setupDataSources();
  _setupRepositories();
  _setupUseCases();
}

void _setupServices() {
  getIt.registerSingleton<ChessRulesService>(ChessRulesService());
  getIt.registerSingleton<ChessEngineService>(ChessEngineService());
  getIt.registerSingleton<AIService>(AIService(getIt<ChessEngineService>()));
  // MaiaOnnxEngine extends ChessAIEngine: plays via Maia neural nets run
  // directly through ONNX Runtime, and transparently falls back to the
  // original minimax engine if a model fails to load or run.
  getIt.registerSingleton<ChessAIEngine>(MaiaOnnxEngine(getIt<ChessRulesService>()));
  // AudioService registered lazily after repositories to access ISettingsRepository
  getIt.registerLazySingleton<AudioService>(
    () => AudioService(settingsRepository: getIt<ISettingsRepository>()),
  );
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<CacheService>(CacheService());
  getIt.registerSingleton<NavigationService>(NavigationService());
}

void _setupDataSources() {
  getIt.registerLazySingleton<ChessEngineDataSource>(
    () => ChessEngineDataSource(getIt<ChessEngineService>()),
  );
  getIt.registerLazySingleton<GameLocalDataSource>(
    () => GameLocalDataSource(getIt<StorageService>()),
  );
  getIt.registerLazySingleton<PreferencesDataSource>(
    () => PreferencesDataSource(),
  );
}

void _setupRepositories() {
  getIt.registerLazySingleton<IGameRepository>(
    () => GameRepository(
      engineDataSource: getIt<ChessEngineDataSource>(),
      localDataSource: getIt<GameLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<ISettingsRepository>(
    () => SettingsRepository(
      preferencesDataSource: getIt<PreferencesDataSource>(),
    ),
  );
  getIt.registerLazySingleton<IStatsRepository>(
    () => StatsRepository(
      preferencesDataSource: getIt<PreferencesDataSource>(),
    ),
  );
}

void _setupUseCases() {
  getIt.registerFactory(() => NewGameUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => MakeMoveUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => UndoMoveUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => RedoMoveUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => GetLegalMovesUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => GetAIMoveUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => EvaluatePositionUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => SaveGameUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => LoadGameUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => ExportPGNUseCase(getIt<IGameRepository>()));
}
