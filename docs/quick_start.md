# Chess AI - Quick Start Guide

## 📋 TÓM TẮT DỰ ÁN

**Chess AI Game Client** - Game cờ vua chuyên nghiệp, cross-platform với AI mạnh.

### Tech Stack
- **Framework**: Flutter 3.x (Dart)
- **Engine**: C++ (existing MCTS engine)
- **AI**: PyTorch (existing trained model)
- **State Management**: flutter_bloc
- **Dependency Injection**: get_it
- **FFI Bridge**: dart:ffi

### Platforms
✅ Android | ✅ Windows | ✅ Linux | ✅ macOS

### Key Features
- Play vs AI (10 difficulty levels)
- Human vs Human
- Save/Load games
- Undo/Redo
- Analysis mode
- PGN export/import
- Multiple board themes
- Multiple piece sets
- Dark/Light themes
- Evaluation bar
- Move history
- Captured pieces display

## 🏗️ KIẾN TRÚC

```
┌─────────────────────────────────────┐
│     Flutter UI (Presentation)       │
│  Screens, Widgets, Themes, Bloc     │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│     Domain Layer (Business Logic)   │
│  Entities, UseCases, Repositories   │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│         Data Layer                   │
│  Repository Impl, DataSources        │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│       Services Layer                 │
│  Engine, AI, Audio, Storage          │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│    Native Bridge (C++ FFI)           │
│  engine_wrapper.cpp, bridge.cpp      │
└─────────────┬───────────────────────┘
              │
      ┌───────┴────────┐
      ▼                ▼
┌──────────┐    ┌──────────┐
│  Engine  │    │  AI Model│
│  (C++)   │    │(PyTorch) │
└──────────┘    └──────────┘
```

## 📁 CẤU TRÚC THƯ MỤC

```
ChessAI/
├── AI/                     # Existing (không đụng)
├── models/                 # Existing (không đụng)
├── game/                   # Flutter client (MỚI)
│   ├── lib/
│   │   ├── core/          # Config, constants, utils
│   │   ├── data/          # Models, repositories, datasources
│   │   ├── domain/        # Entities, usecases
│   │   ├── presentation/  # UI (screens, widgets, themes)
│   │   ├── services/      # Infrastructure services
│   │   └── main.dart
│   ├── assets/            # Images, sounds, fonts
│   ├── test/
│   └── pubspec.yaml
├── native/                 # C++ bridge (MỚI)
│   ├── src/
│   │   ├── bridge.cpp
│   │   └── engine_wrapper.cpp
│   └── CMakeLists.txt
└── docs/                   # Documentation (MỚI)
    ├── architecture.md
    ├── api.md
    ├── assets.md
    └── quick_start.md (this file)
```

## 🚀 SETUP INSTRUCTIONS

### Prerequisites

```bash
# 1. Flutter SDK (3.24+)
flutter --version

# 2. Dart SDK (included with Flutter)
dart --version

# 3. CMake (3.10+)
cmake --version

# 4. C++ compiler
g++ --version  # Linux
cl             # Windows (Visual Studio)
clang --version # macOS

# 5. Android SDK (for Android builds)
# Install via Android Studio

# 6. PyTorch C++ (libtorch)
# Download from: https://pytorch.org/get-started/locally/
```

### Step 1: Setup Flutter Project

```bash
# Navigate to project root
cd /home/hn/Code/Python/ChessAI

# Create Flutter project
flutter create game

# Or if already exists, get dependencies
cd game
flutter pub get
```

### Step 2: Download Assets

```bash
# Run asset setup script
chmod +x scripts/setup_assets.sh
./scripts/setup_assets.sh

# This will download:
# - Chess pieces from Lichess
# - Sound effects
# - Fonts (optional, if not using google_fonts)
```

### Step 3: Build Native Bridge

