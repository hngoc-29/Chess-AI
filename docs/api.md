# Chess Engine Service API

## 1. TỔNG QUAN

EngineService là lớp giao tiếp giữa Flutter UI và C++ Chess Engine. Sử dụng **dart:ffi** để gọi các hàm C++ thông qua shared library.

```
Flutter (Dart)
      ↓
ChessEngineService.dart
      ↓
FFI Bindings (engine_bindings.dart)
      ↓
Native Bridge (libchess_engine.so/dll/dylib)
      ↓
C++ Engine Wrapper (engine_wrapper.cpp)
      ↓
Existing Chess Engine (mcts.cpp, ChessEnv.cpp)
```

## 2. NATIVE BRIDGE API (C++)

### 2.1. Initialization

```cpp
// Initialize engine và load AI model
// Returns: 0 on success, error code on failure
extern "C" int32_t native_init(const char* model_path);

// Cleanup và free resources
extern "C" void native_cleanup();
```

### 2.2. Game Management

```cpp
// Create new game
// Returns: game_id
extern "C" int32_t native_new_game();

// Delete game instance
extern "C" void native_delete_game(int32_t game_id);

// Reset game to initial position
extern "C" void native_reset_game(int32_t game_id);

// Set position from FEN string
// Returns: 0 on success, -1 on invalid FEN
extern "C" int32_t native_set_position(
    int32_t game_id,
    const char* fen
);

// Get current FEN string
// Returns: FEN string (caller must free)
extern "C" char* native_get_fen(int32_t game_id);
```

### 2.3. Move Operations

```cpp
// Make a move
// from, to: chess notation (e.g., "e2", "e4")
// promotion: promotion piece ('Q', 'R', 'B', 'N') or '\0'
// Returns: 0 on success, -1 on illegal move
extern "C" int32_t native_make_move(
    int32_t game_id,
    const char* from,
    const char* to,
    char promotion
);

// Undo last move
// Returns: 0 on success, -1 if no moves to undo
extern "C" int32_t native_undo(int32_t game_id);

// Redo move
// Returns: 0 on success, -1 if no moves to redo
extern "C" int32_t native_redo(int32_t game_id);

// Get legal moves for a square
// square: chess notation (e.g., "e2")
// Returns: JSON array of legal moves, e.g., ["e3", "e4"]
//          Caller must free
extern "C" char* native_get_legal_moves(
    int32_t game_id,
    const char* square
);

// Get all legal moves in current position
// Returns: JSON array of move objects
//          [{"from": "e2", "to": "e4", "promotion": null}, ...]
extern "C" char* native_get_all_legal_moves(int32_t game_id);
```

### 2.4. AI Operations

```cpp
// Get AI's best move
// difficulty: 1-10 (controls MCTS simulations)
// max_time_ms: maximum thinking time
// Returns: JSON object with move and stats
//          {
//            "from": "e7",
//            "to": "e5",
//            "promotion": null,
//            "nodes_searched": 10000,
//            "depth": 12,
//            "evaluation": 0.15
//          }
extern "C" char* native_get_ai_move(
    int32_t game_id,
    int32_t difficulty,
    int32_t max_time_ms
);

// Start AI thinking in background
// Returns: thinking_id for cancellation
extern "C" int32_t native_start_ai_thinking(
    int32_t game_id,
    int32_t difficulty,
    int32_t max_time_ms
);

// Cancel AI thinking
extern "C" void native_cancel_ai_thinking(int32_t thinking_id);

// Check if AI is still thinking
// Returns: 1 if thinking, 0 if done
extern "C" int32_t native_is_ai_thinking(int32_t thinking_id);

// Get AI thinking result (blocking)
// Returns: same as native_get_ai_move
extern "C" char* native_get_ai_result(int32_t thinking_id);

// Get AI thinking progress
// Returns: JSON object with current stats
//          {"nodes_searched": 5000, "depth": 8, "progress": 0.5}
extern "C" char* native_get_ai_progress(int32_t thinking_id);
```

