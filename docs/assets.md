# Chess AI - Assets & Resources

## 1. CHESS PIECES (Quân cờ)

### 1.1. CBurnett Chess Set (Recommended - Default)
- **Nguồn**: https://github.com/lichess-org/lila/tree/master/public/piece
- **License**: GPL-3.0 (Free for all uses)
- **Phong cách**: Clean, modern, professional
- **Format**: SVG (scalable, nhỏ gọn)
- **Bộ pieces có sẵn**:
  - cburnett (default - cân bằng, đẹp)
  - merida (classic tournament style)
  - alpha (minimalist)
  - california (modern, rounded)
  - cardinal (traditional)
  - companion (friendly, rounded)
  - dubrovny (elegant)
  - fantasy (artistic)
  - fresca (clean lines)
  - gioco (colorful)
  - governor (professional)
  - horsey (playful)
  - icpieces (sharp, modern)
  - kosal (geometric)
  - leipzig (classic German)
  - letter (text-based)
  - libra (balanced)
  - maestro (elegant)
  - pirouetti (artistic)
  - pixel (retro 8-bit)
  - reillycraig (hand-drawn)
  - riohacha (tropical)
  - shapes (abstract geometric)
  - spatial (3D-ish)
  - staunty (Staunton classic)
  - tatiana (ornate)

**Cách sử dụng**:
```bash
# Clone Lichess repo
git clone --depth 1 https://github.com/lichess-org/lila.git
# Copy pieces
cp -r lila/public/piece/* game/assets/images/pieces/
```

### 1.2. Chess.com Pieces (Alternative)
- **Nguồn**: Có thể tự vẽ inspired by Chess.com style
- **License**: Cần tự tạo (không dùng trực tiếp của Chess.com - có bản quyền)
- **Recommendation**: Dùng Lichess pieces thay vì tự vẽ

### 1.3. Wikimedia Commons Chess Pieces
- **Nguồn**: https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces
- **License**: Public Domain / CC0
- **Sets available**:
  - Classic Staunton
  - Modern variations
  - Historical sets

## 2. BOARD THEMES (Bàn cờ)

### 2.1. Built-in Color Themes (Recommended)
Tạo boards bằng code Flutter (nhẹ, không cần load image):

```dart
// Lichess-inspired themes
final boardThemes = {
  'brown': BoardTheme(
    lightSquare: Color(0xFFF0D9B5),
    darkSquare: Color(0xFFB58863),
  ),
  'blue': BoardTheme(
    lightSquare: Color(0xFFDEE3E6),
    darkSquare: Color(0xFF8CA2AD),
  ),
  'green': BoardTheme(
    lightSquare: Color(0xFFFFFFDD),
    darkSquare: Color(0xFF86A666),
  ),
  'purple': BoardTheme(
    lightSquare: Color(0xFFE8E9B7),
    darkSquare: Color(0xFF9F90B0),
  ),
  'wood': BoardTheme(
    lightSquare: Color(0xFFD5A574),
    darkSquare: Color(0xFF946F51),
  ),
  'dark': BoardTheme(
    lightSquare: Color(0xFF5A5A5A),
    darkSquare: Color(0xFF3A3A3A),
  ),
};
```

### 2.2. Texture-based Boards (Optional, cho premium feel)

#### Wooden Texture
- **Nguồn**: https://www.pexels.com/search/wood%20texture/
- **License**: Pexels License (Free for commercial use)
- **Recommended images**:
  - Light wood: Search "maple wood texture"
  - Dark wood: Search "walnut wood texture"
  - Premium: Search "mahogany texture"

#### Marble Texture
- **Nguồn**: https://unsplash.com/s/photos/marble-texture
- **License**: Unsplash License (Free for commercial)
- **Style**: Elegant, luxury feel

#### Modern/Minimal
- **Nguồn**: Tự tạo gradients trong Flutter
- **Style**: Flat colors với subtle gradients

**Download script**:
```bash
# Sử dụng Pexels API hoặc download manual
# Resize về 2048x2048 (cho high DPI)
# Export ở PNG và WebP formats
```

