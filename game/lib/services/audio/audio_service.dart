import 'package:audioplayers/audioplayers.dart';

import '../../core/utils/logger.dart';
import '../../domain/repositories/i_settings_repository.dart';

enum SoundEffect {
  move,
  capture,
  check,
  checkmate,
  castle,
  button,
}

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final ISettingsRepository? _settingsRepository;
  final Map<SoundEffect, String> _soundPaths = {
    SoundEffect.move: 'assets/sounds/Move.mp3',
    SoundEffect.capture: 'assets/sounds/Capture.mp3',
    SoundEffect.check: 'assets/sounds/Check.mp3',
    SoundEffect.checkmate: 'assets/sounds/Checkmate.mp3',
    SoundEffect.castle: 'assets/sounds/Move.mp3',
    SoundEffect.button: 'assets/sounds/Select.mp3',
  };

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _volume = 1.0;

  AudioService({ISettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository {
    _initMusic();
  }

  Future<void> _initMusic() async {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    if (_settingsRepository != null) {
      final result = await _settingsRepository!.getMusicEnabled();
      _musicEnabled = result.getOrElse(() => true);
    }
    if (_musicEnabled) {
      playMusic();
    }
  }

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  double get volume => _volume;

  Future<void> preloadSounds() async {
    try {
      AppLogger.info('Preloading sound effects...');
      AppLogger.info('Sound effects preloaded');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to preload sounds', e, stackTrace);
    }
  }

  Future<void> playSound(SoundEffect effect) async {
    // Check current settings from repository if available
    bool soundEnabled = _soundEnabled;
    if (_settingsRepository != null) {
      final result = await _settingsRepository.getSoundEnabled();
      soundEnabled = result.getOrElse(() => _soundEnabled);
    }
    
    if (!soundEnabled) return;

    try {
      final path = _soundPaths[effect];
      if (path != null) {
        await _player.play(AssetSource(path.replaceFirst('assets/', '')));
      }
    } catch (e) {
      AppLogger.warning('Failed to play sound: $effect', e);
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    if (enabled) {
      playMusic();
    } else {
      stopMusic();
    }
  }

  Future<void> playMusic() async {
    try {
      await _musicPlayer.play(AssetSource('sounds/background_music.mp3'));
    } catch (e) {
      AppLogger.warning('Failed to play background music', e);
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    await _musicPlayer.setVolume(_volume * 0.5); // Background music slightly quieter
  }

  void dispose() {
    _player.dispose();
    _musicPlayer.dispose();
  }
}
