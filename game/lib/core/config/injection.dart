import 'package:get_it/get_it.dart';

import '../../data/datasources/local/game_local_datasource.dart';
import '../../data/datasources/local/preferences_datasource.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../domain/repositories/i_game_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_stats_repository.dart';
import '../../domain/usecases/load_game.dart';
import '../../domain/usecases/save_game.dart';
import '../../services/ai/chess_ai_engine.dart';
import '../../services/ai/maia_onnx_engine.dart';
import '../../services/audio/audio_service.dart';
import '../../services/game/chess_rules_service.dart';
import '../../services/storage/cache_service.dart';
import '../../services/storage/storage_service.dart';
import '../../services/online/backend_auth_service.dart';
import '../../services/online/socket_io_service.dart';
import '../../services/online/api_client_service.dart';
import '../../services/online/offline_sync_service.dart';
import '../../presentation/blocs/online/auth_bloc.dart';
import '../../presentation/blocs/online/matchmaking_bloc.dart';
import '../../presentation/blocs/online/online_game_bloc.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  _setupServices();
  _setupDataSources();
  _setupRepositories();
  _setupUseCases();
  _setupBlocs();
}

void _setupServices() {
  getIt.registerSingleton<ChessRulesService>(ChessRulesService());
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
  
  // Online services
  getIt.registerSingleton<BackendAuthService>(BackendAuthService());
  getIt.registerSingleton<SocketIOService>(SocketIOService());
  getIt.registerSingleton<ApiClientService>(ApiClientService());
  getIt.registerSingleton<OfflineSyncService>(OfflineSyncService(getIt<ApiClientService>()));
}

void _setupDataSources() {
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
  getIt.registerFactory(() => SaveGameUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => LoadGameUseCase(getIt<IGameRepository>()));
}

void _setupBlocs() {
  getIt.registerFactory(
    () => AuthBloc(
      authService: getIt<BackendAuthService>(),
      socketService: getIt<SocketIOService>(),
      apiService: getIt<ApiClientService>(),
      syncService: getIt<OfflineSyncService>(),
    ),
  );
  getIt.registerFactory(
    () => MatchmakingBloc(socketService: getIt<SocketIOService>()),
  );
  getIt.registerFactory(
    () => OnlineGameBloc(socketService: getIt<SocketIOService>()),
  );
}
