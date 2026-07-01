# Chess AI - Kiến Trúc Hệ Thống

## 1. TỔNG QUAN

Hệ thống Chess AI được xây dựng theo mô hình **Clean Architecture** với 3 thành phần chính:

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Game Client                       │
│                  (Android/Windows/Linux/macOS)               │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ FFI (dart:ffi)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Native Bridge (C++)                        │
│              (engine_wrapper.cpp, bridge.cpp)                │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
┌──────────────────────┐      ┌──────────────────────┐
│   Chess Engine       │      │   AI Model (PyTorch) │
│   (C++ - MCTS)       │      │   best_model.pt      │
└──────────────────────┘      └──────────────────────┘
```

## 2. CLEAN ARCHITECTURE LAYERS

### 2.1. Presentation Layer
- **Screens**: UI screens (Main Menu, Game, Settings, etc.)
- **Widgets**: Reusable UI components
- **Controllers**: State management và business logic cho UI
- **Themes**: Styling và theming

**Nguyên tắc:**
- Không chứa business logic
- Chỉ hiển thị dữ liệu và nhận input từ user
- Phụ thuộc vào Domain layer qua UseCases

### 2.2. Domain Layer (Business Logic)
- **Entities**: Pure Dart objects (Piece, Board, Position, Move)
- **Repository Interfaces**: Contracts cho data access
- **Use Cases**: Business rules (MakeMove, GetLegalMoves, GetAIMove, SaveGame)

**Nguyên tắc:**
- Không phụ thuộc vào framework
- Không biết về UI hay data source
- Pure business logic

### 2.3. Data Layer
- **Models**: Data Transfer Objects (DTOs)
- **Repositories**: Implementation của interfaces từ Domain
- **Data Sources**: Local storage, Engine binding, Cache

**Nguyên tắc:**
- Implement interfaces từ Domain layer
- Convert giữa Models (DTOs) và Entities
- Xử lý I/O operations

### 2.4. Services Layer (Infrastructure)
- **ChessEngineService**: Gọi C++ engine qua FFI
- **AIService**: Load và run PyTorch model
- **AudioService**: Quản lý sound effects
- **StorageService**: Save/load games
- **CacheService**: Cache assets và game states

**Nguyên tắc:**
- Infrastructure concerns
- Được inject vào UseCases thông qua Dependency Injection
- Không chứa business logic

## 3. SƠ ĐỒ MODULE CHI TIẾT

```
┌─────────────────────────────────────────────────────────────┐
│                       PRESENTATION                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Splash  │  │MainMenu  │  │  Game    │  │ Settings │   │
│  │ Screen   │─▶│ Screen   │─▶│ Screen   │  │ Screen   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│        │            │              │              │          │
│        └────────────┴──────────────┴──────────────┘          │
│                          │                                   │
│                          ▼                                   │
│              ┌────────────────────────┐                      │
│              │   Game Controller      │                      │
│              │  (State Management)    │                      │
│              └────────────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Uses
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                         DOMAIN                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    Use Cases                         │   │
│  │  • MakeMove         • GetLegalMoves                 │   │
│  │  • UndoMove         • RedoMove                      │   │
│  │  • GetAIMove        • EvaluatePosition              │   │
│  │  • SaveGame         • LoadGame                      │   │
│  │  • ExportPGN        • LoadFEN                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                   │
│                          │ Uses                              │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Repository Interfaces                   │   │
│  │  • IGameRepository                                   │   │
│  │  • ISettingsRepository                               │   │
│  │  • IStatsRepository                                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    Entities                          │   │
│  │  • Piece          • Board                           │   │
│  │  • Position       • ChessMove                       │   │
│  │  • Player         • GameState                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Implements
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                          DATA                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Repository Implementations              │   │
│  │  • GameRepository                                    │   │
│  │  • SettingsRepository                                │   │
│  │  • StatsRepository                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                   │
│              ┌───────────┴───────────┐                      │
│              ▼                       ▼                      │
│  ┌──────────────────┐    ┌──────────────────┐             │
│  │  Local Storage   │    │  Engine Bridge   │             │
│  │  DataSource      │    │  DataSource      │             │
│  └──────────────────┘    └──────────────────┘             │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Uses
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       SERVICES                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │  Engine    │  │    AI      │  │   Audio    │           │
│  │  Service   │  │  Service   │  │  Service   │           │
│  └────────────┘  └────────────┘  └────────────┘           │
│        │                │                │                  │
│        ▼                ▼                ▼                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │  Storage   │  │   Cache    │  │ Navigation │           │
│  │  Service   │  │  Service   │  │  Service   │           │
│  └────────────┘  └────────────┘  └────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

