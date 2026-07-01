import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chess_move.dart';
import '../repositories/i_game_repository.dart';

class GetAIMoveUseCase {
  final IGameRepository repository;

  GetAIMoveUseCase(this.repository);

  Future<Either<Failure, ChessMove>> call({
    required int gameId,
    int difficulty = 5,
    Duration? maxTime,
  }) async {
    return await repository.getAIMove(
      gameId,
      difficulty: difficulty,
      maxTime: maxTime,
    );
  }
}
