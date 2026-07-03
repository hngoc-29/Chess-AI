import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/i_stats_repository.dart';
import '../datasources/local/preferences_datasource.dart';

class StatsRepository implements IStatsRepository {
  final PreferencesDataSource _preferencesDataSource;

  StatsRepository({required PreferencesDataSource preferencesDataSource})
      : _preferencesDataSource = preferencesDataSource;

  @override
  Future<Either<Failure, GameStats>> getStats() async {
    try {
      final totalGames = await _preferencesDataSource.getTotalGames();
      final wins = await _preferencesDataSource.getWins();
      final losses = await _preferencesDataSource.getLosses();
      final draws = await _preferencesDataSource.getDraws();

      return Right(GameStats(
        totalGames: totalGames,
        wins: wins,
        losses: losses,
        draws: draws,
      ));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> recordGame({
    required bool isWin,
    required bool isDraw,
  }) async {
    try {
      await _preferencesDataSource.incrementTotalGames();
      
      if (isDraw) {
        await _preferencesDataSource.incrementDraws();
      } else if (isWin) {
        await _preferencesDataSource.incrementWins();
      } else {
        await _preferencesDataSource.incrementLosses();
      }
      
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetStats() async {
    try {
      await _preferencesDataSource.resetStats();
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
