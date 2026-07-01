class ChessException implements Exception {
  final String message;
  const ChessException(this.message);

  @override
  String toString() => 'ChessException: $message';
}

class EngineException extends ChessException {
  const EngineException(super.message);
}

class InvalidMoveException extends ChessException {
  const InvalidMoveException(super.message);
}

class GameNotFoundException extends ChessException {
  const GameNotFoundException(super.message);
}

class EngineNotInitializedException extends ChessException {
  const EngineNotInitializedException()
      : super('Engine not initialized. Call initialize() first.');
}

class StorageException extends ChessException {
  const StorageException(super.message);
}

class CacheException extends ChessException {
  const CacheException(super.message);
}
