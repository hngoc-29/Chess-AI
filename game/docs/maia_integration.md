# Tích hợp Maia Chess làm đối thủ AI (bản ONNX Runtime)

> Đây là bản viết lại hoàn toàn. Cách làm đầu tiên (bundle engine `lc0` thật
> qua gói `leela_chess_zero`) đã bị bỏ sau khi gặp 2 vấn đề nghiêm trọng: bản
> pub.dev thiếu file cần thiết để build Android, và có dấu hiệu treo/crash ở
> tầng native khi chơi thực tế (log không ghi được lỗi nào sau một điểm cụ
> thể — dấu hiệu của crash tiến trình, không phải lỗi Dart bình thường).
> Xem lịch sử trò chuyện nếu cần biết chi tiết quá trình debug đó.

## Ý tưởng cốt lõi

Maia, về bản chất, chỉ là một mạng neural network (giống các mạng AlphaZero
khác). Việc `lc0` làm chỉ là: (1) mã hoá bàn cờ → tensor đầu vào, (2) chạy
qua mạng, (3) đọc tensor đầu ra → nước đi. Với `go nodes 1` (cách Maia được
thiết kế để dùng — **không search**), lc0 chỉ chạy đúng 1 lần forward pass.

Vậy có thể bỏ hẳn `lc0`/UCI/subprocess, chuyển thẳng 9 file `.pb.gz` sang
`.onnx`, rồi chạy qua **ONNX Runtime** ngay trong Dart. Không còn tiến trình
native riêng, không còn pipe, không còn giao thức UCI — chỉ còn 1 lời gọi
hàm suy luận (inference) bình thường.

## Cái giá phải trả

Đổi lại, phải tự viết bằng Dart 2 phần mà `lc0` trước đây lo hộ:
1. **Encode bàn cờ → tensor đầu vào** đúng định dạng mà mạng Maia mong đợi.
2. **Decode tensor đầu ra → nước đi thật.**

Đây là 2 phần dễ sai nhất trong toàn bộ việc này, vì sai một chi tiết nhỏ
(thứ tự plane, quy ước lật bàn cờ khi đến lượt Đen, cách map UCI→index...)
sẽ khiến mạng chạy ra kết quả vô nghĩa mà **không hề có lỗi hay crash nào cả**
— im lặng cho nước đi sai, khó phát hiện hơn cả một crash rõ ràng.

**Vì vậy toàn bộ logic encode/decode đã được viết và kiểm chứng bằng Python
thật trong sandbox trước khi chuyển sang Dart** (điều không thể làm được với
hướng `lc0` cũ, vì sandbox không có Flutter để chạy thử):
- Build `lc0` (bản Linux, chỉ để lấy công cụ `leela2onnx` có sẵn trong mã
  nguồn của chính lc0) → convert cả 9 file Maia sang `.onnx`.
- Dùng `lczero-tools` (thư viện Python tham chiếu, nguồn mở) để tạo dữ liệu
  input/output "đúng" cho nhiều thế cờ khác nhau.
- Chạy thử: mạng Maia dự đoán đúng y hệt các nước mở màn phổ biến nhất của
  con người (1.e4 ~65%, 1.d4 ~21%, ...) — xác nhận toàn bộ pipeline hoạt
  động đúng.
- Viết lại logic encode bằng Python **giống hệt cấu trúc code Dart sẽ viết**
  (cùng vòng lặp, cùng công thức index), so khớp byte-từng-byte với dữ liệu
  tham chiếu ở trên cho nhiều thế cờ (bao gồm cả trường hợp khó: đến lượt
  Đen, có phong cấp, có bắt tốt qua đường, halfmove/fullmove tuỳ ý) — khớp
  tuyệt đối trước khi viết bản Dart thật.
- Trích xuất trực tiếp bảng tra cứu UCI↔index (~7400 dòng) bằng code, không
  chép tay, để không có lỗi đánh máy.

## Kiến trúc

| File | Vai trò |
|---|---|
| `assets/onnx/maia-{1100..1900}.onnx` | 9 mạng Maia đã convert (~3.5MB/file, ~31MB tổng) |
| `assets/onnx/uci_to_idx.json` | Bảng tra UCI→index cho 4 biến thể (trắng/đen × có/không quyền nhập thành) |
| `lib/services/ai/maia/maia_board_encoder.dart` | Bàn cờ + lịch sử → tensor input 112x8x8 |
| `lib/services/ai/maia/maia_move_index.dart` | Load bảng tra cứu, map nước đi hợp lệ → index trong vector policy 1858 chiều |
| `lib/services/ai/maia/maia_position_snapshot.dart` | Kiểu dữ liệu gọn (board+turn+castling+en passant+halfmove) dùng riêng cho encoder, tách khỏi `GameState` đầy đủ |
| `lib/services/ai/maia_onnx_engine.dart` | **Engine chính.** Load model, chạy inference, chọn nước đi, có fallback |

