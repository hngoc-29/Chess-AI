import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../repositories/i_game_repository.dart';

class EvaluatePositionUseCase {
  final IGameRepository repository;

  EvaluatePositionUseCase(this.repository);

  Future<Either<Failure, double>> call(int gameId) async {
    return await repository.evaluatePosition(gameId);
  }
}
