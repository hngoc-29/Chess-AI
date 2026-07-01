import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chess_move.dart';
import '../entities/game_state.dart';
import '../entities/position.dart';

abstract class IGameRepository {
  Future<Either<Failure, GameState>> newGame();
  Future<Either<Failure, GameState>> makeMove(int gameId, Position from, Position to);
  Future<Either<Failure, GameState>> undo(int gameId);
  Future<Either<Failure, GameState>> redo(int gameId);
  Future<Either<Failure, List<Position>>> getLegalMoves(int gameId, Position position);
  Future<Either<Failure, ChessMove>> getAIMove(int gameId, {int difficulty, Duration? maxTime});
  Future<Either<Failure, double>> evaluatePosition(int gameId);
  Future<Either<Failure, void>> saveGame(int gameId);
  Future<Either<Failure, GameState>> loadGame(String gameId);
  Future<Either<Failure, String>> exportPGN(int gameId);
}
