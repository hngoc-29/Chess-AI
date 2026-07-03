# Tích hợp Maia Chess làm đối thủ AI

Tài liệu này ghi lại những gì đã được thêm vào để game dùng các mạng **Maia**
(chơi giống người, theo từng mức Elo) thay vì (hoặc cùng với) engine minimax
tự viết trước đó.

## Tóm tắt kiến trúc

- **Trước đây**: `GameBloc` gọi `ChessAIEngine.getBestMove()` — một minimax +
  alpha-beta thuần Dart, chạy ngay trong app, không cần model gì cả. Các file
  `services/ai/ai_service.dart` và `services/engine/chess_engine_service.dart`
  là code khung cho một cầu nối FFI C++/LibTorch **chưa từng được xây dựng**
  (không có file `.cpp` bridge nào, không dùng `dart:ffi`) — đây là code chết,
  không đụng tới.
- **Bây giờ**: `MaiaAIEngine` (kế thừa `ChessAIEngine`) thay thế vị trí đó
  trong DI container (`injection.dart`). Nó nói chuyện UCI với engine `lc0`
  thật (được đóng gói sẵn qua gói Flutter `leela_chess_zero`), nạp 1 trong 9
  file trọng số Maia tuỳ theo độ khó, rồi xin nước đi tốt nhất.
- Nếu engine native không khởi động được vì bất kỳ lý do gì (thiết bị lạ,
  plugin cài lỗi, ...), `MaiaAIEngine` tự động rơi về lại minimax gốc — game
  không bao giờ bị "đứng" vì thiếu đối thủ.

Maia không phải file `.pt`/TorchScript như model bạn tự train trong `/AI` —
nó là 9 file `.pb.gz` định dạng lc0, **chỉ chạy được qua binary `lc0`**, nên
không thể nạp thẳng vào MCTS C++ hiện có của bạn. Đây là lý do dùng
`leela_chess_zero` (đã đóng gói sẵn `lc0` cho Android/iOS) thay vì tự
cross-compile.

## Các file đã thay đổi/thêm mới

