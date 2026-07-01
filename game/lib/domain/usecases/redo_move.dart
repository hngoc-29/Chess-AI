import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';
import '../repositories/i_game_repository.dart';

class RedoMoveUseCase {
  final IGameRepository repository;

  RedoMoveUseCase(this.repository);

  Future<Either<Failure, GameState>> call(int gameId) async {
    return await repository.redo(gameId);
  }
}
