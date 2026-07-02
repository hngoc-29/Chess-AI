import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/strings.dart';
import '../../../domain/entities/settings.dart';
import '../../../domain/repositories/i_settings_repository.dart';
import '../../app/routes.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/settings/settings_event.dart';
import '../../blocs/settings/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsBloc(
        repository: getIt<ISettingsRepository>(),
      )..add(const LoadSettings()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SettingsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SettingsBloc>().add(const LoadSettings());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SettingsLoaded) {
            final settings = state.settings;
            return ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.volume_up),
                  title: const Text(AppStrings.soundEffects),
                  trailing: Switch(
                    value: settings.soundEnabled,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(UpdateSoundEnabled(value));
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text(AppStrings.music),
                  trailing: Switch(
                    value: settings.musicEnabled,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(UpdateMusicEnabled(value));
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text(AppStrings.theme),
                  subtitle: Text(_getThemeLabel(settings.theme)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemePicker(context, settings.theme),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: const Text(AppStrings.boardStyle),
                  subtitle: Text(_getBoardStyleLabel(settings.boardStyle)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showBoardStylePicker(context, settings.boardStyle),
                ),
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text(AppStrings.pieceStyle),
                  subtitle: Text(_getPieceStyleLabel(settings.pieceStyle)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPieceStylePicker(context, settings.pieceStyle),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text(AppStrings.animationSpeed),
                  subtitle: Text(_getAnimationSpeedLabel(settings.animationSpeed)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAnimationSpeedPicker(context, settings.animationSpeed),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: const Text(AppStrings.aiDifficulty),
                  subtitle: Text(_getAIDifficultyLabel(settings.aiDifficulty)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAIDifficultyPicker(context, settings.aiDifficulty),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Debug Logs'),
                  subtitle: const Text('Xem và export logs để debug'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.debugLogs);
                  },
                ),
              ],
            );
          }

          return const Center(child: Text('Unknown state'));
        },
      ),
    );
  }

  String _getThemeLabel(ThemeMode theme) {
    switch (theme) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _getBoardStyleLabel(BoardStyle style) {
    switch (style) {
      case BoardStyle.classic:
        return 'Classic';
      case BoardStyle.modern:
        return 'Modern';
      case BoardStyle.wooden:
        return 'Wooden';
      case BoardStyle.marble:
        return 'Marble';
    }
  }

  String _getPieceStyleLabel(PieceStyle style) {
    switch (style) {
      case PieceStyle.cburnett:
        return 'CBurnett';
      case PieceStyle.merida:
        return 'Merida';
      case PieceStyle.alpha:
        return 'Alpha';
      case PieceStyle.pixel:
        return 'Pixel';
    }
  }

  String _getAnimationSpeedLabel(AnimationSpeed speed) {
    switch (speed) {
      case AnimationSpeed.none:
        return 'None';
      case AnimationSpeed.fast:
        return 'Fast';
      case AnimationSpeed.normal:
        return 'Normal';
      case AnimationSpeed.slow:
        return 'Slow';
    }
  }

  String _getAIDifficultyLabel(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.easy:
        return 'Easy';
      case AIDifficulty.medium:
        return 'Medium';
      case AIDifficulty.hard:
        return 'Hard';
      case AIDifficulty.expert:
        return 'Expert';
    }
  }

  void _showThemePicker(BuildContext context, ThemeMode current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((theme) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeLabel(theme)),
              value: theme,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(UpdateTheme(value));
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBoardStylePicker(BuildContext context, BoardStyle current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Board Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BoardStyle.values.map((style) {
            return RadioListTile<BoardStyle>(
              title: Text(_getBoardStyleLabel(style)),
              value: style,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(UpdateBoardStyle(value));
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPieceStylePicker(BuildContext context, PieceStyle current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Piece Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PieceStyle.values.map((style) {
            return RadioListTile<PieceStyle>(
              title: Text(_getPieceStyleLabel(style)),
              value: style,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(UpdatePieceStyle(value));
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAnimationSpeedPicker(BuildContext context, AnimationSpeed current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Animation Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AnimationSpeed.values.map((speed) {
            return RadioListTile<AnimationSpeed>(
              title: Text(_getAnimationSpeedLabel(speed)),
              value: speed,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(UpdateAnimationSpeed(value));
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAIDifficultyPicker(BuildContext context, AIDifficulty current) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select AI Difficulty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AIDifficulty.values.map((difficulty) {
            return RadioListTile<AIDifficulty>(
              title: Text(_getAIDifficultyLabel(difficulty)),
              value: difficulty,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(UpdateAIDifficulty(value));
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
