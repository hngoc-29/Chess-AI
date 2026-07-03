import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../datasources/local/preferences_datasource.dart';

class SettingsRepository implements ISettingsRepository {
  final PreferencesDataSource _preferencesDataSource;

  SettingsRepository({required PreferencesDataSource preferencesDataSource})
      : _preferencesDataSource = preferencesDataSource;

  @override
  Future<Either<Failure, bool>> getSoundEnabled() async {
    try {
      final result = await _preferencesDataSource.getSoundEnabled();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setSoundEnabled(bool enabled) async {
    try {
      await _preferencesDataSource.setSoundEnabled(enabled);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> getMusicEnabled() async {
    try {
      final result = await _preferencesDataSource.getMusicEnabled();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setMusicEnabled(bool enabled) async {
    try {
      await _preferencesDataSource.setMusicEnabled(enabled);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getVolume() async {
    try {
      final result = await _preferencesDataSource.getVolume();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setVolume(double volume) async {
    try {
      await _preferencesDataSource.setVolume(volume);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getBoardTheme() async {
    try {
      final result = await _preferencesDataSource.getBoardTheme();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setBoardTheme(String theme) async {
    try {
      await _preferencesDataSource.setBoardTheme(theme);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getPieceSet() async {
    try {
      final result = await _preferencesDataSource.getPieceSet();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setPieceSet(String pieceSet) async {
    try {
      await _preferencesDataSource.setPieceSet(pieceSet);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isDarkMode() async {
    try {
      final result = await _preferencesDataSource.isDarkMode();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setDarkMode(bool isDark) async {
    try {
      await _preferencesDataSource.setDarkMode(isDark);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getAIDifficulty() async {
    try {
      final result = await _preferencesDataSource.getAIDifficulty();
      return Right(result);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setAIDifficulty(int difficulty) async {
    try {
      await _preferencesDataSource.setAIDifficulty(difficulty);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