### 2.5. Game State Queries

```cpp
// Get current turn
// Returns: 0 for white, 1 for black
extern "C" int32_t native_get_current_turn(int32_t game_id);

// Check if game is over
// Returns: 0 if ongoing, 1 if checkmate, 2 if stalemate,
//          3 if draw by repetition, 4 if draw by 50-move rule
extern "C" int32_t native_get_game_status(int32_t game_id);

// Check if current side is in check
// Returns: 1 if in check, 0 otherwise
extern "C" int32_t native_is_in_check(int32_t game_id);

// Get piece at square
// square: chess notation (e.g., "e2")
// Returns: piece character ('K', 'Q', 'R', 'B', 'N', 'P' for white,
//          'k', 'q', 'r', 'b', 'n', 'p' for black, '.' for empty)
extern "C" char native_get_piece_at(
    int32_t game_id,
    const char* square
);

// Get full board state
// Returns: JSON array of 64 pieces (a1, b1, ..., h8)
extern "C" char* native_get_board(int32_t game_id);
```

### 2.6. Evaluation

```cpp
// Evaluate current position
// Returns: evaluation score (positive = white advantage)
//          in centipawns (100 = 1 pawn advantage)
extern "C" float native_evaluate(int32_t game_id);

// Get detailed evaluation breakdown
// Returns: JSON object with evaluation details
//          {
//            "total": 150,
//            "material": 200,
//            "position": -30,
//            "mobility": -20,
//            "king_safety": 0
//          }
extern "C" char* native_get_evaluation_details(int32_t game_id);
```

### 2.7. Move History

```cpp
// Get move history
// Returns: JSON array of moves
//          [
//            {"from": "e2", "to": "e4", "piece": "P", "captured": null},
//            {"from": "e7", "to": "e5", "piece": "p", "captured": null}
//          ]
extern "C" char* native_get_move_history(int32_t game_id);

// Get move count
extern "C" int32_t native_get_move_count(int32_t game_id);
```

### 2.8. PGN Export/Import

```cpp
// Export game to PGN
// Returns: PGN string
extern "C" char* native_export_pgn(
    int32_t game_id,
    const char* white_player,
    const char* black_player,
    const char* event,
    const char* date
);

// Import game from PGN
// Returns: 0 on success, -1 on error
extern "C" int32_t native_import_pgn(
    int32_t game_id,
    const char* pgn
);
```

### 2.9. Error Handling

```cpp
// Get last error message
// Returns: error string (caller must free)
extern "C" char* native_get_last_error();
```

## 3. FLUTTER SERVICE API (Dart)

### 3.1. ChessEngineService Class