## 4. LUỒNG HOẠT ĐỘNG CHI TIẾT

### 4.1. Khởi động ứng dụng

```
User launches app
      ↓
main.dart initializes
      ↓
Load dependencies (DI setup)
      ↓
ChessEngineService.initialize()
      ↓
Load native library (libchess_engine.so/dll/dylib)
      ↓
AIService.loadModel("models/best_model_traced.pt")
      ↓
AudioService.preloadSounds()
      ↓
CacheService.preloadAssets()
      ↓
Navigate to SplashScreen
      ↓
Show logo + loading animation
      ↓
Navigate to MainMenuScreen
```

### 4.2. Bắt đầu game mới (Play vs AI)

```
User taps "Play vs AI"
      ↓
MainMenuController.startNewGame(mode: PlayMode.vsAI)
      ↓
Navigate to GameScreen
      ↓
GameController.initialize()
      ↓
UseCase: NewGameUseCase.execute()
      ↓
Repository: GameRepository.createNewGame()
      ↓
Service: ChessEngineService.newGame()
      ↓
FFI Bridge: native_new_game()
      ↓
C++ Engine: Initialize board state
      ↓
Return initial GameState to UI
      ↓
UI renders chess board
```

### 4.3. User thực hiện nước đi

```
User drags piece from e2 to e4
      ↓
ChessBoardWidget.onPieceDragged(from: e2, to: e4)
      ↓
GameController.makeMove(from: e2, to: e4)
      ↓
UseCase: MakeMoveUseCase.execute(from, to)
      ↓
UseCase calls: GetLegalMovesUseCase.execute(from: e2)
      ↓
Repository: GameRepository.getLegalMoves(e2)
      ↓
Service: ChessEngineService.getLegalMoves(e2)
      ↓
FFI: native_get_legal_moves(e2)
      ↓
C++ Engine: Calculate legal moves
      ↓
Return legal moves [e3, e4]
      ↓
Check if e4 is in legal moves
      ↓
If valid:
  ├─ Repository.makeMove(e2, e4)
  ├─ Service: ChessEngineService.makeMove(e2, e4)
  ├─ FFI: native_make_move(e2, e4)
  ├─ C++ Engine: Execute move
  ├─ AudioService.playSound(SoundEffect.move)
  ├─ Update GameState
  └─ UI animates piece movement
      ↓
If invalid:
  ├─ UI shows error feedback
  └─ Piece returns to original position
```

### 4.4. AI thực hiện nước đi

```
After user's move completes
      ↓
GameController.requestAIMove()
      ↓
UseCase: GetAIMoveUseCase.execute()
      ↓
Repository: GameRepository.getAIMove()
      ↓
Service: AIService.getBestMove(currentState)
      ↓
FFI: native_get_ai_move()
      ↓
C++ Engine:
  ├─ Run MCTS (mcts.cpp)
  ├─ Query neural network (best_model.pt)
  ├─ Search tree for N simulations
  └─ Select best move
      ↓
Return Move(from: g8, to: f6)
      ↓
UseCase: MakeMoveUseCase.execute(g8, f6)
      ↓
Repository.makeMove(g8, f6)
      ↓
Service: ChessEngineService.makeMove(g8, f6)
      ↓
C++ Engine: Execute AI move
      ↓
AudioService.playSound(SoundEffect.move)
      ↓
Update GameState
      ↓
UI animates AI piece movement
      ↓
Check game over conditions
```

### 4.5. Lưu game

```
User taps "Save Game"
      ↓
GameController.saveGame()
      ↓
UseCase: SaveGameUseCase.execute()
      ↓
Repository: GameRepository.saveGame(gameState)
      ↓
Service: StorageService.saveToFile(gameState)
      ↓
Convert GameState to JSON
      ↓
Write to: /storage/games/game_<timestamp>.json
      ↓
Return success
      ↓
UI shows "Game saved" snackbar
```

### 4.6. Load game đã lưu

```
User taps "Load Game"
      ↓
Navigate to LoadGameScreen
      ↓
LoadGameController.loadGamesList()
      ↓
StorageService.getSavedGames()
      ↓
Display list of saved games
      ↓
User selects a game
      ↓
UseCase: LoadGameUseCase.execute(gameId)
      ↓
Repository: GameRepository.loadGame(gameId)
      ↓
Service: StorageService.readFromFile(gameId)
      ↓
Parse JSON to GameState
      ↓
Service: ChessEngineService.setPosition(fen)
      ↓
FFI: native_set_position(fen)
      ↓
C++ Engine: Set board state from FEN
      ↓
Navigate to GameScreen with loaded state
      ↓
UI renders loaded position
```

