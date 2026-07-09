import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';
import '../repositories/i_game_repository.dart';

class SaveGameUseCase {
  final IGameRepository repository;

  SaveGameUseCase(this.repository);

  Future<Either<Failure, void>> call(GameState gameState) async {
    return await repository.saveGameState(gameState);
  }

  Future<Either<Failure, void>> saveState(GameState gameState) async {
    return await repository.saveGameState(gameState);
  }
}
