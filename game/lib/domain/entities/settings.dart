import 'package:equatable/equatable.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

enum BoardStyle {
  classic,
  modern,
  wooden,
  marble,
}

enum PieceStyle {
  cburnett,
  merida,
  alpha,
  pixel,
}

enum AnimationSpeed {
  none,
  fast,
  normal,
  slow,
}

/// AI difficulty tiers. Each maps to a specific Maia (lc0) network trained
/// on human games at that approximate Elo rating - see
/// MaiaOnnxEngine in services/ai/maia_onnx_engine.dart for the mapping.
enum AIDifficulty {
  beginner, // Maia ~1100 Elo
  easy, // Maia ~1300 Elo
  medium, // Maia ~1500 Elo
  hard, // Maia ~1700 Elo
  veryHard, // Maia ~1900 Elo
  expert, // Maia ~1900 Elo net, searched much deeper (less human, stronger)
}

class Settings extends Equatable {
  final bool soundEnabled;
  final bool musicEnabled;
  final AppThemeMode theme;
  final BoardStyle boardStyle;
  final PieceStyle pieceStyle;
  final AnimationSpeed animationSpeed;
  final AIDifficulty aiDifficulty;

  const Settings({
    required this.soundEnabled,
    required this.musicEnabled,
    required this.theme,
    required this.boardStyle,
    required this.pieceStyle,
    required this.animationSpeed,
    required this.aiDifficulty,
  });

  factory Settings.defaults() {
    return const Settings(
      soundEnabled: true,
      musicEnabled: false,
      theme: AppThemeMode.system,
      boardStyle: BoardStyle.classic,
      pieceStyle: PieceStyle.cburnett,
      animationSpeed: AnimationSpeed.normal,
      aiDifficulty: AIDifficulty.medium,
    );
  }

  Settings copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    AppThemeMode? theme,
    BoardStyle? boardStyle,
    PieceStyle? pieceStyle,
    AnimationSpeed? animationSpeed,
    AIDifficulty? aiDifficulty,
  }) {
    return Settings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      theme: theme ?? this.theme,
      boardStyle: boardStyle ?? this.boardStyle,
      pieceStyle: pieceStyle ?? this.pieceStyle,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soundEnabled': soundEnabled,
      'musicEnabled': musicEnabled,
      'theme': theme.name,
      'boardStyle': boardStyle.name,
      'pieceStyle': pieceStyle.name,
      'animationSpeed': animationSpeed.name,
      'aiDifficulty': aiDifficulty.name,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      musicEnabled: json['musicEnabled'] as bool? ?? false,
      theme: AppThemeMode.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => AppThemeMode.system,
      ),
      boardStyle: BoardStyle.values.firstWhere(
        (e) => e.name == json['boardStyle'],
        orElse: () => BoardStyle.classic,
      ),
      pieceStyle: PieceStyle.values.firstWhere(
        (e) => e.name == json['pieceStyle'],
        orElse: () => PieceStyle.cburnett,
      ),
      animationSpeed: AnimationSpeed.values.firstWhere(
        (e) => e.name == json['animationSpeed'],
        orElse: () => AnimationSpeed.normal,
      ),
      aiDifficulty: AIDifficulty.values.firstWhere(
        (e) => e.name == json['aiDifficulty'],
        orElse: () => AIDifficulty.medium,
      ),
    );
  }

  @override
  List<Object?> get props => [
        soundEnabled,
        musicEnabled,
        theme,
        boardStyle,
        pieceStyle,
        animationSpeed,
        aiDifficulty,
      ];
}
