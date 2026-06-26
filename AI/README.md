# ChessAI

ChessAI là một dự án học tăng cường cho cờ vua bằng cách kết hợp:
- engine C++ dùng MCTS và LibTorch để sinh dữ liệu self-play,
- mô hình PyTorch để học policy từ các nước đi,
- pipeline Python để chạy vòng self-play → training → export model.

## Tình trạng hiện tại

- Đã kiểm tra cú pháp các entry point Python chính bằng lệnh:
  - `python3 -m py_compile src/colab_selfplay_pipeline.py src/Train.py`
  - Kết quả: `py-syntax-ok`
- Engine self-play đã build được và có thể chạy qua file binary `engine/build/selfplay`.
- Pipeline hỗ trợ chạy trên Colab/Kaggle với GPU.

## Cấu trúc thư mục chính

- `src/colab_selfplay_pipeline.py` — pipeline chính cho self-play và training.
- `src/Train.py` — script huấn luyện cũ, dùng cho training dữ liệu binary.
- `src/Convert_pth_to_pt.py` — chuyển checkpoint `.pth` sang TorchScript `.pt`.
- `engine/` — engine C++ gồm MCTS, môi trường cờ và self-play.
- `data/` — model và dữ liệu ban đầu.
- `kaggle_train.sh` — launcher cho Kaggle.
- `docs/` — tài liệu hướng dẫn.

## Cài đặt môi trường

### Python

Cài các gói cần thiết:

```bash
pip install numpy torch==2.2.2
```

### C++ / LibTorch

Nếu chạy engine C++, cần cài CMake và LibTorch.
Trên Kaggle, script `kaggle_train.sh` sẽ tự cài và tải LibTorch.

## Chạy training

### Kaggle

```bash
cd /kaggle/working/ChessAI
bash kaggle_train.sh
```

Bạn có thể override tham số như:

```bash
SIMULATIONS=400 GAMES=100 EPOCHS=3 BATCH_SIZE=256 LR=0.001 MAX_GENERATIONS=3 bash kaggle_train.sh
```

### Local / Colab

```bash
python3 src/colab_selfplay_pipeline.py \
  --project_root . \
  --drive_root ./outputs \
  --workdir ./chess_selfplay \
  --simulations 200 \
  --games 50 \
  --epochs 2 \
  --batch_size 128 \
  --lr 0.001 \
  --max_generations 2 \
  --no_infinite
```

## Output

Sau mỗi generation, pipeline sẽ tạo:
- `model_gen_<generation>.pt`
- `best_model_traced.pt`
- `checkpoint_gen_<generation>.pt`
- `training_summary_gen_<generation>.json`
- `metrics_gen_<generation>/training_metrics.csv`
- `metrics_gen_<generation>/training_metrics.png`
- `generation_comparison.csv`
- `generation_comparison.md`

## Ghi chú về code hiện tại

### Điểm tốt
- Pipeline đã hỗ trợ:
  - tự động phát hiện môi trường Kaggle/Colab,
  - validate TorchScript model trước mỗi generation,
  - ghi checkpoint sau mỗi generation,
  - xuất metric CSV/PNG,
  - tạo bảng so sánh giữa các generation.

### Điểm cần lưu ý
- Môi trường cần có PyTorch và NumPy để chạy pipeline Python.
- Mô hình ban đầu được kỳ vọng tại `data/best_model_traced.pt` hoặc đường dẫn được truyền qua `--best_model_path`.
- Engine C++ hiện có một số đường dẫn hard-coded trong một số file; nếu chạy ở máy khác, có thể cần cập nhật lại đường dẫn model.
- Hiện tại pipeline chủ yếu học policy (nước đi), dù giá trị self-play đã được ghi thêm trong engine; việc dùng value target trong loss vẫn còn là điểm có thể cải thiện tiếp.

## Khuyến nghị dùng cho Kaggle

- Chọn GPU T4/T4x2.
- Bắt đầu với cấu hình nhẹ hơn nếu muốn test nhanh:
  - `SIMULATIONS=200`
  - `GAMES=50`
  - `EPOCHS=2`
  - `BATCH_SIZE=128`
  - `MAX_GENERATIONS=2`

## Liên hệ / phát triển tiếp

Nếu muốn cải thiện thêm, các hướng phát triển phù hợp là:
- dùng value target thật trong training,
- tăng chất lượng self-play bằng MCTS sâu hơn,
- thêm resume tự động từ checkpoint tốt hơn,
- chuyển sang mô hình có đầu ra policy+value rõ ràng.