```bash
# Build C++ bridge library
cd native
mkdir build && cd build

# Linux
cmake .. -DCMAKE_BUILD_TYPE=Release
make

# Copy library to Flutter
cp libchess_engine.so ../../game/linux/

# Windows (from Visual Studio Command Prompt)
cmake .. -G "Visual Studio 17 2022"
cmake --build . --config Release
copy Release\chess_engine.dll ..\..\game\windows\runner\

# macOS
cmake .. -DCMAKE_BUILD_TYPE=Release
make
cp libchess_engine.dylib ../../game/macos/
```

### Step 4: Configure Flutter Dependencies

Edit `game/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # Dependency Injection
  get_it: ^7.6.4
  
  # UI
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  
  # Audio
  audioplayers: ^5.2.1
  
  # Storage
  shared_preferences: ^2.2.2
  path_provider: ^2.1.1
  
  # FFI
  ffi: ^2.1.0
  
  # Utils
  intl: ^0.18.1
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
  mockito: ^5.4.4
```

### Step 5: Run the App

```bash
cd game

# Desktop (Linux)
flutter run -d linux

# Desktop (Windows)
flutter run -d windows

# Desktop (macOS)
flutter run -d macos

# Android (with device/emulator connected)
flutter run

# Hot reload during development
# Press 'r' in terminal
```

## 📦 DEPENDENCIES EXPLAINED

### Core Flutter Packages

| Package | Purpose | Why |
|---------|---------|-----|
| `flutter_bloc` | State management | Reactive, testable, scales well |
| `get_it` | Service locator/DI | Simple, no code generation needed |
| `ffi` | Call C++ code | Required for engine integration |

### UI Packages

| Package | Purpose | Why |
|---------|---------|-----|
| `google_fonts` | Typography | 1000+ fonts, no bundling needed |
| `flutter_svg` | SVG rendering | Chess pieces are SVG (scalable) |

### Platform Packages

| Package | Purpose | Why |
|---------|---------|-----|
| `shared_preferences` | Settings storage | Simple key-value store |
| `path_provider` | File paths | Cross-platform file access |
| `audioplayers` | Sound effects | Cross-platform audio |

## 🎨 THEMING

### Built-in Themes

1. **Dark Theme** (default)
   - Background: Deep blue-gray
   - Board: Brown wooden style
   - Pieces: CBurnett (Lichess default)

2. **Light Theme**
   - Background: Light gray
   - Board: Light wooden style
   - Pieces: CBurnett

### Board Themes

- Brown (default)
- Blue
- Green
- Purple
- Wood texture (optional)
- Marble (optional)

### Piece Sets

- CBurnett (default) - Modern, clean
- Merida - Tournament style
- Alpha - Minimalist
- Pixel - Retro 8-bit

## 🎵 SOUNDS

All sounds from Lichess (GPL-3.0):
- `move.mp3` - Standard move
- `capture.mp3` - Capture piece
- `check.mp3` - King in check
- `checkmate.mp3` - Game over
- `castle.mp3` - Castling move

## 🧪 TESTING

```bash
# Unit tests
flutter test

# Widget tests
flutter test test/widget/

# Integration tests (requires running app)
flutter test integration_test/

# Test coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 🏗️ BUILD FOR RELEASE

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Windows

```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

### Linux

```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

### macOS

```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/
```

## 📊 PERFORMANCE TARGETS

### Minimum Requirements
- Android: 2GB RAM, Android 5.0+ (API 21+)
- Windows: 4GB RAM, Windows 10+
- Linux: 4GB RAM, Ubuntu 20.04+
- macOS: 4GB RAM, macOS 10.14+

### Performance Goals
- 60 FPS UI rendering
- < 100ms move animation
- < 50ms legal moves calculation
- AI thinking: 1-30 seconds (depending on difficulty)
- App startup: < 3 seconds
- Asset loading: < 1 second

### Size Targets
- APK size: < 50 MB
- App bundle: < 40 MB (after split APKs)
- Desktop app: < 100 MB

## 🐛 TROUBLESHOOTING

### Flutter Issues

```bash
# Clean build
flutter clean
flutter pub get

