# 1. Tìm và chuẩn bị dữ liệu

## Mục tiêu

Chuẩn bị dữ liệu PGN hoặc dữ liệu đã được trích xuất để huấn luyện mô hình ChessAI.

## Nguồn dữ liệu đề xuất

- File PGN từ Lichess hoặc các kho dữ liệu cờ vua công khai
- File `.pgn` hoặc `.pgn.gz`
- Có thể dùng các file như:
  - [data/lichess_elite_2025-10.pgn](../data/lichess_elite_2025-10.pgn)
  - [data/lichess_elite_2025-11.pgn](../data/lichess_elite_2025-11.pgn)

## Bước 1: Đặt file vào đúng vị trí

Đặt dữ liệu vào thư mục [data](../data):

```text
data/
  lichess_elite_2025-10.pgn
  lichess_elite_2025-11.pgn
```

## Bước 2: Kiểm tra dữ liệu

Trước khi xử lý, nên kiểm tra:

- file có tồn tại không,
- có lỗi encoding không,
- số lượng ván cờ có đủ không,
- có game bị trống hoặc lỗi không.

## Bước 3: Chuẩn bị cho quá trình xử lý

Nếu bạn muốn dùng trên Colab, có thể nén toàn bộ dự án thành tar.gz rồi upload lên Drive theo hướng dẫn ở [colab.md](./colab.md).

## Gợi ý lưu trữ trên Drive

Bạn có thể lưu dữ liệu vào một thư mục như:

```text
/content/drive/MyDrive/ChessAI/data/
```
