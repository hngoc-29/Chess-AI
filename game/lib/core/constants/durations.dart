class AppDurations {
  AppDurations._();

  static const Duration splash = Duration(seconds: 2);

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  static const Duration pieceMoveAnimation = Duration(milliseconds: 300);
  static const Duration pieceCapture = Duration(milliseconds: 200);
  static const Duration highlightFade = Duration(milliseconds: 200);

  static const Duration snackbarShort = Duration(seconds: 2);
  static const Duration snackbarMedium = Duration(seconds: 4);
  static const Duration snackbarLong = Duration(seconds: 6);

  static const Duration debounceShort = Duration(milliseconds: 300);
  static const Duration debounceMedium = Duration(milliseconds: 500);

  static const Duration aiThinkingMin = Duration(seconds: 1);
  static const Duration aiThinkingDefault = Duration(seconds: 10);
  static const Duration aiThinkingMax = Duration(seconds: 30);
}