```dart
class ChessEngineService {
  /// Initialize engine with AI model
  Future<void> initialize(String modelPath);
  
  /// Cleanup resources
  void dispose();
  
  /// Create new game
  /// Returns game ID
  Future<int> newGame();
  
  /// Delete game
  Future<void> deleteGame(int gameId);
  
  /// Reset game to starting position
  Future<void> resetGame(int gameId);
  
  /// Set position from FEN
  Future<void> setPosition(int gameId, String fen);
  
  /// Get current FEN
  Future<String> getFen(int gameId);
  
  /// Make a move
  /// Throws InvalidMoveException if move is illegal
  Future<void> makeMove(
    int gameId,
    String from,
    String to,
    {PieceType? promotion}
  );
  
  /// Undo last move
  /// Returns false if no moves to undo
  Future<bool> undo(int gameId);
  
  /// Redo move
  /// Returns false if no moves to redo
  Future<bool> redo(int gameId);
  
  /// Get legal moves for a piece
  Future<List<String>> getLegalMoves(int gameId, String square);
  
  /// Get all legal moves
  Future<List<ChessMove>> getAllLegalMoves(int gameId);
  
  /// Get AI's best move
  /// Returns move and thinking stats
  Future<AIMove> getAIMove(
    int gameId,
    {int difficulty = 5, Duration? maxTime}
  );
  
  /// Start AI thinking (async)
  /// Returns thinking ID
  Future<int> startAIThinking(
    int gameId,
    {int difficulty = 5, Duration? maxTime}
  );
  
  /// Cancel AI thinking
  Future<void> cancelAIThinking(int thinkingId);
  
  /// Check if AI is thinking
  Future<bool> isAIThinking(int thinkingId);
  
  /// Get AI thinking progress
  /// Returns stream of progress updates
  Stream<AIProgress> getAIProgress(int thinkingId);
  
  /// Get current turn (Color.white or Color.black)
  Future<Color> getCurrentTurn(int gameId);
  
  /// Get game status
  Future<GameStatus> getGameStatus(int gameId);
  
  /// Check if in check
  Future<bool> isInCheck(int gameId);
  
  /// Get piece at square
  Future<Piece?> getPieceAt(int gameId, String square);
  
  /// Get full board state
  Future<Board> getBoard(int gameId);
  
  /// Evaluate position
  Future<double> evaluate(int gameId);
  
  /// Get detailed evaluation
  Future<EvaluationDetails> getEvaluationDetails(int gameId);
  
  /// Get move history
  Future<List<ChessMove>> getMoveHistory(int gameId);
  
  /// Export to PGN
  Future<String> exportPGN(
    int gameId,
    {String? whitePlayer,
    String? blackPlayer,
    String? event,
    DateTime? date}
  );
  
  /// Import from PGN
  Future<void> importPGN(int gameId, String pgn);
}
```

### 3.2. Data Classes

```dart
/// Chess move
class ChessMove {
  final String from;
  final String to;
  final PieceType? promotion;
  final Piece? captured;
  final bool isCheck;
  final bool isCheckmate;
  final bool isCastle;
  final bool isEnPassant;
}

/// AI move with stats
class AIMove {
  final ChessMove move;
  final int nodesSearched;
  final int depth;
  final double evaluation;
  final Duration thinkingTime;
}

/// AI thinking progress
class AIProgress {
  final int nodesSearched;
  final int depth;
  final double progress; // 0.0 to 1.0
  final ChessMove? bestMove;
}

/// Board state
class Board {
  final List<List<Piece?>> squares; // 8x8 grid
  final Color currentTurn;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final String? enPassantSquare;
  final int halfMoveClock;
  final int fullMoveNumber;
}

/// Piece
class Piece {
  final PieceType type;
  final Color color;
}

enum PieceType { king, queen, rook, bishop, knight, pawn }
enum Color { white, black }

/// Game status
enum GameStatus {
  ongoing,
  checkmate,
  stalemate,
  drawByRepetition,
  drawByFiftyMoveRule,
  drawByInsufficientMaterial,
}

/// Evaluation details
class EvaluationDetails {
  final double total;
  final double material;
  final double position;
  final double mobility;
  final double kingSafety;
}
```

### 3.3. Exceptions

```dart
class ChessEngineException implements Exception {
  final String message;
  ChessEngineException(this.message);
}

class InvalidMoveException extends ChessEngineException {
  InvalidMoveException(String message) : super(message);
}

class EngineNotInitializedException extends ChessEngineException {
  EngineNotInitializedException() 
      : super('Engine not initialized. Call initialize() first.');
}

class GameNotFoundException extends ChessEngineException {
  GameNotFoundException(int gameId) 
      : super('Game with id $gameId not found.');
}
```

## 4. USAGE EXAMPLES

### 4.1. Initialize Engine

```dart
final engineService = ChessEngineService();
await engineService.initialize('models/best_model_traced.pt');
```

### 4.2. New Game

```dart
final gameId = await engineService.newGame();
final board = await engineService.getBoard(gameId);
```

### 4.3. Make Move

```dart
try {
  await engineService.makeMove(gameId, 'e2', 'e4');
  // Play sound, update UI
} on InvalidMoveException catch (e) {
  // Show error to user
  print('Invalid move: ${e.message}');
}
```

### 4.4. Get AI Move (Blocking)

