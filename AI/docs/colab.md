# 5. Chạy self-play và vòng lặp tự học trên Colab

## Mục tiêu

Chạy toàn bộ pipeline trên Google Colab với GPU T4:

- cài LibTorch,
- build engine C++,
- chạy self-play,
- huấn luyện mô hình,
- export model mới và cập nhật best model.

## File chính

- [src/colab_selfplay_pipeline.py](../src/colab_selfplay_pipeline.py)
- [COLAB_SELFPLAY.md](../COLAB_SELFPLAY.md)

## Bước 1: Chuẩn bị archive tối thiểu

Chỉ đóng gói những phần cần thiết vào tar.gz:

```bash
mkdir -p /tmp/chessai_minimal/ChessAI/data /tmp/chessai_minimal/ChessAI/src
cp -r engine /tmp/chessai_minimal/ChessAI/
rm -rf /tmp/chessai_minimal/ChessAI/engine/libtorch
cp data/best_model_traced.pt /tmp/chessai_minimal/ChessAI/data/
cp src/colab_selfplay_pipeline.py /tmp/chessai_minimal/ChessAI/src/

tar -czf chessai_project.tar.gz -C /tmp/chessai_minimal ChessAI
```

## Bước 2: Upload và giải nén trên Colab

```python
from google.colab import drive
import os

drive.mount('/content/drive', force_remount=False)

archive_path = '/content/drive/MyDrive/chessai_project.tar.gz'
project_root = '/content/ChessAI'

if not os.path.exists(project_root):
    !tar -xzf "{archive_path}" -C /content
```

## Bước 3: Cài LibTorch và build engine

```python
!python -V
!apt-get update -qq
!apt-get install -y -qq build-essential cmake
!pip install -q numpy torch==2.2.2

!rm -rf /content/libtorch /content/libtorch.zip
!wget -q "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip" -O /content/libtorch.zip
!unzip -q /content/libtorch.zip -d /content
!test -f /content/libtorch/share/cmake/Torch/TorchConfig.cmake && echo "LibTorch OK" || echo "LibTorch path check failed"
```

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
result = subprocess.run(
    ['cmake', '-S', '.', '-B', 'build', '-DCMAKE_PREFIX_PATH=' + libtorch_root, '-DTorch_DIR=' + torch_dir],
    capture_output=True,
    text=True,
)
print(result.stdout)
print(result.stderr)
if result.returncode != 0:
    raise SystemExit(result.returncode)

result = subprocess.run(['cmake', '--build', 'build', '-j2'], capture_output=True, text=True)
print(result.stdout)
print(result.stderr)
if result.returncode != 0:
    raise SystemExit(result.returncode)
```

## Bước 4: Chạy pipeline

```python
import os
os.chdir('/content/ChessAI')
!python src/colab_selfplay_pipeline.py --project_root /content/ChessAI --drive_root /content/drive/MyDrive/ChessAI --archive_path /content/drive/MyDrive/chessai_project.tar.gz --workdir /content/chess_selfplay --simulations 800 --games 500 --epochs 3 --batch_size 256 --lr 0.001 --max_generations 3 --no_infinite
```

## Output

Kết quả sẽ được lưu trực tiếp vào Drive:

- best_model_traced.pt
- model_gen_1.pt, model_gen_2.pt, ...
- selfplay_gen_1.bin, selfplay_gen_2.bin, ...

## Cách hoạt động của vòng tự học

Pipeline sẽ tự động:

1. dùng model hiện tại từ Drive hoặc từ data/best_model_traced.pt để chạy self-play;
2. sau mỗi generation, train lại mạng và lưu model mới thành model_gen_N.pt;
3. copy model mới sang best_model_traced.pt trên Drive;
4. đồng bộ model mới cũng vào thư mục project data/best_model_traced.pt để vòng tiếp theo dùng ngay.

Bạn có thể kiểm tra bằng các dòng sau sau khi chạy xong một generation:

```python
import os
print(os.path.exists('/content/drive/MyDrive/ChessAI/best_model_traced.pt'))
print(os.path.exists('/content/ChessAI/data/best_model_traced.pt'))
```