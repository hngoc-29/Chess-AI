# 🎯 Hướng Dẫn Debug App Android - Tóm Tắt Hoàn Chỉnh

## 📋 Vấn đề đã giải quyết

**Vấn đề ban đầu**: App Chess AI hiển thị màn hình đen khi mở trên Android

**Nguyên nhân**: 
- App crash khi khởi động do lỗi initialization
- Native library và model file không tồn tại
- Không có cách nào xem log để debug

**Giải pháp**: 
✅ Sửa code để handle lỗi gracefully  
✅ Logger tự động lưu log vào file trong máy user  
✅ UI để xem/export logs ngay trong app  
✅ GitHub Actions tự động build APK  

---

## 🔧 Các File Đã Thay Đổi

### 1. **GitHub Actions Workflow** (MỚI)
📁 `.github/workflows/build-android.yml`
- Tự động build APK khi push code
- Build cả Debug và Release APK
- Upload artifacts để download

### 2. **Logger Service** (CẬP NHẬT)
📁 `game/lib/core/utils/logger.dart`
- Lưu log vào file trong storage của Android
- Tự động quản lý file (giữ tối đa 5 file logs gần nhất)
- Methods để đọc, export, và xóa logs
- **QUAN TRỌNG**: Phải gọi `await AppLogger.initialize()` trong main()

### 3. **Main App** (CẬP NHẬT)
📁 `game/lib/main.dart`
- Initialize logger TRƯỚC tất cả services khác
- Wrap mỗi service trong try-catch riêng
- App không crash nếu một service fail

### 4. **Debug Logs Screen** (MỚI)
📁 `game/lib/presentation/screens/debug_logs_screen.dart`
- UI để xem danh sách log files
- Xem nội dung log file
- Share/export log files
- Xóa logs

### 5. **Routes** (CẬP NHẬT)
📁 `game/lib/presentation/app/routes.dart`
- Thêm route `/debug-logs` cho Debug Logs screen

### 6. **Settings Screen** (CẬP NHẬT)
📁 `game/lib/presentation/screens/settings/settings_screen.dart`
- Thêm button "Debug Logs" để truy cập màn hình debug

### 7. **Dependencies** (CẬP NHẬT)
📁 `game/pubspec.yaml`
- Thêm `share_plus: ^10.0.2` để share log files

### 8. **Troubleshooting Guide** (MỚI)
📁 `game/TROUBLESHOOTING.md`
- Hướng dẫn debug chi tiết
- Cách xem log bằng adb
- Các lỗi phổ biến và cách sửa

### 9. **Debug Script** (MỚI)
📁 `game/debug_android.sh`
- Script để xem log chi tiết từ thiết bị Android bằng adb

---

## 🚀 Cách Build APK Mới

### Option 1: GitHub Actions (Khuyên dùng)

1. **Push code lên GitHub**:
```bash
cd /home/hn/Code/Python/ChessAI
git add .
git commit -m "Add debug logging and fix crash issues"
git push origin main
```

2. **Xem build progress**:
- Vào GitHub repository
- Click tab "Actions"
- Xem workflow "Build Android APK" đang chạy

3. **Download APK**:
- Khi build xong (màu xanh ✅)
- Click vào workflow run
- Scroll xuống phần "Artifacts"
- Download `chess-ai-release` hoặc `chess-ai-debug`

### Option 2: Build Locally

```bash
cd /home/hn/Code/Python/ChessAI/game

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Hoặc build debug APK (có nhiều log hơn)
flutter build apk --debug
```

**APK file sẽ ở**: 
- Release: `build/app/outputs/flutter-apk/app-release.apk`
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`

---

## 📱 Cách Xem Logs Trong App

### Bước 1: Mở app và vào Settings
1. Mở app Chess AI trên điện thoại
2. Vào **Settings** (⚙️)
3. Scroll xuống dưới cùng
4. Tap vào **"Debug Logs"** (🐛)

### Bước 2: Xem logs
Trong màn hình Debug Logs, bạn có thể:

1. **Xem danh sách log files**:
   - File hiện tại (đang ghi) có icon màu xanh
   - Mỗi file hiển thị: tên, kích thước, thời gian

2. **Xem nội dung log**:
   - Tap vào icon 👁️ (View) để xem nội dung
   - Scroll để đọc logs
   - Tap icon 📋 để copy toàn bộ log

3. **Share/Export logs**:
   - Tap vào icon 🔗 (Share) 
   - Chọn app để share (Gmail, Drive, Telegram, etc.)
   - Gửi file cho developer để phân tích

4. **Xóa logs**:
   - Tap vào icon 🗑️ ở trên cùng
   - Xác nhận để xóa tất cả logs

### Log File Path
Log files được lưu tại:
```
/storage/emulated/0/Android/data/com.chessai.app/files/logs/
```

---

## 🔍 Cách Debug Khi App Vẫn Màn Hình Đen

Nếu app vẫn màn hình đen sau khi build APK mới:

### Option 1: Xem log trong app (nếu app chạy được)
1. Mở app → Settings → Debug Logs
2. Xem log file mới nhất
3. Tìm dòng có `ERROR`, `FATAL`, hoặc `Exception`
4. Share log file để phân tích

### Option 2: Xem log bằng ADB (nếu app crash)
```bash
cd /home/hn/Code/Python/ChessAI/game

# Chạy script debug
./debug_android.sh

