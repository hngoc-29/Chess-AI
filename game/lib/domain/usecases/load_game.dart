import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';
import '../repositories/i_game_repository.dart';

class LoadGameUseCase {
  final IGameRepository repository;

  LoadGameUseCase(this.repository);

  Future<Either<Failure, GameState>> call(String gameId) async {
    return await repository.loadGame(gameId);
  }
}