### Định dạng input (112 plane, đã verify)

- 8 bước lịch sử (mới nhất trước) × 13 plane = 104 plane: 6 plane quân "ta" +
  6 plane quân "địch" (thứ tự Tốt,Mã,Tượng,Xe,Hậu,Vua) + 1 plane lặp thế.
  Thiếu lịch sử (đầu game) thì các plane còn lại để 0 — đúng như lc0 làm.
- 8 plane hằng số: quyền nhập thành ta/địch (2 bên), bên đi (0=trắng,
  1=đen), số nước không ăn/không đi tốt (giá trị thô, không chuẩn hoá), toàn
  0, toàn 1.
- **Điểm dễ nhầm nhất**: khi đến lượt Đen, bàn cờ chỉ lật theo **hàng**
  (rank), **cột (file) giữ nguyên** — không phải lật 180 độ như trực giác
  thông thường. Đã verify thực nghiệm bằng nhiều thế cờ đơn giản.
- En passant **không có plane riêng** — không phải thiếu sót, định dạng
  gốc của lc0 (classical 112-plane) đơn giản là không mã hoá thông tin này.
- Lặp thế được tính đơn giản hoá: chỉ so trong 8 nước gần nhất, không phải
  toàn bộ ván (tránh phải giữ bảng transposition suốt ván), đủ dùng cho đa
  số trường hợp thực tế (đi lại 1 quân qua lại).

### Định dạng output

- `/output/policy`: 1858 giá trị. Lọc ra đúng các nước hợp lệ (qua bảng
  UCI→index) rồi softmax **chỉ trên các nước đó** (không softmax cả 1858).
- `/output/wdl`: 3 giá trị (Thắng/Hoà/Thua) — mạng Maia dùng đầu ra WDL,
  không phải 1 giá trị scalar đơn như nhiều tài liệu cũ mô tả (đã verify
  bằng `lc0 describenet`), hiện chưa dùng đến số này (chỉ chọn theo policy).

### Chọn nước đi

Mặc định **sample có trọng số** theo đúng phân phối xác suất mà Maia dự
đoán (giống cách con người ở mức Elo đó thực sự chơi — có thể chọn nước tốt
nhất theo policy, nhưng cũng có thể chọn nước phổ biến thứ 2, 3...), không
lấy máy móc nước cao nhất mỗi lần. Riêng mức "Chuyên gia" hạ "nhiệt độ"
(temperature) sampling xuống 0.3 để nhất quán chọn nước top hơn — bù một
phần cho việc không còn search sâu như bản `lc0` cũ (xem hạn chế bên dưới).

## Hạn chế đã biết

- **Không còn mức "search sâu hơn"**: bản `lc0` cũ có thể tăng `nodes` để
  tìm sâu hơn ở mức "Chuyên gia". Chạy ONNX thuần không có search — mức
  "Chuyên gia" hiện chỉ là mạng 1900 Elo với nhiệt độ sampling thấp hơn,
  không phải deep search thật. Muốn có mức thật sự mạnh (engine-strength,
  không phải "giống người") sau này, hướng khả thi là viết thêm 1 minimax
  nông (2-3 ply) dùng đầu ra WDL để đánh giá lá, đặt lên trên policy Maia để
  sắp thứ tự nước đi — chưa làm trong bản này.
- Lặp thế chỉ xét trong cửa sổ 8 nước gần nhất (xem trên).
- En passant không được mạng "nhìn thấy" trực tiếp (hạn chế của chính định
  dạng input classical của lc0, không phải lỗi của bản port này).

## Việc bạn cần tự làm

Mình không có Flutter SDK trong sandbox nên chưa build/chạy thử được bước
cuối (chỉ verify được phần thuật toán encode bằng Python, không verify được
việc gọi gói `flutter_onnxruntime` thật trong Flutter). Cần bạn:

1. `flutter pub get` trong `game/`.
2. `flutter analyze` — bắt các lỗi type mình không tự kiểm tra bằng mắt được.
3. Build & chạy thử trên thiết bị/emulator Android thật, đánh vài nước ở
   từng độ khó, xem AI có phản hồi hợp lý không (nước đi có vẻ hợp lý cho
   mức Elo đã chọn, không bị đứng).
4. Nếu AI vẫn có vấn đề, vào Settings → xem log debug, tái hiện lỗi, gửi log
   lại — do dùng gói mới (được verify publisher, cập nhật gần đây, MIT
   license) nên hy vọng ổn định hơn nhiều so với bản `lc0` trước, nhưng vẫn
   nên kiểm tra thực tế.

## Ghi chú giấy phép

`flutter_onnxruntime` là MIT license — không còn vướng nghĩa vụ GPL-3.0 như
gói `leela_chess_zero` cũ. Các file `.onnx` (chuyển từ trọng số Maia gốc)
vẫn theo giấy phép gốc của Maia Chess (xem repo CSSLab/maia-chess).
