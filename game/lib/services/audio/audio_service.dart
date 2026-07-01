import 'package:audioplayers/audioplayers.dart';

import '../../core/utils/logger.dart';

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
  final Map<SoundEffect, String> _soundPaths = {
    SoundEffect.move: 'assets/sounds/Move.mp3',
    SoundEffect.capture: 'assets/sounds/Capture.mp3',
    SoundEffect.check: 'assets/sounds/Check.mp3',
    SoundEffect.checkmate: 'assets/sounds/Checkmate.mp3',
    SoundEffect.castle: 'assets/sounds/Move.mp3',
    SoundEffect.button: 'assets/sounds/Select.mp3',
  };

  bool _soundEnabled = true;
  double _volume = 1.0;

  bool get soundEnabled => _soundEnabled;
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
    if (!_soundEnabled) return;

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

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  void dispose() {
    _player.dispose();
  }
}
