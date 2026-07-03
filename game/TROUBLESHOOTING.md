# Hướng dẫn Debug App Android

## Vấn đề: Màn hình đen khi mở app

### Nguyên nhân phổ biến:
1. App crash khi khởi động (exception không được handle)
2. Native libraries thiếu
3. Assets/Model files không có
4. Permission issues
5. Theme/rendering issues

---

## Cách 1: Xem Log Chi Tiết (Khuyên dùng)

### Bước 1: Kết nối thiết bị
```bash
# Bật USB Debugging trên điện thoại:
# Settings > Developer Options > USB Debugging

# Kiểm tra kết nối:
adb devices
```

### Bước 2: Chạy script debug
```bash
cd /home/hn/Code/Python/ChessAI/game
./debug_android.sh
```

**Chọn Option 1** (Khuyên dùng nhất):
- Xóa log cũ
- Xem log real-time
- Mở app trên điện thoại
- Xem ngay lỗi xuất hiện

**Hoặc Option 5** (Tự động):
- Tự động cài APK
- Tự động chạy app
- Tự động xem log

### Bước 3: Đọc log
Tìm các dòng có:
- `ERROR` - Lỗi thông thường
- `FATAL` - Lỗi nghiêm trọng
- `AndroidRuntime` - App crash
- `King's Gambit AI` hoặc `kings_gambit_ai` - Log từ app của bạn

---

## Cách 2: Xem Log Trực Tiếp

### Xem chỉ ERROR và CRASH:
```bash
adb logcat *:E
```

### Xem log của app King's Gambit AI:
```bash
adb logcat | grep -E "com.kingsgambit.ai|King's Gambit AI|kings_gambit_ai|Flutter"
```

### Workflow debug nhanh:
```bash
# 1. Xóa log cũ
adb logcat -c

# 2. Mở app trên điện thoại

# 3. Xem log ngay lập tức
adb logcat | grep -E "ERROR|FATAL|AndroidRuntime"
```

---

## Cách 3: Sử dụng Android Studio

1. Mở Android Studio
2. Mở project: `ChessAI/game/android`
3. Kết nối thiết bị
4. Chạy app từ Android Studio
5. Xem log trong tab **Logcat** (ở dưới cùng)
6. Filter theo level: **Error**, **Warn**

---

## Sửa lỗi phổ biến

### Lỗi: Native library không tìm thấy
```
Could not load native library: chess_engine
```

**Giải pháp**: Native library chưa được build. App đã được sửa để handle gracefully - app sẽ chạy mà không có engine.

### Lỗi: Asset không tồn tại
```
Unable to load asset: models/best_model_traced.pt
```

**Giải pháp**: 
1. Thêm model file vào `assets/models/`
2. Hoặc comment out phần load model trong code
3. App đã được sửa để continue nếu model không load được

### Lỗi: Permission denied
```
java.lang.SecurityException: Permission denied
```

**Giải pháp**: Thêm permission vào `AndroidManifest.xml` (đã có INTERNET permission)

---

## Build APK mới sau khi sửa code

```bash
cd /home/hn/Code/Python/ChessAI/game

# Clean build
flutter clean

# Build release APK
flutter build apk --release

# Hoặc build debug APK (có log chi tiết hơn)
flutter build apk --debug
```

**APK file sẽ ở**: 
- Release: `build/app/outputs/flutter-apk/app-release.apk`
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`

---

## Tips Debug

### 1. Build Debug APK thay vì Release
Debug APK có nhiều log hơn và dễ debug hơn:
```bash
flutter build apk --debug
```

### 2. Xem log khi app crash
```bash
adb logcat -c  # xóa log cũ
# Mở app
adb logcat AndroidRuntime:E *:S  # chỉ xem crash log
```

### 3. Xem memory usage
```bash
adb shell dumpsys meminfo com.kingsgambit.ai
```

### 4. Gỡ cài đặt app cũ trước khi cài mới
```bash
adb uninstall com.kingsgambit.ai
adb install -r app-release.apk
```

### 5. Kiểm tra app có cài đúng không
```bash
adb shell pm list packages | grep kingsgambit
```

---

## Code đã được sửa

File: `lib/main.dart`

**Trước đây**: Nếu một service fail → toàn bộ app crash
**Bây giờ**: Mỗi service được handle riêng → app vẫn chạy

```dart
// Engine service - nếu fail, app vẫn chạy
try {
  final engineService = getIt<ChessEngineService>();
  await engineService.initialize('models/best_model_traced.pt');
  AppLogger.info('Chess engine initialized');
} catch (e, stackTrace) {
  AppLogger.error('Chess engine initialization failed (non-critical)', e, stackTrace);
  // Continue without engine - will use fallback
}
```

---

## Nếu vẫn không giải quyết được

1. Chạy `./debug_android.sh` và chọn Option 5
2. Copy toàn bộ log output
3. Tìm dòng có `ERROR`, `FATAL`, hoặc `Exception`
4. Share log để phân tích chi tiết hơn

---

## Checklist Debug

- [ ] Điện thoại đã bật USB Debugging
- [ ] `adb devices` hiển thị thiết bị
- [ ] Đã chạy `./debug_android.sh`
- [ ] Đã xem log khi mở app
- [ ] Đã tìm dòng ERROR/FATAL trong log
- [ ] Đã build lại APK sau khi sửa code
- [ ] Đã gỡ cài đặt app cũ trước khi cài mới
