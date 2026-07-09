import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/player.dart';
import '../../domain/repositories/i_game_repository.dart';
import '../datasources/local/game_local_datasource.dart';

/// Handles persisting/restoring GameState to local storage. This is the
/// only part of the original repository design that's actually live -
/// move generation, AI moves, and PGN export all happen directly through
/// ChessRulesService/ChessAIEngine in GameBloc instead.
class GameRepository implements IGameRepository {
  final GameLocalDataSource _localDataSource;

  GameRepository({required GameLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, void>> saveGameState(GameState gameState) async {
    try {
      final json = gameState.toJson();
      await _localDataSource.saveGame(gameState.gameId.toString(), json);
      // Save a quick-recovery session key depending on whether this game is vs AI or local
      final hasAI = gameState.whitePlayer.type == PlayerType.ai || gameState.blackPlayer.type == PlayerType.ai;
      final sessionKey = hasAI ? 'current_session_ai' : 'current_session_local';
      await _localDataSource.saveGame(sessionKey, json);
      return const Right(null);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GameState>> loadGame(String gameId) async {
    try {
      final json = await _localDataSource.loadGame(gameId);
      if (json == null || json.isEmpty) {
        return Left(StorageFailure('Game not found'));
      }
      final gameState = GameState.fromJson(json);
      return Right(gameState);
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
