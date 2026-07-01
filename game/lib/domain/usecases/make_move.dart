import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';
import '../entities/position.dart';
import '../repositories/i_game_repository.dart';

class MakeMoveUseCase {
  final IGameRepository repository;

  MakeMoveUseCase(this.repository);

  Future<Either<Failure, GameState>> call({
    required int gameId,
    required Position from,
    required Position to,
  }) async {
    return await repository.makeMove(gameId, from, to);
  }
}
