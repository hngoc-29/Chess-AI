# 2. Xử lý dữ liệu PGN sang định dạng trainable

## Mục tiêu

Chuyển dữ liệu PGN thành dữ liệu mẫu có thể dùng cho mô hình học nước đi.

## Công cụ chính

- [src/extract_chess_pgn.cpp](../src/extract_chess_pgn.cpp): trích xuất dữ liệu từ file PGN sang định dạng binary.
- [src/Train.py](../src/Train.py): đọc dataset binary và chuẩn bị batch cho training.

## Quy trình

1. Chạy chương trình trích xuất dữ liệu từ PGN.
2. Tạo file binary chứa các sample bàn cờ và label nước đi.
3. Đảm bảo layout đúng:
   - 12 planes × 64 ô = 768 bytes
   - label nước đi = 8 bytes
4. Dùng [src/Train.py](../src/Train.py) để đọc dữ liệu và tạo DataLoader.

## Lưu ý quan trọng

- Label phải tương ứng với trạng thái bàn cờ trước nước đi.
- Không để nước đi hiện tại lộ vào input.
- Nếu dữ liệu bị lệch hoặc lặp lại, training sẽ bị overfit.

## Kết quả mong đợi

Sau bước này, bạn sẽ có file `.bin` hoặc dữ liệu tương ứng để đưa vào training.