### 4.7. Undo/Redo moves

```
User taps "Undo" button
      ↓
GameController.undo()
      ↓
UseCase: UndoMoveUseCase.execute()
      ↓
Repository: GameRepository.undo()
      ↓
Service: ChessEngineService.undo()
      ↓
FFI: native_undo()
      ↓
C++ Engine: Revert to previous state
      ↓
Update GameState
      ↓
UI animates reverse piece movement
      ↓
AudioService.playSound(SoundEffect.undo)
```

## 5. DEPENDENCY INJECTION

Sử dụng **get_it** package cho Service Locator pattern:

```dart
// core/injection.dart
final getIt = GetIt.instance;

void setupDependencies() {
  // Services
  getIt.registerSingleton<ChessEngineService>(ChessEngineService());
  getIt.registerSingleton<AIService>(AIService());
  getIt.registerSingleton<AudioService>(AudioService());
  getIt.registerSingleton<StorageService>(StorageService());
  
  // Repositories
  getIt.registerLazySingleton<IGameRepository>(
    () => GameRepository(
      engineService: getIt<ChessEngineService>(),
      storageService: getIt<StorageService>(),
    ),
  );
  
  // Use Cases
  getIt.registerFactory(() => MakeMoveUseCase(getIt<IGameRepository>()));
  getIt.registerFactory(() => GetAIMoveUseCase(getIt<IGameRepository>()));
  // ...
}
```

## 6. STATE MANAGEMENT

Sử dụng **flutter_bloc** cho state management:

```dart
class GameBloc extends Bloc<GameEvent, GameState> {
  final MakeMoveUseCase makeMoveUseCase;
  final GetAIMoveUseCase getAIMoveUseCase;
  
  GameBloc({
    required this.makeMoveUseCase,
    required this.getAIMoveUseCase,
  }) : super(GameInitial());
  
  @override
  Stream<GameState> mapEventToState(GameEvent event) async* {
    if (event is MakeMoveEvent) {
      yield* _mapMakeMoveToState(event);
    } else if (event is GetAIMoveEvent) {
      yield* _mapGetAIMoveToState(event);
    }
  }
}
```

## 7. ERROR HANDLING

```dart
// core/errors/failures.dart
abstract class Failure {
  final String message;
  Failure(this.message);
}

class EngineFailure extends Failure {
  EngineFailure(String message) : super(message);
}

class InvalidMoveFailure extends Failure {
  InvalidMoveFailure(String message) : super(message);
}

// Use in UseCases
class MakeMoveUseCase {
  Future<Either<Failure, GameState>> execute(Move move) async {
    try {
      final result = await repository.makeMove(move);
      return Right(result);
    } on InvalidMoveException catch (e) {
      return Left(InvalidMoveFailure(e.message));
    } on EngineException catch (e) {
      return Left(EngineFailure(e.message));
    }
  }
}
```

## 8. PERFORMANCE OPTIMIZATIONS

### 8.1. Asset Management
- Preload tất cả piece images khi app khởi động
- Cache board themes
- Use AssetBundle để load nhanh

### 8.2. Rendering
- Use RepaintBoundary cho chess board
- Optimize piece movement animations với AnimatedPositioned
- Use const constructors khi có thể

### 8.3. Engine Calls
- Run engine operations trên background isolate
- Cache legal moves cho current position
- Debounce evaluation calculations

### 8.4. Memory Management
- Dispose controllers properly
- Clear cache khi không cần
- Limit undo history (default: 50 moves)

## 9. TESTING STRATEGY

```
test/
├── unit/
│   ├── domain/
│   │   ├── entities/
│   │   └── usecases/
│   ├── data/
│   │   └── repositories/
│   └── services/
├── widget/
│   ├── screens/
│   └── widgets/
└── integration/
    ├── game_flow_test.dart
    └── ai_interaction_test.dart
```

### 9.1. Unit Tests
- Test all UseCases với mock repositories
- Test Entities business logic
- Test Repository implementations với mock data sources

### 9.2. Widget Tests
- Test UI components render correctly
- Test user interactions
- Test state changes

### 9.3. Integration Tests
- Test complete game flows
- Test AI integration
- Test save/load functionality

## 10. BUILD & DEPLOYMENT

### 10.1. Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### 10.2. Windows
```bash
flutter build windows --release
```

### 10.3. Linux
```bash
flutter build linux --release
```

### 10.4. macOS
```bash
flutter build macos --release
```

Native libraries (libchess_engine) phải được compiled cho từng platform và đặt trong:
- Android: `android/app/src/main/jniLibs/`
- Windows: `windows/runner/`
- Linux: `linux/`
- macOS: `macos/`
