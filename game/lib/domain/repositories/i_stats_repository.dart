import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';

class GameStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;

  const GameStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
  });
}

abstract class IStatsRepository {
  Future<Either<Failure, GameStats>> getStats();
  Future<Either<Failure, void>> recordGame({required bool isWin, required bool isDraw});
  Future<Either<Failure, void>> resetStats();
}
