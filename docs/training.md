# 3. Huấn luyện mô hình PyTorch

## Mục tiêu

Huấn luyện mạng dự đoán nước đi từ trạng thái bàn cờ.

## File chính

- [src/Train.py](../src/Train.py)

## Cấu hình đề xuất

- Learning rate: 0.001
- Batch size: 256
- Epochs: 3–5
- Device: CUDA nếu có, nếu không thì CPU

## Bước 1: Chuẩn bị dữ liệu

Đảm bảo file dataset đã sẵn sàng và đường dẫn trong script đúng.

## Bước 2: Chạy training

Bạn có thể dùng script [src/Train.py](../src/Train.py) hoặc pipeline Colab [src/colab_selfplay_pipeline.py](../src/colab_selfplay_pipeline.py).

## Bước 3: Kiểm tra kết quả

Sau mỗi epoch, nên xem:

- loss có giảm ổn định không,
- accuracy có hợp lý không,
- có dấu hiệu overfitting không.

## Output

Sau khi training, bạn sẽ có file checkpoint hoặc trọng số mô hình.
