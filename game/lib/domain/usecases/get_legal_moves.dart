import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/position.dart';
import '../repositories/i_game_repository.dart';

class GetLegalMovesUseCase {
  final IGameRepository repository;

  GetLegalMovesUseCase(this.repository);

  Future<Either<Failure, List<Position>>> call({
    required int gameId,
    required Position position,
  }) async {
    return await repository.getLegalMoves(gameId, position);
  }
}