| File | Thay đổi |
|---|---|
| `pubspec.yaml` | Thêm dependency `leela_chess_zero` (git, xem lý do bên dưới), đăng ký `assets/weights/` |
| `android/app/build.gradle` | `minSdkVersion` 21→24, `compileSdk` 34→36, `ndkVersion` →28.2.13676358 (bắt buộc bởi plugin) |
| `assets/weights/maia-*.pb.gz` | 9 file trọng số Maia thật (1100–1900 Elo, ~12MB tổng), tải từ [CSSLab/maia-chess](https://github.com/CSSLab/maia-chess) |
| `lib/services/ai/maia_ai_engine.dart` | **Mới.** Engine nói UCI với lc0, có fallback |
| `lib/domain/entities/settings.dart` | `AIDifficulty` mở rộng 4 → 6 mức |
| `lib/services/ai/chess_ai_engine.dart` | Thêm case cho 2 mức mới; thêm tham số `halfMoveClock`/`fullMoveNumber` (không bắt buộc) vào interface chung |
| `lib/core/config/injection.dart` | Đăng ký `MaiaAIEngine` thay cho `ChessAIEngine` trần |
| `lib/presentation/blocs/game/game_bloc.dart` | Truyền thêm half-move/full-move cho FEN chuẩn; giải phóng engine lúc `close()` |
| `lib/presentation/blocs/settings/settings_bloc.dart` | Sửa `clamp(0,3)` → theo đúng độ dài enum mới |
| `lib/data/datasources/local/preferences_datasource.dart` | Sửa giá trị mặc định `5` (rác, không khớp enum cũ) → `2` (medium) |
| `lib/presentation/screens/settings/settings_screen.dart` | Nhãn tiếng Việt cho 6 mức, kèm Elo tham khảo |

`lib/core/utils/fen_utils.dart` (đã có sẵn từ trước, không cần sửa) cung cấp
`boardToFen()` — dùng lại nguyên bản để sinh FEN gửi cho lc0.

## Bảng ánh xạ độ khó → mạng Maia

| AIDifficulty | Mạng | Nodes | Ghi chú |
|---|---|---|---|
| `beginner` | maia-1100 | 1 | không search, đúng tinh thần Maia |
| `easy` | maia-1300 | 1 | |
| `medium` | maia-1500 | 1 | mặc định |
| `hard` | maia-1700 | 1 | |
| `veryHard` | maia-1900 | 1 | mạng "người" mạnh nhất hiện có |
| `expert` | maia-1900 | 800 | search sâu hơn nhiều → mạnh hơn 1900 thật sự, nhưng bớt "giống người" |

Muốn có một mức thật sự siêu mạnh (engine-strength, không phải "giống
người") sau này, chỉ cần tải thêm 1 mạng lc0 chuẩn (không phải Maia, ví dụ từ
lczero.org) vào `assets/weights/` và thêm một dòng vào `_kMaiaProfiles` trong
`maia_ai_engine.dart`.

## Vụ build lỗi trên CI (đã tìm ra nguyên nhân + fix)

Lần build đầu trên GitHub Actions bị lỗi ở bước biên dịch native của
`leela_chess_zero`:

```
fatal error: 'proto/net.pb.h' file not found
```

**Nguyên nhân** (đã xác nhận bằng cách tự clone source của package về xem):
`android/CMakeLists.txt` của `leela_chess_zero` include đúng đường dẫn
`ios/lc0/build` để tìm 3 file protobuf-header đã được generate sẵn
(`net.pb.h`, `hlo.pb.h`, `onnx.pb.h`). 3 file này **có tồn tại và có commit
vào git** của package (force-add qua rule `.gitignore` chặn `build/`), nhưng
khi tác giả `dart pub publish` lên pub.dev, bản đóng gói xuất bản dường như
đã loại bỏ 3 file này (rất có thể do công cụ publish của Dart tôn trọng rule
gitignore bất kể file có bị force-track hay không). Kết quả: ai cài
`leela_chess_zero: ^1.0.0` qua pub.dev cũng sẽ gặp lỗi y hệt — đây là lỗi ở
package, không phải do code hay cấu hình phía bạn.

**Cách fix** (đã áp vào `pubspec.yaml`): đổi dependency từ bản pub.dev sang
git dependency, trỏ thẳng vào repo GitHub của package — `git clone` sẽ lấy
đúng các file đã commit, bỏ qua việc lọc theo gitignore mà quy trình publish
của pub.dev áp dụng.

```yaml
leela_chess_zero:
  git:
    url: https://github.com/ArjanAswal/LeelaChessZero.git
    ref: main
```

Đồng thời log build còn yêu cầu nâng `compileSdk` 34→36 và `ndkVersion`
25.x→`28.2.13676358` — đã sửa trong `android/app/build.gradle`.

Nếu về sau tác giả package fix lại publish (chạy `dart pub publish` với các
file đó được include đúng), bạn có thể đổi lại về
`leela_chess_zero: ^<version-mới>` cho gọn.

## Việc bạn cần tự làm tiếp

Mình không có Flutter SDK trong sandbox này nên vẫn chưa build/chạy thử lại
được sau fix này — cần bạn:

1. `flutter pub get` lại trong thư mục `game/` để lấy git dependency mới.
2. Build lại (`flutter build apk` hoặc CI) — với fix này, bước CMake nên qua
   được. Nếu vẫn lỗi ở chỗ khác trong quá trình build native (đây là package
   khá non/ít người dùng, 3 file trên có thể không phải vấn đề duy nhất),
   gửi lại log cho mình, mình sẽ tiếp tục đào sâu vào source của package.
3. Chạy thử trên thiết bị/emulator Android thật (API ≥ 24) — bấm cho AI đi
   vài nước ở từng độ khó để chắc `lc0` khởi động và trả `bestmove` đúng.
4. `import 'package:leela_chess_zero/lc0.dart';` trong `maia_ai_engine.dart`
   — đã xác nhận đúng 100% (kiểm tra trực tiếp `lib/lc0.dart` trong source
   của package), không cần đổi.

## Lưu ý về giấy phép (không phải tư vấn pháp lý)

`leela_chess_zero` nhúng binary `lc0`, phát hành theo **GPL-3.0**. Nếu bạn
định phát hành app (đặc biệt là closed-source/lên store), nên tìm hiểu kỹ
nghĩa vụ copyleft của GPL-3.0 áp dụng thế nào cho phần này, hoặc hỏi người
có chuyên môn pháp lý nếu bạn cần app giữ mã nguồn đóng.
