# 6. Cấu trúc dự án và file quan trọng

## Cấu trúc thư mục

```text
ChessAI/
├── data/
│   └── best_model_traced.pt
├── docs/
│   ├── README.md
│   ├── data.md
│   ├── data-processing.md
│   ├── training.md
│   ├── conversion.md
│   ├── colab.md
│   └── project-structure.md
├── engine/
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── mcts.cpp
│   ├── mcts.hpp
│   ├── ChessEnv.cpp
│   └── selfplay.cpp
├── src/
│   ├── Train.py
│   ├── Convert_pth_to_pt.py
│   ├── extract_chess_pgn.cpp
│   └── colab_selfplay_pipeline.py
└── README_Train.md
```

## Archive tối thiểu cho Colab

Để tạo file tar.gz nhỏ gọn, chỉ cần đóng gói các mục sau:

- [data/best_model_traced.pt](../data/best_model_traced.pt)
- thư mục [engine](../engine) (không bao gồm libtorch)
- [src/colab_selfplay_pipeline.py](../src/colab_selfplay_pipeline.py)

LibTorch được tải sau trong Colab bằng shell.

## Vai trò từng phần

- [data](../data): chứa file model TorchScript dùng cho engine và self-play.
- [engine](../engine): engine C++ dùng MCTS và self-play.
- [src](../src): script Python huấn luyện, export model và pipeline Colab.
- [docs](./): tài liệu quy trình dự án.
