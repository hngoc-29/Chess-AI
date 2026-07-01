import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';
import '../repositories/i_game_repository.dart';

class NewGameUseCase {
  final IGameRepository repository;

  NewGameUseCase(this.repository);

  Future<Either<Failure, GameState>> call() async {
    return await repository.newGame();
  }
}
