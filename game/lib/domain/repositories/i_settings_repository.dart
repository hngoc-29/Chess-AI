import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';

abstract class ISettingsRepository {
  Future<Either<Failure, bool>> getSoundEnabled();
  Future<Either<Failure, void>> setSoundEnabled(bool enabled);
  Future<Either<Failure, double>> getVolume();
  Future<Either<Failure, void>> setVolume(double volume);
  Future<Either<Failure, String>> getBoardTheme();
  Future<Either<Failure, void>> setBoardTheme(String theme);
  Future<Either<Failure, String>> getPieceSet();
  Future<Either<Failure, void>> setPieceSet(String pieceSet);
  Future<Either<Failure, bool>> isDarkMode();
  Future<Either<Failure, void>> setDarkMode(bool isDark);
  Future<Either<Failure, int>> getAIDifficulty();
  Future<Either<Failure, void>> setAIDifficulty(int difficulty);
}