### 2.3. Board Coordinates
Tạo bằng code Flutter (không cần assets):
- Font: Roboto Medium 12sp
- Color: Contrast với board edge
- Position: A-H (bottom/top), 1-8 (left/right)

## 3. ICONS & UI ELEMENTS

### 3.1. Material Design Icons
- **Package**: `flutter_svg` + Material Icons
- **Nguồn**: Built-in Flutter + https://fonts.google.com/icons
- **License**: Apache License 2.0
- **Icons cần**:
  - play_arrow (Play)
  - settings (Settings)
  - bar_chart (Statistics)
  - person (Profile)
  - replay (Replay)
  - analytics (Analysis)
  - exit_to_app (Exit)
  - undo (Undo)
  - redo (Redo)
  - flip_camera_android (Flip Board)
  - lightbulb (Hint)
  - save (Save)
  - folder_open (Load)
  - volume_up / volume_off (Sound)
  - brightness_6 (Theme toggle)
  - language (Language)

### 3.2. Chess-specific Icons
- **Nguồn**: Tạo custom từ pieces SVG hoặc use Font Awesome Chess icons
- **Font Awesome Chess**: https://fontawesome.com/icons/categories/chess
- **License**: Font Awesome Free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1)
- **Icons**:
  - Chess pieces (all 6 types)
  - King in check icon
  - Castling icon
  - En passant icon

### 3.3. App Icon & Launcher
**Option 1: Tự thiết kế**
- Tool: Figma (free) hoặc Inkscape (open source)
- Style: Minimalist king/knight silhouette
- Colors: Brand colors (suggest: Deep blue + gold)

**Option 2: AI Generation**
- Tool: DALL-E / Midjourney cho concept
- Refine: Trong Figma/Inkscape
- Export: Use `flutter_launcher_icons` package

**Package helper**:
```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#1e1e1e"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
```

## 4. FONTS

### 4.1. Google Fonts (Recommended)
**Package**: `google_fonts` - download on-demand, no asset bundling needed

#### Primary Font: **Roboto**
- **Use**: UI text, buttons, labels
- **License**: Apache License 2.0
- **Weights**: Regular (400), Medium (500), Bold (700)
- **Why**: Clean, readable, Android/Material standard

```dart
import 'package:google_fonts/google_fonts.dart';

final textTheme = TextTheme(
  displayLarge: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold),
  bodyLarge: GoogleFonts.roboto(fontSize: 16),
  // ...
);
```

#### Secondary Font: **Montserrat** (Optional)
- **Use**: Headings, titles, branding
- **License**: SIL Open Font License
- **Weights**: SemiBold (600), Bold (700)
- **Why**: Modern, elegant, pairs well with Roboto

#### Monospace Font: **Roboto Mono**
- **Use**: Move notation (e.g., "1. e4 e5"), FEN strings, PGN export
- **License**: Apache License 2.0
- **Weight**: Regular (400)

### 4.2. Alternative: Bundle Fonts Locally
```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
        - asset: assets/fonts/Roboto-Medium.ttf
          weight: 500
        - asset: assets/fonts/Roboto-Bold.ttf
          weight: 700
```

**Download**:
- https://fonts.google.com/specimen/Roboto
- https://fonts.google.com/specimen/Montserrat

## 5. SOUND EFFECTS

### 5.1. Lichess Sounds (Recommended)
- **Nguồn**: https://github.com/lichess-org/lila/tree/master/public/sound
- **License**: Free to use (part of open source project)
- **Format**: MP3, OGG
- **Sounds included**:
  - `Move.mp3` - Standard move
  - `Capture.mp3` - Capture piece
  - `Check.mp3` - King in check (alert sound)
  - `GenericNotify.mp3` - Game start/end
  - `Dong.mp3` - Game over
  - `Victory.mp3` - Win
  - `Defeat.mp3` - Loss

**Download**:
```bash
wget https://lichess1.org/assets/sound/standard/Move.mp3
wget https://lichess1.org/assets/sound/standard/Capture.mp3
wget https://lichess1.org/assets/sound/standard/Check.mp3
# etc.
```

### 5.2. Freesound.org (Alternative/Additional)
- **Nguồn**: https://freesound.org/
- **License**: CC0 / CC-BY (check individual sounds)
- **Search terms**:
  - "chess move"
  - "wood click"
  - "piece place"
  - "victory fanfare"
  - "lose sound"

