import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/game_state.dart';

abstract class IGameRepository {
  Future<Either<Failure, void>> saveGameState(GameState gameState);
  Future<Either<Failure, GameState>> loadGame(String gameId);
}
