abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class EngineFailure extends Failure {
  const EngineFailure(super.message);
}

class InvalidMoveFailure extends Failure {
  const InvalidMoveFailure(super.message);
}

class GameNotFoundFailure extends Failure {
  const GameNotFoundFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