**Recommended sounds**:
- Move: Wood/marble click sound
- Capture: Slightly sharper click
- Castle: Double-click sound
- Check: Alert tone (not too loud)
- Checkmate: Victory chime
- Button: Soft UI click

### 5.3. Custom Synthesis (Optional)
- **Tool**: SFXR (https://sfxr.me/) - browser-based, free
- **Use**: Generate retro/arcade style sounds
- **Good for**: Button clicks, UI feedback

### 5.4. Implementation
```yaml
# pubspec.yaml
dependencies:
  audioplayers: ^5.2.0  # For sound effects

flutter:
  assets:
    - assets/sounds/move.mp3
    - assets/sounds/capture.mp3
    - assets/sounds/check.mp3
    - assets/sounds/checkmate.mp3
    - assets/sounds/castle.mp3
    - assets/sounds/button.mp3
```

**Preload all sounds at app start** (per requirement: "không load asset nhiều lần, có cache").

## 6. ANIMATIONS & EFFECTS

### 6.1. Lottie Animations (Optional)
- **Package**: `lottie` - Flutter package for Lottie animations
- **Nguồn**: https://lottiefiles.com/
- **License**: Free animations available (check each animation)
- **Use cases**:
  - Splash screen animation
  - Loading spinners
  - Victory celebration
  - Thinking indicator (for AI)

**Recommended free animations**:
- "Chess pieces animation" (search on LottieFiles)
- "Loading spinner"
- "Checkmark success"
- "Trophy/victory"

### 6.2. Built-in Flutter Animations (Recommended)
**Piece Movement**:
```dart
AnimatedPositioned(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // ... position
)
```

**Highlight Effects**:
```dart
AnimatedOpacity(
  duration: Duration(milliseconds: 200),
  opacity: isHighlighted ? 1.0 : 0.0,
  child: Container(/* highlight square */),
)
```

**Ripple Effect**:
```dart
InkWell(
  splashColor: Colors.blue.withOpacity(0.3),
  onTap: () {},
  child: // square
)
```

### 6.3. Particle Effects (Advanced, Optional)
- **Package**: `flutter_particles` hoặc custom particle system
- **Use**: Checkmate celebration, piece capture explosion
- **Priority**: Low (implement sau khi core game hoàn thành)

## 7. BACKGROUND IMAGES (Optional)

### 7.1. Subtle Patterns
- **Nguồn**: https://www.toptal.com/designers/subtlepatterns/
- **License**: CC BY-SA 3.0
- **Use**: Background cho main menu, settings
- **Style**: Subtle, không làm rối UI

### 7.2. Gradients (Recommended)
Tạo bằng code Flutter:
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
    ),
  ),
)
```

## 8. ASSET ORGANIZATION STRUCTURE

```
game/assets/
├── images/
│   ├── pieces/
│   │   ├── cburnett/          # Default set
│   │   │   ├── wK.svg
│   │   │   ├── wQ.svg
│   │   │   ├── ... (all 12 pieces)
│   │   ├── merida/            # Alternative set
│   │   ├── alpha/
│   │   └── pixel/
│   ├── boards/
│   │   ├── wooden_light.png   # Optional textures
│   │   ├── wooden_dark.png
│   │   └── marble.png
│   ├── icons/
│   │   └── app_icon.png       # Launcher icon
│   └── backgrounds/
│       └── subtle_pattern.png
├── sounds/
│   ├── move.mp3
│   ├── capture.mp3
│   ├── check.mp3
│   ├── checkmate.mp3
│   ├── castle.mp3
│   └── button.mp3
├── fonts/                      # If not using google_fonts
│   ├── Roboto-Regular.ttf
│   ├── Roboto-Medium.ttf
│   └── Roboto-Bold.ttf
└── animations/
    └── lottie/
        ├── splash.json
        └── thinking.json
