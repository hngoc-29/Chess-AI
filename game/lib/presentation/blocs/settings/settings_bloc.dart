import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/settings.dart';
import '../../../domain/repositories/i_settings_repository.dart';
import '../../../services/audio/audio_service.dart';
import '../../../core/config/injection.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final ISettingsRepository _repository;

  SettingsBloc({
    required ISettingsRepository repository,
  })  : _repository = repository,
        super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateSoundEnabled>(_onUpdateSoundEnabled);
    on<UpdateMusicEnabled>(_onUpdateMusicEnabled);
    on<UpdateTheme>(_onUpdateTheme);
    on<UpdateBoardStyle>(_onUpdateBoardStyle);
    on<UpdatePieceStyle>(_onUpdatePieceStyle);
    on<UpdateAnimationSpeed>(_onUpdateAnimationSpeed);
    on<UpdateAIDifficulty>(_onUpdateAIDifficulty);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      // Load all settings from repository
      final soundResult = await _repository.getSoundEnabled();
      final musicResult = await _repository.getMusicEnabled();
      final boardThemeResult = await _repository.getBoardTheme();
      final pieceSetResult = await _repository.getPieceSet();
      final darkModeResult = await _repository.isDarkMode();
      final difficultyResult = await _repository.getAIDifficulty();

      // Handle any failures
      if (soundResult.isLeft() ||
          musicResult.isLeft() ||
          boardThemeResult.isLeft() ||
          pieceSetResult.isLeft() ||
          darkModeResult.isLeft() ||
          difficultyResult.isLeft()) {
        emit(const SettingsError('Failed to load settings'));
        return;
      }

      // Extract values
      final soundEnabled = soundResult.getOrElse(() => true);
      final musicEnabled = musicResult.getOrElse(() => true);
      final boardTheme = boardThemeResult.getOrElse(() => 'classic');
      final pieceSet = pieceSetResult.getOrElse(() => 'cburnett');
      final isDark = darkModeResult.getOrElse(() => false);
      final difficulty = difficultyResult.getOrElse(() => 2);

      // Parse enums
      final boardStyle = BoardStyle.values.firstWhere(
        (e) => e.name == boardTheme,
        orElse: () => BoardStyle.classic,
      );
      final pieceStyle = PieceStyle.values.firstWhere(
        (e) => e.name == pieceSet,
        orElse: () => PieceStyle.cburnett,
      );
      final aiDifficulty = AIDifficulty.values[difficulty.clamp(0, AIDifficulty.values.length - 1)];

      final settings = Settings(
        soundEnabled: soundEnabled,
        musicEnabled: musicEnabled,
        theme: isDark ? AppThemeMode.dark : AppThemeMode.light,
        boardStyle: boardStyle,
        pieceStyle: pieceStyle,
        animationSpeed: AnimationSpeed.normal, // Not in current repo
        aiDifficulty: aiDifficulty,
      );

      emit(SettingsLoaded(settings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateSoundEnabled(
    UpdateSoundEnabled event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    final result = await _repository.setSoundEnabled(event.enabled);

    result.fold(
      (failure) => emit(SettingsError(failure.toString())),
      (_) {
        // Update audio service
        getIt<AudioService>().setSoundEnabled(event.enabled);
        
        final updatedSettings = currentSettings.copyWith(
          soundEnabled: event.enabled,
        );
        emit(SettingsLoaded(updatedSettings));
      },
    );
  }

  Future<void> _onUpdateMusicEnabled(
    UpdateMusicEnabled event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    final result = await _repository.setMusicEnabled(event.enabled);

    result.fold(
      (failure) => emit(SettingsError(failure.toString())),
      (_) {
        // Update audio service
        getIt<AudioService>().setMusicEnabled(event.enabled);
        
        final updatedSettings = currentSettings.copyWith(
          musicEnabled: event.enabled,
        );
        emit(SettingsLoaded(updatedSettings));
      },
    );
  }

  Future<void> _onUpdateTheme(
    UpdateTheme event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    final isDark = event.theme == AppThemeMode.dark;
    final result = await _repository.setDarkMode(isDark);

    result.fold(
      (failure) => emit(SettingsError(failure.toString())),
      (_) {
        final updatedSettings = currentSettings.copyWith(theme: event.theme);
        emit(SettingsLoaded(updatedSettings));
      },
    );
  }

  Future<void> _onUpdateBoardStyle(
    UpdateBoardStyle event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    final result = await _repository.setBoardTheme(event.style.name);

    result.fold(
      (failure) => emit(SettingsError(failure.toString())),
      (_) {
        final updatedSettings = currentSettings.copyWith(
          boardStyle: event.style,
        );
        emit(SettingsLoaded(updatedSettings));
      },
    );
  }

  Future<void> _onUpdatePieceStyle(
    UpdatePieceStyle event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    final result = await _repository.setPieceSet(event.style.name);

    result.fold(
      (failure) => emit(SettingsError(failure.toString())),
      (_) {
        final updatedSettings = currentSettings.copyWith(
          pieceStyle: event.style,
        );
        emit(SettingsLoaded(updatedSettings));
      },
    );
  }

  Future<void> _onUpdateAnimationSpeed(
    UpdateAnimationSpeed event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    // Animation speed not in current repo, just update local state
    final updatedSettings = currentSettings.copyWith(
      animationSpeed: event.speed,
    );
    emit(SettingsLoaded(updatedSettings));
  }

  Future<void> _onUpdateAIDifficulty(
    UpdateAIDifficulty event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final currentSettings = (state as SettingsLoaded).settings;

    final difficultyIndex = event.difficulty.index;
    final result = await _repository.setAIDifficulty(difficultyIndex);

    result.fold(
      (failure) => emit(SettingsError(failure.toString())),
      (_) {
        final updatedSettings = currentSettings.copyWith(
          aiDifficulty: event.difficulty,
        );
        emit(SettingsLoaded(updatedSettings));
      },
    );
  }
}
