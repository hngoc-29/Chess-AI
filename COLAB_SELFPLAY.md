# Colab Self-Play Pipeline for ChessAI

Tài liệu này hướng dẫn cách chạy vòng lặp tự huấn luyện trên Google Colab bằng cách đóng gói tối thiểu dự án vào file tar.gz:

- file model: data/best_model_traced.pt
- thư mục engine: toàn bộ source C++ để build binary self-play
- script pipeline: src/colab_selfplay_pipeline.py

> LibTorch sẽ KHÔNG được đưa vào tar.gz. Bạn sẽ tải nó trực tiếp trong Colab bằng shell ở bước 2.

## Bước 0: Tạo archive tối thiểu trên máy local

Chạy lệnh sau trên máy của bạn để tạo file tar.gz chỉ gồm những phần cần thiết:

```bash
mkdir -p /tmp/chessai_minimal/ChessAI/data /tmp/chessai_minimal/ChessAI/src
cp -r engine /tmp/chessai_minimal/ChessAI/
rm -rf /tmp/chessai_minimal/ChessAI/engine/libtorch
cp data/best_model_traced.pt /tmp/chessai_minimal/ChessAI/data/
cp src/colab_selfplay_pipeline.py /tmp/chessai_minimal/ChessAI/src/

tar -czf chessai_project.tar.gz -C /tmp/chessai_minimal ChessAI
```

Sau đó upload file `chessai_project.tar.gz` lên Google Drive, ví dụ:

```text
/content/drive/MyDrive/chessai_project.tar.gz
```

## Cell 1: Kết nối Drive và giải nén archive

```python
from google.colab import drive
import os

drive.mount('/content/drive', force_remount=False)

archive_path = '/content/drive/MyDrive/chessai_project.tar.gz'
project_root = '/content/ChessAI'

if not os.path.exists(project_root):
    !tar -xzf "{archive_path}" -C /content
    print('Extraction completed')

if os.path.exists(project_root):
    os.chdir(project_root)
    print('Working directory:', os.getcwd())
else:
    raise FileNotFoundError(f'Không tìm thấy thư mục dự án sau khi giải nén: {project_root}')
```

## Cell 2: Cài môi trường và tải LibTorch

```bash
!python -V
!nvidia-smi

!apt-get update -qq
!apt-get install -y -qq build-essential cmake

!pip install -q numpy torch==2.2.2

!mkdir -p /content/libtorch
!wget -q https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip -O /content/libtorch.zip
!unzip -q /content/libtorch.zip -d /content

!ls /content/libtorch | head
```

> Nếu Colab báo lỗi về CUDA version, đổi URL `cu121` thành `cu118` hoặc `cu124` tương ứng.

## Cell 3: Kiểm tra cấu trúc thư mục sau khi giải nén

```bash
cd /content/ChessAI
!find . -maxdepth 2 -type d | sort
!ls -R data engine src | head -100
```

Bạn cần thấy:

- data/best_model_traced.pt
- engine/CMakeLists.txt
- src/colab_selfplay_pipeline.py

## Cell 4: Biên dịch engine C++

```bash
cd /content/ChessAI/engine
!cmake -S . -B build -DCMAKE_PREFIX_PATH=/content/libtorch
!cmake --build build -j2

!ls -l build/selfplay build/chess_mcts
```

## Cell 5: Chạy vòng lặp tự học

```bash
cd /content/ChessAI
!python src/colab_selfplay_pipeline.py \
  --project_root /content/ChessAI \
  --drive_root /content/drive/MyDrive/ChessAI \
  --archive_path /content/drive/MyDrive/chessai_project.tar.gz \
  --workdir /content/chess_selfplay \
  --simulations 800 \
  --games 500 \
  --epochs 3 \
  --batch_size 256 \
  --lr 0.001 \
  --max_generations 3 \
  --no_infinite
```

## Cell 6 (tùy chọn): Chạy tiếp thêm một vòng bằng model mới

```bash
cd /content/ChessAI
!python src/colab_selfplay_pipeline.py \
  --project_root /content/ChessAI \
  --drive_root /content/drive/MyDrive/ChessAI \
  --archive_path /content/drive/MyDrive/chessai_project.tar.gz \
  --initial_model /content/drive/MyDrive/ChessAI/best_model_traced.pt \
  --workdir /content/chess_selfplay \
  --simulations 800 \
  --games 500 \
  --epochs 3 \
  --batch_size 256 \
  --lr 0.001 \
  --max_generations 1 \
  --no_infinite
```

## Output lưu vào Drive

Sau khi chạy, các file dưới đây sẽ được lưu trong Drive:

- /content/drive/MyDrive/ChessAI/best_model_traced.pt
- /content/drive/MyDrive/ChessAI/model_gen_1.pt
- /content/drive/MyDrive/ChessAI/model_gen_2.pt
- /content/drive/MyDrive/ChessAI/selfplay_gen_1.bin
- /content/drive/MyDrive/ChessAI/selfplay_gen_2.bin

Nếu cần chạy vòng lặp vô hạn, bỏ tham số `--no_infinite`.