```

## 9. ASSET LOADING STRATEGY (Performance)

### 9.1. Preload Critical Assets
```dart
// main.dart
Future<void> preloadAssets(BuildContext context) async {
  // Preload all piece images
  final pieceFiles = [
    'wK', 'wQ', 'wR', 'wB', 'wN', 'wP',
    'bK', 'bQ', 'bR', 'bB', 'bN', 'bP',
  ];
  
  for (final piece in pieceFiles) {
    await precachePicture(
      ExactAssetPicture(
        SvgPicture.svgStringDecoderBuilder,
        'assets/images/pieces/cburnett/$piece.svg',
      ),
      context,
    );
  }
  
  // Preload sounds
  await audioService.preloadAll();
}
```

### 9.2. Lazy Load Optional Assets
- Board textures: Load khi user thay đổi theme
- Alternative piece sets: Load on-demand
- Lottie animations: Load khi cần hiển thị

### 9.3. Caching
```dart
// Dùng flutter_cache_manager cho images từ network (nếu có)
// Dùng shared_preferences cho user preferences
// Assets local đã được cache tự động bởi Flutter
```

## 10. DOWNLOAD & SETUP SCRIPT

Tạo script tự động download assets:

```bash
#!/bin/bash
# setup_assets.sh

echo "Setting up Chess AI assets..."

# Create directories
mkdir -p game/assets/{images/{pieces,boards,icons},sounds,fonts}

# Download Lichess pieces (cburnett set)
echo "Downloading chess pieces..."
git clone --depth 1 https://github.com/lichess-org/lila.git temp_lichess
cp -r temp_lichess/public/piece/cburnett game/assets/images/pieces/
cp -r temp_lichess/public/piece/merida game/assets/images/pieces/
cp -r temp_lichess/public/piece/alpha game/assets/images/pieces/
rm -rf temp_lichess

# Download Lichess sounds
echo "Downloading sound effects..."
wget -P game/assets/sounds/ https://lichess1.org/assets/sound/standard/Move.mp3
wget -P game/assets/sounds/ https://lichess1.org/assets/sound/standard/Capture.mp3
wget -P game/assets/sounds/ https://lichess1.org/assets/sound/standard/Check.mp3
wget -P game/assets/sounds/ https://lichess1.org/assets/sound/standard/GenericNotify.mp3

# Rename sounds
cd game/assets/sounds/
mv Move.mp3 move.mp3
mv Capture.mp3 capture.mp3
mv Check.mp3 check.mp3
mv GenericNotify.mp3 checkmate.mp3
cd ../../..

echo "Assets setup complete!"
echo "Note: Fonts will be loaded via google_fonts package (no download needed)"
```

## 11. LICENSES SUMMARY

| Asset Type | Source | License | Commercial Use |
|------------|--------|---------|----------------|
| Chess Pieces | Lichess (cburnett) | GPL-3.0 | ✅ Yes |
| Sound Effects | Lichess | Open Source | ✅ Yes |
| Icons | Material Icons | Apache 2.0 | ✅ Yes |
| Icons | Font Awesome | CC BY 4.0 | ✅ Yes |
| Fonts | Google Fonts | Apache 2.0 / SIL OFL | ✅ Yes |
| Wood Textures | Pexels | Pexels License | ✅ Yes |
| Marble Textures | Unsplash | Unsplash License | ✅ Yes |
| Lottie Animations | LottieFiles | Varies (check each) | ⚠️ Check |

**Tất cả assets đề xuất đều MIỄN PHÍ cho commercial use.**

## 12. TOTAL SIZE ESTIMATE

```
Pieces (3 sets × SVG):        ~2-3 MB
Sounds (6 files × MP3):       ~500 KB
Board textures (optional):    ~2 MB (nếu dùng)
Fonts (local, optional):      ~500 KB (nếu không dùng google_fonts)
Icons (built-in):             0 KB (Material Icons included)
Animations (optional):        ~200 KB

TOTAL (minimal):  ~3-4 MB
TOTAL (full):     ~5-6 MB
```

**Tối ưu cho Android 2GB+ RAM**: ✅ Pass

## 13. NEXT STEPS

1. ✅ Review danh sách assets
2. ⏳ Chạy `setup_assets.sh` để download
3. ⏳ Test load assets trên emulator
4. ⏳ Tối ưu kích thước nếu cần (compress images, convert to WebP)
5. ⏳ Update pubspec.yaml với asset paths
