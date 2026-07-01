import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../repositories/i_game_repository.dart';

class SaveGameUseCase {
  final IGameRepository repository;

  SaveGameUseCase(this.repository);

  Future<Either<Failure, void>> call(int gameId) async {
    return await repository.saveGame(gameId);
  }
}
