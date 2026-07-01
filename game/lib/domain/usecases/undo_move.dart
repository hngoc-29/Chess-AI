import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';
import '../repositories/i_game_repository.dart';

class UndoMoveUseCase {
  final IGameRepository repository;

  UndoMoveUseCase(this.repository);

  Future<Either<Failure, GameState>> call(int gameId) async {
    return await repository.undo(gameId);
  }
}
