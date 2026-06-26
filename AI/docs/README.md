# ChessAI Documentation Hub

Tài liệu này là trung tâm cho toàn bộ quy trình dự án ChessAI, từ việc thu thập và xử lý dữ liệu PGN, huấn luyện mạng, chuyển đổi sang TorchScript, cho đến chạy vòng lặp tự học trên Colab.

## Mục lục

1. [Tìm và chuẩn bị dữ liệu](./data.md)
2. [Xử lý dữ liệu PGN sang định dạng trainable](./data-processing.md)
3. [Huấn luyện mô hình PyTorch](./training.md)
4. [Chuyển đổi .pth sang .pt (TorchScript)](./conversion.md)
5. [Chạy self-play và vòng lặp tự học trên Colab](./colab.md)
6. [Cấu trúc dự án và file quan trọng](./project-structure.md)

## Luồng tổng thể

```text
PGN / dữ liệu gốc
  → trích xuất và chuyển thành binary samples
  → huấn luyện mô hình PyTorch
  → export sang TorchScript (.pt)
  → dùng trong engine C++ / MCTS / self-play
  → lặp lại vòng tự học trên Colab
```

## Archive tối thiểu cho Colab

Để giữ file tar.gz nhỏ và dễ upload, archive nên chỉ gồm:

- [data/best_model_traced.pt](../data/best_model_traced.pt)
- thư mục [engine](../engine) (không gồm libtorch)
- [src/colab_selfplay_pipeline.py](../src/colab_selfplay_pipeline.py)

LibTorch sẽ được tải trực tiếp trong Colab ở bước cài đặt.

## File chính trong dự án

- [src/Train.py](../src/Train.py)
- [src/Convert_pth_to_pt.py](../src/Convert_pth_to_pt.py)
- [src/extract_chess_pgn.cpp](../src/extract_chess_pgn.cpp)
- [src/colab_selfplay_pipeline.py](../src/colab_selfplay_pipeline.py)
- [engine/selfplay.cpp](../engine/selfplay.cpp)
- [engine/CMakeLists.txt](../engine/CMakeLists.txt)
