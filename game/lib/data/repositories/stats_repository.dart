import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/i_stats_repository.dart';
import '../datasources/local/game_local_datasource.dart';

class StatsRepository implements IStatsRepository {
  final GameLocalDataSource _localDataSource;

  StatsRepository({required GameLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, GameStats>> getStats() async {
    try {
      return Right(GameStats(
        totalGames: 0,
        wins: 0,
        losses: 0,
        draws: 0,
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
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
