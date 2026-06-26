# Hướng dẫn chạy dự án ChessAI trên Colab từ archive tối thiểu

Tài liệu này cập nhật cho workflow hiện tại của dự án: bạn chỉ cần đóng gói một phần tối thiểu vào file tar.gz, upload lên Google Drive, rồi giải nén trên Colab. Mục tiêu là giữ archive nhỏ gọn và để LibTorch tải sau trong Colab.

## 1. Cấu trúc archive tối thiểu mong đợi

Sau khi giải nén, thư mục gốc phải có dạng:

```text
ChessAI/
├── engine/
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── mcts.cpp
│   ├── mcts.hpp
│   ├── ChessEnv.cpp
│   └── selfplay.cpp
├── src/
│   └── colab_selfplay_pipeline.py
└── data/
    └── best_model_traced.pt
```

Điều này rất quan trọng vì script Colab sẽ tìm đường dẫn `engine/CMakeLists.txt` và `data/best_model_traced.pt` sau khi giải nén.

## 2. Tạo archive tối thiểu trên máy local

Chạy các lệnh sau trên máy của bạn:

```bash
mkdir -p /tmp/chessai_minimal/ChessAI/data /tmp/chessai_minimal/ChessAI/src
cp -r engine /tmp/chessai_minimal/ChessAI/
rm -rf /tmp/chessai_minimal/ChessAI/engine/libtorch
cp data/best_model_traced.pt /tmp/chessai_minimal/ChessAI/data/
cp src/colab_selfplay_pipeline.py /tmp/chessai_minimal/ChessAI/src/

tar -czf chessai_project.tar.gz -C /tmp/chessai_minimal ChessAI
```

Lưu ý:

- archive KHÔNG cần chứa thư mục `engine/libtorch`.
- LibTorch sẽ được tải trong Colab bằng shell ở bước 2.
- Nếu bạn muốn dùng thêm [src/Train.py](src/Train.py), hãy copy thêm vào thư mục `src/` trước khi nén.

## 3. Upload lên Google Drive

Đưa file tar.gz vào một vị trí như:

```text
/content/drive/MyDrive/chessai_project.tar.gz
```

## 4. Cell Colab để giải nén

```python
from google.colab import drive
import os

drive.mount('/content/drive', force_remount=False)

archive_path = '/content/drive/MyDrive/chessai_project.tar.gz'
project_root = '/content/ChessAI'

if not os.path.exists(project_root):
    !tar -xzf "{archive_path}" -C /content

if os.path.exists(project_root):
    os.chdir(project_root)
    print('Working directory:', os.getcwd())
else:
    raise FileNotFoundError(f'Không tìm thấy thư mục dự án sau khi giải nén: {project_root}')
```

## 5. Cài đặt môi trường và tải LibTorch trong Colab

```python
!python -V
!nvidia-smi

!apt-get update -qq
!apt-get install -y -qq build-essential cmake

!pip install -q numpy torch==2.2.2

!rm -rf /content/libtorch /content/libtorch.zip
!wget -q "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip" -O /content/libtorch.zip
!unzip -q /content/libtorch.zip -d /content
!test -f /content/libtorch/share/cmake/Torch/TorchConfig.cmake && echo "LibTorch OK" || echo "LibTorch path check failed"
```

## 6. Biên dịch engine C++

```python
import os
import shutil
import subprocess

engine_dir = '/content/ChessAI/engine'
build_dir = os.path.join(engine_dir, 'build')
if os.path.exists(build_dir):
    shutil.rmtree(build_dir)

libtorch_root = '/content/libtorch'
torch_dir = os.path.join(libtorch_root, 'share', 'cmake', 'Torch')
print('Torch dir:', torch_dir)
if not os.path.exists(os.path.join(torch_dir, 'TorchConfig.cmake')):
    raise FileNotFoundError('TorchConfig.cmake not found under /content/libtorch')

os.chdir(engine_dir)
subprocess.run(
    ['cmake', '-S', '.', '-B', 'build', '-DCMAKE_PREFIX_PATH=' + libtorch_root, '-DTorch_DIR=' + torch_dir],
    check=True,
)
subprocess.run(['cmake', '--build', 'build', '-j2'], check=True)
```

## 7. Chạy pipeline tự học tăng cường

```python
import os
os.chdir('/content/ChessAI')
!python src/colab_selfplay_pipeline.py --project_root /content/ChessAI --drive_root /content/drive/MyDrive/ChessAI --archive_path /content/drive/MyDrive/chessai_project.tar.gz --workdir /content/chess_selfplay --simulations 800 --games 500 --epochs 3 --batch_size 256 --lr 0.001 --max_generations 3 --no_infinite
```

## 8. Output sẽ được lưu ở đâu

Sau khi chạy, các file quan trọng sẽ xuất hiện trong thư mục Drive của bạn:

- best_model_traced.pt
- model_gen_1.pt, model_gen_2.pt, ...
- selfplay_gen_1.bin, selfplay_gen_2.bin, ...

## 9. Ghi chú quan trọng

- Nếu bạn đã giải nén rồi thì có thể bỏ tham số `--archive_path`.
- Nếu muốn chạy vòng lặp vô hạn, bỏ `--no_infinite`.
- Nếu Colab bị mất kết nối, file model và dữ liệu self-play vẫn được lưu trực tiếp vào Drive.
