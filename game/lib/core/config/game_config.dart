class GameConfig {
  GameConfig._();

  static const int defaultAIDifficulty = 5;
  static const int minAIDifficulty = 1;
  static const int maxAIDifficulty = 10;

  static const int maxUndoHistory = 50;

  static const double minBoardSize = 320.0;
  static const double maxBoardSize = 800.0;

  static const String defaultBoardTheme = 'brown';
  static const String defaultPieceSet = 'cburnett';

  static const List<String> availableBoardThemes = [
    'brown',
    'blue',
    'green',
    'purple',
    'wood',
    'dark',
  ];

  static const List<String> availablePieceSets = [
    'cburnett',
    'merida',
    'alpha',
    'pixel',
  ];

  static const bool showCoordinates = true;
  static const bool highlightLegalMoves = true;
  static const bool highlightLastMove = true;
  static const bool showCapturedPieces = true;
  static const bool showEvaluationBar = true;
  static const bool showMoveHistory = true;
}
