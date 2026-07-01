# Chess AI - Flutter Game Client

Professional chess game with AI powered by MCTS engine and PyTorch neural network.

## 🎯 Overview

Cross-platform chess application built with Flutter, featuring:
- Play vs AI (10 difficulty levels)
- Human vs Human mode
- Save/Load games
- PGN export/import
- Analysis mode
- Multiple themes and piece sets
- Modern, responsive UI

## 🏗️ Architecture

Built following **Clean Architecture** principles:

```
lib/
├── core/           # Configuration, constants, utilities
├── domain/         # Business logic (entities, use cases)
├── data/           # Data layer (repositories, data sources)
├── presentation/   # UI (screens, widgets, themes)
└── services/       # Infrastructure (engine, audio, storage)
```

## 📋 Prerequisites

- Flutter SDK 3.24+ (install later)
- Dart SDK 3.2+
- C++ compiler (for native bridge)
- CMake 3.10+
- PyTorch C++ (libtorch)

## 🚀 Quick Start

### 1. Setup Assets

Download chess pieces and sounds from Lichess:

```bash
cd /home/hn/Code/Python/ChessAI
./scripts/setup_assets.sh
```

### 2. Install Flutter (if not installed)

```bash
# Download Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
flutter doctor
```

### 3. Get Dependencies

```bash
cd game
flutter pub get
```

### 4. Build Native Bridge

```bash
cd ../native
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make

# Copy library to Flutter
cp libchess_engine.so ../../game/linux/
```

### 5. Run the App

```bash
cd ../../game

# Linux
flutter run -d linux

# Android (with device connected)
flutter run

# Windows
flutter run -d windows
```

## 📦 Project Structure

### Core Layer
- **config/**: App configuration, dependency injection
- **constants/**: Colors, dimensions, durations, strings
- **errors/**: Exception and failure classes
- **utils/**: Logger, extensions, helpers

### Domain Layer
- **entities/**: Pure business objects (Piece, Board, Position, Move, GameState)
- **repositories/**: Repository interfaces
- **usecases/**: Business logic operations

### Data Layer
- **models/**: Data transfer objects
- **repositories/**: Repository implementations
- **datasources/**: Data sources (engine, local storage)

### Presentation Layer
- **screens/**: UI screens (menu, game, settings, etc.)
- **widgets/**: Reusable UI components
- **themes/**: App theming

### Services Layer
- **engine/**: Chess engine service (FFI to C++)
- **ai/**: AI service
- **audio/**: Sound effects
- **storage/**: Save/load games
- **cache/**: Asset caching

## 🎨 Assets

### Chess Pieces
- **cburnett** (default) - Modern, clean style
- **merida** - Tournament style
- **alpha** - Minimalist
- **pixel** - Retro 8-bit

### Board Themes
- Brown (default)
- Blue
- Green
- Purple
- Wood
- Dark

### Sounds
All sounds from Lichess (GPL-3.0):
- Move, Capture, Check, Checkmate, Castle

### Fonts
Using `google_fonts` package (no local files needed):
- **Roboto** - Primary UI font
- **Roboto Mono** - Move notation

## 🧪 Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Test coverage
flutter test --coverage
```

## 🏗️ Build for Release

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### Linux
```bash
flutter build linux --release
```

### Windows
```bash
flutter build windows --release
```

## 📚 Documentation

- [Architecture Guide](../docs/architecture.md)
- [API Reference](../docs/api.md)
- [Assets Guide](../docs/assets.md)
- [Quick Start Guide](../docs/quick_start.md)

## 🔧 Key Dependencies

- **flutter_bloc**: State management
- **get_it**: Dependency injection
- **google_fonts**: Typography
- **flutter_svg**: SVG rendering (pieces)
- **audioplayers**: Sound effects
- **shared_preferences**: Settings storage
- **ffi**: Native C++ bridge

## 🎯 Features Status

- ✅ Core game mechanics
- ✅ Clean architecture structure
- ✅ Cross-platform support
- ✅ Multiple themes
- ✅ Sound effects
- ⏳ AI integration (stub)
- ⏳ Save/Load games (stub)
- ⏳ Analysis mode
- ⏳ Opening explorer

## 🐛 Troubleshooting

### Flutter not found
```bash
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
```

### Native library not found
```bash
# Check library exists
ls game/linux/libchess_engine.so

# Set library path
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/game/linux
```

### Assets not loading
```bash
# Re-run asset setup
./scripts/setup_assets.sh

# Verify pubspec.yaml has assets declared
```

## 📄 License

- Code: (To be determined)
- Assets:
  - Lichess pieces: GPL-3.0
  - Lichess sounds: Open Source
  - Google Fonts: Apache 2.0 / SIL OFL

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📞 Support

For issues or questions:
- Check [documentation](../docs/)
- Review [troubleshooting section](#-troubleshooting)
- Open an issue on GitHub

---

**Note**: This is the Flutter game client. The AI engine (C++) and trained model (PyTorch) are in the parent directory and should not be modified.