# Doctor check
flutter doctor -v

# Upgrade Flutter
flutter upgrade
```

### Native Library Issues

**Linux: Library not found**
```bash
# Check if library exists
ls game/linux/libchess_engine.so

# Check dependencies
ldd game/linux/libchess_engine.so

# Set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/game/linux
```

**Android: UnsatisfiedLinkError**
```bash
# Verify .so files in correct location
ls game/android/app/src/main/jniLibs/arm64-v8a/libchess_engine.so
ls game/android/app/src/main/jniLibs/armeabi-v7a/libchess_engine.so

# Rebuild native library for Android
cd native
./build_android.sh
```

### Performance Issues

**Slow UI rendering**
- Enable performance overlay: `flutter run --profile`
- Check for rebuilds: Add `debugPrintRebuildDirtyWidgets = true` in main.dart
- Use `RepaintBoundary` for chess board

**Slow AI thinking**
- Reduce MCTS simulations (difficulty level)
- Check if model is loaded correctly
- Verify model file path

### Asset Loading Issues

**Images not showing**
```yaml
# Verify pubspec.yaml has assets declared
flutter:
  assets:
    - assets/images/pieces/
    - assets/sounds/
```

**Fonts not loading**
```dart
// Use google_fonts package (no local files needed)
import 'package:google_fonts/google_fonts.dart';
Text('Hello', style: GoogleFonts.roboto());
```

## 📚 DOCUMENTATION

- **Architecture**: [docs/architecture.md](./architecture.md)
- **API Reference**: [docs/api.md](./api.md)
- **Assets Guide**: [docs/assets.md](./assets.md)

## 🔗 USEFUL LINKS

### Flutter Resources
- Flutter Docs: https://docs.flutter.dev/
- Dart Docs: https://dart.dev/guides
- Pub.dev: https://pub.dev/

### Chess Resources
- Lichess Open Source: https://github.com/lichess-org/lila
- Chess.com API: https://www.chess.com/news/view/published-data-api
- PGN Specification: https://ia902908.us.archive.org/26/items/pgn-standard-1994-03-12/PGN_standard_1994-03-12.txt

### Assets
- Lichess Pieces: https://github.com/lichess-org/lila/tree/master/public/piece
- Google Fonts: https://fonts.google.com/
- Material Icons: https://fonts.google.com/icons
- Pexels (textures): https://www.pexels.com/

## 🎯 ROADMAP

### Phase 1: Core Game (Current)
- ✅ Architecture design
- ✅ Asset planning
- ⏳ Flutter project setup
- ⏳ Native bridge implementation
- ⏳ Basic UI (board, pieces, moves)
- ⏳ Engine integration
- ⏳ AI integration

### Phase 2: Features
- Settings screen
- Save/Load games
- PGN export/import
- Multiple themes
- Sound effects
- Animations

### Phase 3: Advanced Features
- Analysis mode
- Evaluation bar
- Opening explorer
- Endgame trainer
- Statistics tracking

### Phase 4: Polish & Release
- Performance optimization
- Bug fixes
- Play Store submission
- Marketing materials

## 💡 TIPS

### Development
- Use hot reload frequently (`r` in terminal)
- Test on real devices, not just emulators
- Use Flutter DevTools for debugging
- Write tests as you go

### Performance
- Profile before optimizing
- Use `const` constructors everywhere possible
- Avoid rebuilding entire widget tree
- Cache expensive computations

### Code Quality
- Follow Dart style guide
- Use meaningful variable names
- Keep functions small (< 50 lines)
- Write comments for non-obvious code only

## 🤝 CONTRIBUTING

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 LICENSE

Assets:
- Lichess pieces: GPL-3.0
- Lichess sounds: Open Source
- Google Fonts: Apache 2.0 / SIL OFL

Code: (To be determined)
