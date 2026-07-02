import 'package:equatable/equatable.dart';

import '../../../domain/entities/settings.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class UpdateSoundEnabled extends SettingsEvent {
  final bool enabled;

  const UpdateSoundEnabled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class UpdateMusicEnabled extends SettingsEvent {
  final bool enabled;

  const UpdateMusicEnabled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class UpdateTheme extends SettingsEvent {
  final ThemeMode theme;

  const UpdateTheme(this.theme);

  @override
  List<Object?> get props => [theme];
}

class UpdateBoardStyle extends SettingsEvent {
  final BoardStyle style;

  const UpdateBoardStyle(this.style);

  @override
  List<Object?> get props => [style];
}

class UpdatePieceStyle extends SettingsEvent {
  final PieceStyle style;

  const UpdatePieceStyle(this.style);

  @override
  List<Object?> get props => [style];
}

class UpdateAnimationSpeed extends SettingsEvent {
  final AnimationSpeed speed;

  const UpdateAnimationSpeed(this.speed);

  @override
  List<Object?> get props => [speed];
}

class UpdateAIDifficulty extends SettingsEvent {
  final AIDifficulty difficulty;

  const UpdateAIDifficulty(this.difficulty);

  @override
  List<Object?> get props => [difficulty];
}