```dart
final aiMove = await engineService.getAIMove(
  gameId,
  difficulty: 5,
  maxTime: Duration(seconds: 10),
);

await engineService.makeMove(
  gameId,
  aiMove.move.from,
  aiMove.move.to,
  promotion: aiMove.move.promotion,
);

print('AI searched ${aiMove.nodesSearched} nodes');
print('Best move evaluation: ${aiMove.evaluation}');
```

### 4.5. Get AI Move (Async with Progress)

```dart
// Start AI thinking
final thinkingId = await engineService.startAIThinking(
  gameId,
  difficulty: 7,
  maxTime: Duration(seconds: 30),
);

// Listen to progress updates
engineService.getAIProgress(thinkingId).listen((progress) {
  print('Progress: ${(progress.progress * 100).toInt()}%');
  print('Nodes: ${progress.nodesSearched}, Depth: ${progress.depth}');
  // Update UI with thinking animation
});

// Wait for result
while (await engineService.isAIThinking(thinkingId)) {
  await Future.delayed(Duration(milliseconds: 100));
}

// Note: In real implementation, use FutureBuilder or StreamBuilder
```

### 4.6. Legal Moves

```dart
// Get legal moves for a specific piece
final legalMoves = await engineService.getLegalMoves(gameId, 'e2');
// Returns: ['e3', 'e4']

// Get all legal moves
final allMoves = await engineService.getAllLegalMoves(gameId);
// Returns: [ChessMove(from: 'e2', to: 'e4'), ...]
```

### 4.7. Undo/Redo

```dart
// Undo
if (await engineService.undo(gameId)) {
  // Move was undone
}

// Redo
if (await engineService.redo(gameId)) {
  // Move was redone
}
```

### 4.8. Check Game Status

```dart
final status = await engineService.getGameStatus(gameId);
if (status == GameStatus.checkmate) {
  final winner = await engineService.getCurrentTurn(gameId);
  showGameOverDialog(winner == Color.white ? 'Black' : 'White');
}

final isCheck = await engineService.isInCheck(gameId);
if (isCheck) {
  playCheckSound();
  highlightKing();
}
```

### 4.9. Export/Import PGN

```dart
// Export
final pgn = await engineService.exportPGN(
  gameId,
  whitePlayer: 'Player',
  blackPlayer: 'AI Level 5',
  event: 'Casual Game',
  date: DateTime.now(),
);

// Import
await engineService.importPGN(gameId, pgn);
```

### 4.10. Evaluation

```dart
// Simple evaluation
final eval = await engineService.evaluate(gameId);
print('Position evaluation: $eval centipawns');

// Detailed evaluation
final details = await engineService.getEvaluationDetails(gameId);
print('Material: ${details.material}');
print('Position: ${details.position}');
print('Mobility: ${details.mobility}');
```

## 5. THREADING & CONCURRENCY

### 5.1. Isolate Usage

Tất cả engine calls chạy trên background isolate để không block UI thread:

```dart
class ChessEngineService {
  late final Isolate _engineIsolate;
  late final SendPort _engineSendPort;
  
  Future<void> initialize(String modelPath) async {
    final receivePort = ReceivePort();
    _engineIsolate = await Isolate.spawn(
      _engineIsolateEntry,
      receivePort.sendPort,
    );
    _engineSendPort = await receivePort.first;
    
    // Initialize engine on isolate
    await _sendCommand('init', {'modelPath': modelPath});
  }
  
  Future<T> _sendCommand<T>(String command, Map<String, dynamic> args) async {
    final responsePort = ReceivePort();
    _engineSendPort.send({
      'command': command,
      'args': args,
      'responsePort': responsePort.sendPort,
    });
    return await responsePort.first;
  }
}
```

### 5.2. Cancellation

AI thinking có thể bị cancel:

```dart
// Start thinking
final thinkingId = await startAIThinking(gameId);

// User cancels
await cancelAIThinking(thinkingId);
```

## 6. ERROR HANDLING

