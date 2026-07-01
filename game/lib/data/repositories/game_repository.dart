import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/chess_move.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/piece.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/position.dart';
import '../../domain/repositories/i_game_repository.dart';
import '../datasources/engine/chess_engine_datasource.dart';
import '../datasources/local/game_local_datasource.dart';

class GameRepository implements IGameRepository {
  final ChessEngineDataSource _engineDataSource;
  final GameLocalDataSource _localDataSource;

  GameRepository({
    required ChessEngineDataSource engineDataSource,
    required GameLocalDataSource localDataSource,
  })  : _engineDataSource = engineDataSource,
        _localDataSource = localDataSource;

  @override
  Future<Either<Failure, GameState>> newGame() async {
    try {
      final gameId = await _engineDataSource.createNewGame();

      final whitePlayer = Player(
        id: 'white',
        name: 'Player',
        color: PieceColor.white,
        type: PlayerType.human,
      );

      final blackPlayer = Player(
        id: 'black',
        name: 'AI',
        color: PieceColor.black,
        type: PlayerType.ai,
      );

      final gameState = GameState.initial(
        gameId: gameId,
        whitePlayer: whitePlayer,
        blackPlayer: blackPlayer,
      );

      return Right(gameState);
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GameState>> makeMove(
    int gameId,
    Position from,
    Position to,
  ) async {
    try {
      await _engineDataSource.makeMove(
        gameId,
        from.toAlgebraic(),
        to.toAlgebraic(),
      );

      return newGame();
    } on InvalidMoveException catch (e) {
      return Left(InvalidMoveFailure(e.message));
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GameState>> undo(int gameId) async {
    try {
      await _engineDataSource.undo(gameId);
      return newGame();
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GameState>> redo(int gameId) async {
    try {
      await _engineDataSource.redo(gameId);
      return newGame();
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Position>>> getLegalMoves(
    int gameId,
    Position position,
  ) async {
    try {
      final moves = await _engineDataSource.getLegalMoves(
        gameId,
        position.toAlgebraic(),
      );
      return Right(moves.map((m) => Position.fromAlgebraic(m)).toList());
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChessMove>> getAIMove(
    int gameId, {
    int difficulty = 5,
    Duration? maxTime,
  }) async {
    try {
      return Right(ChessMove(
        from: Position.fromAlgebraic('e7'),
        to: Position.fromAlgebraic('e5'),
      ));
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> evaluatePosition(int gameId) async {
    try {
      return const Right(0.0);
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveGame(int gameId) async {
    try {
      await _localDataSource.saveGame(gameId.toString(), {});
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
      return newGame();
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> exportPGN(int gameId) async {
    try {
      return const Right('');
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    } catch (e) {
      return Left(EngineFailure(e.toString()));
    }
  }
}
