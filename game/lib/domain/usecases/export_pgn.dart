import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../repositories/i_game_repository.dart';

class ExportPGNUseCase {
  final IGameRepository repository;

  ExportPGNUseCase(this.repository);

  Future<Either<Failure, String>> call(int gameId) async {
    return await repository.exportPGN(gameId);
  }
}