### 6.1. Engine Errors

```dart
try {
  await engineService.makeMove(gameId, 'e2', 'e5');
} on InvalidMoveException catch (e) {
  // Invalid move - show error to user
  showError(e.message);
} on GameNotFoundException catch (e) {
  // Game not found - shouldn't happen in normal flow
  logError(e);
} on ChessEngineException catch (e) {
  // Generic engine error
  showError('Engine error: ${e.message}');
}
```

### 6.2. Native Crashes

Nếu native code crash, isolate sẽ die và cần restart:

```dart
_engineIsolate.addErrorListener((error) {
  logError('Engine isolate crashed: $error');
  // Restart engine
  initialize(modelPath);
});
```

## 7. PERFORMANCE CONSIDERATIONS

### 7.1. Caching

Cache frequently accessed data:

```dart
class ChessEngineService {
  final _legalMovesCache = <int, Map<String, List<String>>>{};
  
  Future<List<String>> getLegalMoves(int gameId, String square) async {
    // Check cache
    if (_legalMovesCache[gameId]?[square] != null) {
      return _legalMovesCache[gameId]![square]!;
    }
    
    // Fetch from engine
    final moves = await _nativeGetLegalMoves(gameId, square);
    
    // Cache result
    _legalMovesCache[gameId] ??= {};
    _legalMovesCache[gameId]![square] = moves;
    
    return moves;
  }
  
  void _invalidateCache(int gameId) {
    _legalMovesCache.remove(gameId);
  }
}
```

### 7.2. Batching

Batch multiple queries:

```dart
Future<(Board, GameStatus, bool)> getGameState(int gameId) async {
  // Single native call returns all info
  final state = await _nativeGetGameState(gameId);
  return (state.board, state.status, state.isCheck);
}
```

### 7.3. Memory Management

Free native memory properly:

```dart
@override
void dispose() {
  _engineSendPort.send({'command': 'cleanup'});
  _engineIsolate.kill();
  super.dispose();
}
```

## 8. TESTING

### 8.1. Mock Service

```dart
class MockChessEngineService implements ChessEngineService {
  @override
  Future<void> makeMove(int gameId, String from, String to, 
      {PieceType? promotion}) async {
    // Mock implementation for tests
    if (from == 'e2' && to == 'e9') {
      throw InvalidMoveException('Square e9 does not exist');
    }
  }
  
  // ... other mock methods
}
```

### 8.1. Integration Tests

```dart
void main() {
  late ChessEngineService service;
  
  setUp(() async {
    service = ChessEngineService();
    await service.initialize('test_model.pt');
  });
  
  tearDown(() {
    service.dispose();
  });
  
  test('New game starts with correct position', () async {
    final gameId = await service.newGame();
    final fen = await service.getFen(gameId);
    expect(fen, startsWith('rnbqkbnr/pppppppp'));
  });
  
  test('Legal moves for e2 pawn', () async {
    final gameId = await service.newGame();
    final moves = await service.getLegalMoves(gameId, 'e2');
    expect(moves, containsAll(['e3', 'e4']));
  });
  
  test('Invalid move throws exception', () async {
    final gameId = await service.newGame();
    expect(
      () => service.makeMove(gameId, 'e2', 'e5'),
      throwsA(isA<InvalidMoveException>()),
    );
  });
}
```

## 9. BUILD CONFIGURATION

### 9.1. CMake (Native Library)

```cmake
# native/CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
project(chess_engine)

# Link existing AI engine
add_subdirectory(../AI/engine engine)

# Build bridge
add_library(chess_engine SHARED
  src/bridge.cpp
  src/engine_wrapper.cpp
)

target_link_libraries(chess_engine
  chess_ai_engine  # Existing engine
  torch            # PyTorch
)
```

### 9.2. Flutter Build

```yaml
# android/app/build.gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }
}
```

Copy native libs:
- Android: `android/app/src/main/jniLibs/`
- Windows: `windows/runner/`
- Linux: `linux/`
- macOS: `macos/`