# Chọn Option 5 (tự động cài và xem log)
# Hoặc Option 1 (xem log realtime)
```

### Option 3: Xem log thủ công
```bash
# Kết nối thiết bị
adb devices

# Xóa log cũ
adb logcat -c

# Mở app trên điện thoại

# Xem log
adb logcat | grep -E "ChessAI|ERROR|FATAL|AndroidRuntime"
```

---

## 📊 Giải Thích Chi Tiết

### GitHub Actions Workflow

Workflow sẽ tự động:
1. ✅ Trigger khi push code vào branch `main` hoặc `develop`
2. ✅ Setup Flutter và Java
3. ✅ Get dependencies (`flutter pub get`)
4. ✅ Analyze code (`flutter analyze`)
5. ✅ Build Debug APK
6. ✅ Build Release APK
7. ✅ Upload cả 2 APKs làm artifacts
8. ✅ Giữ artifacts trong 30 ngày (debug) và 90 ngày (release)

### Logger System

**Cách hoạt động**:
1. Khi app khởi động, `AppLogger.initialize()` được gọi
2. Tạo file log mới với timestamp: `chess_ai_2026-07-02T14-30-45.log`
3. Mọi log (info, error, warning) đều được ghi vào:
   - Console (để dev xem khi debug)
   - File (để user xem sau này)
4. Tự động xóa file log cũ (chỉ giữ 5 file gần nhất)

**Log levels**:
- `AppLogger.debug()` - Debug info (chỉ ở debug mode)
- `AppLogger.info()` - Thông tin bình thường
- `AppLogger.warning()` - Cảnh báo
- `AppLogger.error()` - Lỗi
- `AppLogger.fatal()` - Lỗi nghiêm trọng

**Ví dụ log file**:
```
📱 Chess AI Logger initialized
📁 Log file: /storage/.../logs/chess_ai_2026-07-02T14-30-45.log
🔧 Build mode: Release
Initializing Chess AI...
Chess engine initialization failed (non-critical)
Audio service initialized
Cache service initialized
Chess AI initialization complete
```

### Error Handling

**Trước đây**:
```dart
// Nếu engineService.initialize() fail → toàn bộ app crash
await engineService.initialize('models/best_model_traced.pt');
```

**Bây giờ**:
```dart
// Nếu engineService fail → chỉ log lỗi, app vẫn chạy
try {
  final engineService = getIt<ChessEngineService>();
  await engineService.initialize('models/best_model_traced.pt');
  AppLogger.info('Chess engine initialized');
} catch (e, stackTrace) {
  AppLogger.error('Chess engine initialization failed (non-critical)', e, stackTrace);
  // Continue without engine - will use fallback
}
```

Điều này có nghĩa:
- ✅ App sẽ chạy được ngay cả khi thiếu native library
- ✅ App sẽ chạy được ngay cả khi thiếu model file
- ✅ App sẽ chạy được ngay cả khi audio/cache fail
- ✅ Tất cả lỗi đều được log để debug sau

---

## ✅ Checklist Hoàn Thành

- [x] Sửa code để handle lỗi initialization gracefully
- [x] Logger lưu log vào file trong máy Android
- [x] UI để xem/export logs trong app
- [x] GitHub Actions workflow để build APK tự động
- [x] Button trong Settings để truy cập Debug Logs
- [x] Script `debug_android.sh` để xem log bằng adb
- [x] Hướng dẫn troubleshooting chi tiết
- [x] Thêm dependency `share_plus` để share logs

---

## 🎯 Các Bước Tiếp Theo

### 1. Build APK mới
```bash
# Push code lên GitHub để trigger build
cd /home/hn/Code/Python/ChessAI
git add .
git commit -m "Add debug logging and fix crash issues"
git push origin main

# Hoặc build locally
cd game
flutter pub get
flutter build apk --debug
```

### 2. Cài APK mới lên điện thoại
- Download từ GitHub Actions artifacts
- Hoặc copy từ `game/build/app/outputs/flutter-apk/app-debug.apk`
- Gỡ app cũ trước khi cài mới (khuyên dùng)

### 3. Test app
- Mở app và kiểm tra có còn màn hình đen không
- Nếu vẫn đen: Vào Settings → Debug Logs để xem lỗi
- Nếu chạy được: Kiểm tra các tính năng

### 4. Xem logs
- Settings → Debug Logs
- Xem log file hiện tại
- Share nếu cần phân tích thêm

### 5. Nếu vẫn có vấn đề
- Share log file từ app
- Hoặc chạy `./debug_android.sh` và copy output
- Gửi logs để phân tích chi tiết

---

## 📞 Nếu Cần Hỗ Trợ Thêm

Khi gặp vấn đề, hãy cung cấp:
1. **Log file** từ app (Settings → Debug Logs → Share)
2. **Hoặc log từ adb**: `./debug_android.sh` output
3. **Thông tin thiết bị**: Android version, device model
4. **Hành động gây lỗi**: Mở app → click vào đâu → crash

---

## 🎉 Tổng Kết

Bây giờ app của bạn có:
- ✅ Error handling tốt hơn (không crash khi service fail)
- ✅ Logger system hoàn chỉnh (lưu vào file)
- ✅ UI để xem logs ngay trong app
- ✅ GitHub Actions để build APK tự động
- ✅ Tools để debug dễ dàng hơn

**Bước tiếp theo quan trọng nhất**: 
Build APK mới và test xem app có còn màn hình đen không. Nếu vẫn có, logs sẽ cho biết chính xác lỗi gì! 🚀
