# -*- coding: utf-8 -*-
"""
Colab-ready self-play + training pipeline for the ChessAI project.

Usage in Colab:
  1. Mount Google Drive.
  2. Upload or clone this repository into Drive (recommended path: /content/drive/MyDrive/ChessAI).
  3. Run this script from the repository root or pass the project root as an argument.

This script will:
  - download LibTorch into /content/libtorch if needed,
  - build the C++ self-play engine,
  - run self-play generations and save binary logs to Drive,
  - train a policy network on the generated data,
  - trace and save a TorchScript model as model_gen_<generation>.pt,
  - overwrite best_model_traced.pt for the next engine generation.
"""

import argparse
import csv
import gc
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tarfile
import threading
import time
from pathlib import Path
from typing import List, Optional, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset

from model_artifacts import validate_training_inputs, write_model_output_summary

try:
    import pandas as pd
except Exception:  # pragma: no cover
    pd = None

try:
    import matplotlib.pyplot as plt
except Exception:  # pragma: no cover
    plt = None


def seed_everything(seed: int = 42) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


def configure_torch_runtime(device: torch.device) -> None:
    if device.type == "cuda":
        # set_device requires an explicit index; fall back to 0 when none is given
        cuda_index = device.index if device.index is not None else 0
        torch.cuda.set_device(cuda_index)
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        torch.backends.cudnn.benchmark = True
        torch.set_float32_matmul_precision("high")
        torch.cuda.empty_cache()
    else:
        torch.set_num_threads(max(1, min(8, os.cpu_count() or 1)))


class ResidualBlock(nn.Module):
    """Residual block with optional Dropout2d for regularization."""

    def __init__(self, channels: int = 128, dropout: float = 0.1) -> None:
        super().__init__()
        self.conv1   = nn.Conv2d(channels, channels, kernel_size=3, padding=1, bias=False)
        self.bn1     = nn.BatchNorm2d(channels)
        self.dropout = nn.Dropout2d(p=dropout)
        self.conv2   = nn.Conv2d(channels, channels, kernel_size=3, padding=1, bias=False)
        self.bn2     = nn.BatchNorm2d(channels)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        residual = x
        out = F.relu(self.bn1(self.conv1(x)))
        out = self.dropout(out)
        out = self.bn2(self.conv2(out))
        return F.relu(out + residual)


class ChessPolicyNet(nn.Module):
    """ResNet-style policy + value network.

    Input: [B, 20, 8, 8] — 20 planes:
      0-11 : piece positions (W_P…W_K, B_P…B_K)
      12   : turn (1.0 = white to move)
      13-16: castling rights WK/WQ/BK/BQ
      17   : en passant square
      18   : rep1 (position repeated ≥1×)
      19   : rep2 (position repeated ≥2×)

    Policy head: 4096 logits (from_sq×64 + to_sq) + 192 underpromotion = 4288 total
    Value head : scalar ∈ [-1, 1] — larger capacity (32ch → 256 → 64 → 1)
    """

    NUM_INPUT_PLANES = 20
    NUM_ACTIONS      = 4288   # 4096 normal + 192 underpromotion (N/B/R × 64 to-squares)

    def __init__(self, num_blocks: int = 6, channels: int = 128,
                 policy_channels: int = 32, dropout: float = 0.1) -> None:
        super().__init__()
        # ── Trunk ────────────────────────────────────────────────────────────
        self.conv_init = nn.Conv2d(self.NUM_INPUT_PLANES, channels,
                                   kernel_size=3, padding=1, bias=False)
        self.bn_init   = nn.BatchNorm2d(channels)
        self.blocks    = nn.ModuleList(
            [ResidualBlock(channels, dropout) for _ in range(num_blocks)]
        )

        # ── Policy head ───────────────────────────────────────────────────────
        self.policy_conv = nn.Conv2d(channels, policy_channels, kernel_size=1, bias=False)
        self.policy_bn   = nn.BatchNorm2d(policy_channels)
        self.fc          = nn.Linear(policy_channels * 8 * 8, self.NUM_ACTIONS)

        # ── Value head (larger capacity: 32ch → 256 → 64 → 1) ────────────────
        self.value_conv  = nn.Conv2d(channels, 32, kernel_size=1, bias=False)
        self.value_bn    = nn.BatchNorm2d(32)
        self.value_fc1   = nn.Linear(32 * 64, 256)
        self.value_fc2   = nn.Linear(256, 64)
        self.value_head  = nn.Linear(64, 1)

    def forward(self, x: torch.Tensor):
        out = F.relu(self.bn_init(self.conv_init(x)))
        for block in self.blocks:
            out = block(out)

        # Policy head
        p = F.relu(self.policy_bn(self.policy_conv(out)))
        policy = self.fc(torch.flatten(p, start_dim=1))

        # Value head
        v = F.relu(self.value_bn(self.value_conv(out)))
        v = F.relu(self.value_fc1(torch.flatten(v, start_dim=1)))
        v = F.relu(self.value_fc2(v))
        value = torch.tanh(self.value_head(v))

        return policy, value


def should_log_output(line: str) -> bool:
    text = line.strip()
    if not text:
        return False
    # Only log errors and warnings from subprocesses
    lowered = text.lower()
    return any(token in lowered for token in ("error", "failed", "exception", "traceback", "warning"))


def run(
    cmd: List[str],
    cwd: Optional[str] = None,
    env: Optional[dict] = None,
    check: bool = True,
    heartbeat_seconds: Optional[float] = None,
    timeout: Optional[float] = None,
) -> subprocess.CompletedProcess:
    # Silent execution, only log errors
    process = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    output_chunks: List[str] = []
    stop_event = threading.Event()
    start_time = time.time()

    def stream_output() -> None:
        assert process.stdout is not None
        for line in process.stdout:
            output_chunks.append(line)
            if should_log_output(line):
                print(line, end="", flush=True)
        process.stdout.close()

    def heartbeat() -> None:
        while not stop_event.is_set():
            # Silent heartbeat
            if stop_event.wait(heartbeat_seconds or 1.0):
                break

    stream_thread = threading.Thread(target=stream_output, daemon=True)
    stream_thread.start()
    heartbeat_thread: Optional[threading.Thread] = None
    if heartbeat_seconds is not None and heartbeat_seconds > 0:
        heartbeat_thread = threading.Thread(target=heartbeat, daemon=True)
        heartbeat_thread.start()

    try:
        returncode = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        stop_event.set()
        stream_thread.join(timeout=5)
        output = "".join(output_chunks)
        raise RuntimeError(
            f"[ERROR] Subprocess timed out after {timeout:.0f}s and was killed: {' '.join(cmd)}\n"
            f"Last output:\n{output[-2000:]}"
        )

    stop_event.set()
    stream_thread.join(timeout=5)
    if heartbeat_thread is not None:
        heartbeat_thread.join(timeout=1)

    output = "".join(output_chunks)
    if check and returncode != 0:
        raise subprocess.CalledProcessError(returncode, cmd, output=output, stderr="")
    return subprocess.CompletedProcess(cmd, returncode, output, "")


def ensure_drive_mount() -> None:
    if os.path.exists('/content/drive'):
        return
    try:
        from google.colab import drive  # type: ignore
        drive.mount('/content/drive', force_remount=False)
    except Exception:  # pragma: no cover
        pass


def detect_runtime_defaults() -> Tuple[Path, Path, Path]:
    cwd = Path.cwd().resolve()
    candidates = []
    if (cwd / 'AI' / 'src' / 'colab_selfplay_pipeline.py').exists():
        candidates.append(cwd)
    if (cwd / 'src' / 'colab_selfplay_pipeline.py').exists():
        candidates.append(cwd)
    if (Path('/kaggle/working/ChessAI') / 'AI' / 'src' / 'colab_selfplay_pipeline.py').exists():
        candidates.append(Path('/kaggle/working/ChessAI'))
    if (Path('/kaggle/working/ChessAI') / 'src' / 'colab_selfplay_pipeline.py').exists():
        candidates.append(Path('/kaggle/working/ChessAI'))
    if (Path('/content/ChessAI') / 'AI' / 'src' / 'colab_selfplay_pipeline.py').exists():
        candidates.append(Path('/content/ChessAI'))
    if (Path('/content/ChessAI') / 'src' / 'colab_selfplay_pipeline.py').exists():
        candidates.append(Path('/content/ChessAI'))

    project_root = cwd
    for candidate in candidates:
        if candidate.exists() and candidate.is_dir():
            project_root = candidate
            break

    if os.path.exists('/kaggle/working'):
        workdir = Path('/kaggle/working/chess_selfplay')
        output_root = Path('/kaggle/working/chess_outputs')
    elif os.path.exists('/content/drive'):
        workdir = Path('/content/chess_selfplay')
        output_root = Path('/content/drive/MyDrive/ChessAI')
    else:
        workdir = project_root / 'chess_selfplay'
        output_root = project_root / 'outputs'

    return project_root, workdir, output_root


def prepare_project_root(project_root: Path, archive_path: Optional[Path] = None) -> Path:
    project_root = project_root.expanduser().resolve()
    if project_root.exists() and project_root.is_dir():
        return project_root

    if archive_path is not None:
        archive_path = archive_path.expanduser().resolve()
        if archive_path.exists() and archive_path.suffixes[-2:] == ['.tar', '.gz']:
            print(f"[Archive] Extracting {archive_path} -> {project_root.parent}")
            project_root.parent.mkdir(parents=True, exist_ok=True)
            with tarfile.open(archive_path, 'r:gz') as tar:
                tar.extractall(project_root.parent)
            if project_root.exists() and project_root.is_dir():
                return project_root

            for child in project_root.parent.iterdir():
                if child.is_dir() and (child / 'engine' / 'CMakeLists.txt').exists():
                    return child

    raise FileNotFoundError(f"Project directory not found: {project_root}")


def select_libtorch_url() -> str:
    """Pick a CUDA-capable LibTorch archive URL matching the installed PyTorch + CUDA."""
    cuda_ver = torch.version.cuda or ""
    torch_ver = torch.__version__.split("+", 1)[0]

    # Try to use the exact installed version first; fall back to the nearest
    # known-good release for versions that didn't have a libtorch binary.
    known_versions = {
        "2.6": "2.6.0",
        "2.5": "2.5.1",
        "2.4": "2.4.1",
        "2.3": "2.3.1",
    }
    # Extract major.minor prefix (e.g. "2.12" from "2.12.1")
    parts = torch_ver.split(".")
    major_minor = f"{parts[0]}.{parts[1]}" if len(parts) >= 2 else torch_ver
    if major_minor in known_versions:
        base_version = known_versions[major_minor]
    elif major_minor >= "2.7":
        # For torch 2.7+ use the exact version string (PyTorch publishes libtorch
        # for each release using the same x.y.z naming convention).
        base_version = torch_ver
    else:
        base_version = "2.3.1"

    # Pick the CUDA tag that matches the installed CUDA runtime.
    if cuda_ver.startswith("12.4"):
        cu_tag = "cu124"
    elif cuda_ver.startswith("12.1") or cuda_ver.startswith("12."):
        cu_tag = "cu121"
    elif cuda_ver.startswith("11.8") or cuda_ver.startswith("11."):
        cu_tag = "cu118"
    else:
        cu_tag = None

    if cu_tag:
        return (
            f"https://download.pytorch.org/libtorch/{cu_tag}/"
            f"libtorch-cxx11-abi-shared-with-deps-{base_version}%2B{cu_tag}.zip"
        )
    return (
        f"https://download.pytorch.org/libtorch/cpu/"
        f"libtorch-cxx11-abi-shared-with-deps-{base_version}%2Bcpu.zip"
    )


def setup_libtorch(project_root: Path, workdir: Path) -> Path:
    """Return the cmake prefix path for LibTorch (CUDA-capable when possible).

    Priority:
    1. System / venv PyTorch – already installed with CUDA, zero download cost.
       torch.utils.cmake_prefix_path points to the cmake directory that
       find_package(Torch) reads (contains Torch/TorchConfig.cmake).
    2. Previously-downloaded CUDA / CPU LibTorch in workdir.
    3. Fresh download of CUDA (or CPU-fallback) LibTorch.
    """
    # ── Priority 1: use the system/venv PyTorch cmake path ───────────────────
    try:
        cmake_prefix = Path(torch.utils.cmake_prefix_path)
        if (cmake_prefix / "Torch" / "TorchConfig.cmake").exists():
            stale = workdir / "libtorch"
            if stale.exists():
                stale_cudart = list(stale.glob("lib/libcudart*"))
                if not stale_cudart:
                    shutil.rmtree(stale, ignore_errors=True)
            return cmake_prefix
    except Exception:
        pass

    # ── Priority 2: reuse previously-downloaded LibTorch ─────────────────────
    libtorch_dir = workdir / "libtorch"
    # cmake prefix for a downloaded LibTorch lives one level deeper
    downloaded_cmake = libtorch_dir / "share" / "cmake"
    torch_config = downloaded_cmake / "Torch" / "TorchConfig.cmake"
    if torch_config.exists():
        has_cuda_lib = bool(list(libtorch_dir.glob("lib/libcudart*")))
        if not has_cuda_lib and torch.cuda.is_available():
            shutil.rmtree(libtorch_dir, ignore_errors=True)
        else:
            return downloaded_cmake

    # ── Priority 3: fresh download ────────────────────────────────────────────
    if libtorch_dir.exists():
        shutil.rmtree(libtorch_dir, ignore_errors=True)
    url = select_libtorch_url()
    archive = workdir / "libtorch.zip"
    run(["wget", "-q", url, "-O", str(archive)])
    run(["unzip", "-q", str(archive), "-d", str(workdir)])
    if not torch_config.exists():
        raise RuntimeError("LibTorch unzip did not create the expected directory.")
    return downloaded_cmake


def build_engine(project_root: Path, libtorch_dir: Path, build_base: Optional[Path] = None) -> Path:
    import hashlib

    engine_dir = project_root / "AI" / "engine"
    if not (engine_dir / "CMakeLists.txt").exists():
        engine_dir = project_root / "engine"

    # build_dir phải nằm ngoài project_root để tránh ghi vào /kaggle/input (read-only).
    # Ưu tiên: build_base được truyền vào > /kaggle/working > engine_dir/build (local dev)
    if build_base is not None:
        build_dir = Path(build_base) / "engine_build"
    elif os.path.exists("/kaggle/working"):
        build_dir = Path("/kaggle/working/chess_engine_build")
    else:
        build_dir = engine_dir / "build"

    binary = build_dir / "selfplay"

    # Tính hash của tất cả source files quan trọng
    hash_files = [
        engine_dir / "CMakeLists.txt",
        engine_dir / "selfplay.cpp",
        engine_dir / "mcts.cpp",
        engine_dir / "mcts.hpp",
        engine_dir / "ChessEnv.cpp",
    ]
    hasher = hashlib.sha256()
    for f in hash_files:
        if f.exists():
            hasher.update(f.read_bytes())
    # Cũng hash libtorch path để rebuild nếu libtorch thay đổi
    hasher.update(str(libtorch_dir).encode())
    current_hash = hasher.hexdigest()

    hash_file = build_dir / ".build_hash"
    if binary.exists() and hash_file.exists():
        try:
            cached_hash = hash_file.read_text().strip()
            if cached_hash == current_hash:
                return binary
        except Exception:
            pass
    if build_dir.exists():
        shutil.rmtree(build_dir, ignore_errors=True)
    build_dir.mkdir(parents=True, exist_ok=True)

    cmake_cmd = [
        "cmake",
        "-S",
        str(engine_dir),
        "-B",
        str(build_dir),
        "-DCMAKE_PREFIX_PATH=" + str(libtorch_dir),
    ]
    run(cmake_cmd, cwd=str(project_root))
    run(["cmake", "--build", str(build_dir), "-j2"], cwd=str(project_root))

    if not binary.exists():
        raise RuntimeError("[ERROR] The self-play binary was not built successfully.")

    hash_file.write_text(current_hash)
    return binary


def load_generation_samples(path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    if not path.exists():
        raise FileNotFoundError(path)
    data = np.fromfile(path, dtype=np.float32)
    if data.size == 0:
        raise ValueError(f"No samples found in {path}")
    # NEW: SelfPlaySample = 1280 state floats + 1 move_idx + 1 value = 1282 floats/sample
    # (OLD was 768+1+1=770 with 12 planes; now 1280+1+1=1282 with 20 planes)
    SAMPLE_SIZE = ChessPolicyNet.NUM_INPUT_PLANES * 64 + 2  # 1282
    if data.size % SAMPLE_SIZE != 0:
        # Backward compat: try old 770-float format (12 planes)
        if data.size % 770 == 0:
            print(f"[DataLoad] {path.name}: old 12-plane format detected — upgrading on-the-fly")
            samples_old = data.reshape(-1, 770)
            states_old  = samples_old[:, :768].astype(np.float32).reshape(-1, 12, 8, 8)
            moves  = samples_old[:, 768].astype(np.int64)
            values = samples_old[:, 769].astype(np.float32)
            # Pad old 12-plane states to 20 planes (fill extra 8 planes with zeros)
            n = states_old.shape[0]
            states = np.zeros((n, ChessPolicyNet.NUM_INPUT_PLANES, 8, 8), dtype=np.float32)
            states[:, :12] = states_old
            # Note: no turn/castling/EP/rep info from old format — zeros is safe (neutral)
        else:
            raise ValueError(f"Unexpected sample size in {path}: {data.size} (not divisible by {SAMPLE_SIZE} or 770)")
    else:
        samples = data.reshape(-1, SAMPLE_SIZE)
        states  = samples[:, :1280].astype(np.float32).reshape(-1, ChessPolicyNet.NUM_INPUT_PLANES, 8, 8)
        moves   = samples[:, 1280].astype(np.int64)
        values  = samples[:, 1281].astype(np.float32)

    draws = (values == 0.0)
    n_draws = int(draws.sum())
    # ── FIX: Remove random noise on draws (was: ±0.25 uniform noise) ─────
    # BUG (cũ): values[draws] += random.uniform(-0.25, 0.25)
    # → noise ngẫu nhiên không dạy được gì, chỉ làm nhiễu tín hiệu value.
    #
    # FIX mới: Dùng material balance từ state để tạo draw value có nghĩa.
    # Mỗi draw position có material balance riêng:
    #   - Nếu bên hiện tại đang có lợi vật chất: draw tệ → value âm nhẹ
    #   - Nếu bên hiện tại đang bất lợi: draw tốt → value dương nhẹ
    #   - Nếu cân bằng: draw trung lập → value gần 0
    # Hệ số scale nhỏ (0.15) để không làm value head lệch quá nhiều.
    if n_draws > 0:
        # ── CRITICAL FIX: Draw penalty để MCTS không seek draw ──────────────
        # Vấn đề gốc: draw=0 → MCTS coi hòa = neutral → safe draw > risky win
        # → model học cách chủ động kéo hòa (repetition, stalemate bẫy) thay vì cố thắng.
        #
        # FIX Bug 5: DRAW_VALUE -0.15 quá nhỏ — tăng lên -0.4 để khuyến khích thắng mạnh hơn.
        # -0.15 chỉ bằng 7.5% của range [-1,1], model không đủ động lực tránh draw.
        # -0.4 phù hợp: đủ mạnh để MCTS avoid draw nhưng không cực đoan.
        # Phải khớp với DRAW_VALUE trong kaggle_pgn_train_notebook.
        BASE_DRAW_PENALTY = -0.4        #   win=+1.0,  draw=-0.4,  loss=-1.0
        # → MCTS tìm win thay vì settle for draw
        # → Khi đang thua: vẫn prefer draw (-0.4 > -1.0) — hợp lý
        # → Khi đang thắng: không chấp nhận draw (-0.4 < +1.0) — MCTS tiếp tục tấn công
        # BUG đã fix: dòng "BASE_DRAW_PENALTY = -0.15" từng nằm ở đây, ghi đè ngay lên
        # giá trị -0.4 phía trên → toàn bộ "Fix Bug 5" ở trên chưa bao giờ có hiệu lực,
        # và DRAW_VALUE giữa pipeline này với notebook bị lệch nhau (-0.15 vs -0.4).

        PIECE_WEIGHTS = np.array([1.0, 3.0, 3.2, 5.1, 9.0,  # P N B R Q (White)
                                  1.0, 3.0, 3.2, 5.1, 9.0,  # P N B R Q (Black)
                                  0.0, 0.0], dtype=np.float32)  # Kings
        draw_states = states[draws]  # [n_draws, 20, 8, 8]
        # Planes 0-11 are piece occupancy (White P/N/B/R/Q/K, Black P/N/B/R/Q/K).
        # Planes 12-19 are auxiliary (turn, castling, EP, repetition) — not material.
        # Must slice [:, :12] BEFORE reshaping: states now have 20 planes (1280
        # floats/pos), so reshape(n, 12, 64) would try to squeeze 1280→768 → ValueError.
        piece_counts = draw_states[:, :12].reshape(n_draws, 12, 64).sum(axis=2)  # [n_draws, 12]
        white_mat = (piece_counts[:, :5] * PIECE_WEIGHTS[:5]).sum(axis=1)
        black_mat = (piece_counts[:, 6:11] * PIECE_WEIGHTS[6:11]).sum(axis=1)
        material_adv = white_mat - black_mat  # positive = White better

        # Material adj nhỏ (±0.05) chỉ để phân biệt "hòa khi đang thắng" vs "hòa khi đang thua"
        # Không dùng sideToMove vì plane encoding không reliable → dùng magnitude nhỏ
        MAX_MAT = 39.0
        material_adj = -np.clip(material_adv / MAX_MAT, -1.0, 1.0) * 0.05
        # Tổng: draw_value ∈ [-0.45, -0.35] — luôn âm, nhỏ hơn loss (-1.0) nhưng lớn hơn loss
        values[draws] = (BASE_DRAW_PENALTY + material_adj).astype(np.float32)
        # ────────────────────────────────────────────────────────────────────

    values = np.clip(values, -1.0, 1.0)
    # ─────────────────────────────────────────────────────────────────────
    return states, moves, values


def load_replay_buffer(paths: List[Path]) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
    all_states = []
    all_moves = []
    all_values = []
    for path in paths:
        if not path.exists():
            continue
        try:
            states, moves, values = load_generation_samples(path)
        except Exception as exc:  # pragma: no cover
            print(f"[ERROR] load_replay_buffer: skipping {path}: {exc}")
            continue
        all_states.append(states)
        all_moves.append(moves)
        all_values.append(values)
    if not all_states:
        raise RuntimeError("No generation data found for training.")
    states_np = np.concatenate(all_states, axis=0)
    moves_np = np.concatenate(all_moves, axis=0)
    values_np = np.concatenate(all_values, axis=0)
    MAX_REPLAY_SAMPLES = 200_000
    if states_np.shape[0] > MAX_REPLAY_SAMPLES:
        states_np = states_np[-MAX_REPLAY_SAMPLES:]
        moves_np = moves_np[-MAX_REPLAY_SAMPLES:]
        values_np = values_np[-MAX_REPLAY_SAMPLES:]
    x = torch.from_numpy(states_np)
    y = torch.from_numpy(moves_np)
    v = torch.from_numpy(values_np)
    return x, y, v


def validate_torchscript_model(model_path: Path, device: torch.device) -> None:
    if not model_path.exists():
        raise FileNotFoundError(f"TorchScript model not found: {model_path}")
    try:
        scripted = torch.jit.load(str(model_path), map_location=device)
        with torch.no_grad():
            dummy = torch.randn(1, ChessPolicyNet.NUM_INPUT_PLANES, 8, 8, device=device)
            out = scripted(dummy)
            if isinstance(out, (tuple, list)):
                policy_out, value_out = out[0], out[1]
                assert policy_out.shape[-1] == ChessPolicyNet.NUM_ACTIONS, f"policy shape sai: {policy_out.shape}"
                assert value_out.shape[-1] == 1, f"value shape sai: {value_out.shape}"
            else:
                assert out.shape[-1] == 4096, f"output shape sai: {out.shape}"
    except Exception as exc:  # pragma: no cover
        raise RuntimeError(f"TorchScript model validation failed for {model_path}: {exc}") from exc


def select_replay_files(drive_root: Path, generation_file: Path, min_samples: int = 20000, max_files: int = 10) -> List[Path]:
    candidates = sorted(
        [path for path in drive_root.glob("selfplay_gen_*.bin") if path.exists()],
        key=lambda path: int(path.stem.split("_")[-1]),
    )
    if generation_file.exists() and generation_file not in candidates:
        candidates.append(generation_file)
    candidates = sorted(candidates, key=lambda path: int(path.stem.split("_")[-1]))

    replay_files: List[Path] = []
    total_samples = 0
    for path in reversed(candidates):
        try:
            states, _, _ = load_generation_samples(path)
        except Exception as exc:  # pragma: no cover
            print(f"[Pipeline] skipping replay {path}: {exc}")
            continue

        replay_files.append(path)
        total_samples += int(states.shape[0])
        if total_samples >= min_samples or len(replay_files) >= max_files:
            break

    if not replay_files:
        replay_files = [generation_file]
    return replay_files


def train_policy_model(
    model: nn.Module,
    states: torch.Tensor,
    moves: torch.Tensor,
    values: torch.Tensor,
    lr: float = 1e-3,
    batch_size: int = 256,
    epochs: int = 3,
    device: torch.device = torch.device("cpu"),
    checkpoint_path: Optional[Path] = None,
    latest_checkpoint_path: Optional[Path] = None,
    metrics_output_dir: Optional[Path] = None,
    patience: int = 5,  # tăng từ 2 → 5 để không dừng quá sớm
    min_delta: float = 1e-4,
    start_epoch: int = 0,
) -> Tuple[nn.Module, dict]:
    model = model.to(device)
    model.train()

    effective_batch_size = max(16, batch_size)
    if device.type == "cuda":
        gpu_mem_gb = torch.cuda.get_device_properties(0).total_memory / (1024 ** 3)
        max_batch = 256 if gpu_mem_gb < 24 else 512
        effective_batch_size = min(effective_batch_size, max_batch)

    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    scaler = torch.cuda.amp.GradScaler(enabled=(device.type == "cuda"))
    history = {"epochs": []}
    best_loss = float("inf")
    patience_counter = 0

    # ── Oversample decisive + material-adjusted draw samples ─────────────
    # FIX: Dùng weighted random sampling thay vì repeat() cứng nhắc.
    # - repeat() tạo exact duplicates → model overfit trên số ít decisive samples.
    # - weighted sampling: decisive samples được chọn thường xuyên hơn nhưng
    #   không 100% giống nhau (shuffle tự nhiên của DataLoader giải quyết order).
    # - Cap factor ở 8x để tránh bùng nổ RAM khi decisive cực hiếm.
    # ── Fix: threshold 0.5 để chỉ bắt actual wins/losses (±1.0), không nhầm draws ──
    # Sau khi fix draw penalty, draw values ∈ [-0.20, -0.10].
    # threshold 0.05 (cũ) sẽ bắt nhầm draws làm "decisive" → oversample không hiệu quả.
    # threshold 0.5 chỉ bắt actual wins (≈+1) và losses (≈-1).
    decisive_mask = (values.abs() > 0.5)
    n_decisive = int(decisive_mask.sum().item())
    total_samples = len(values)
    draw_rate = 1.0 - n_decisive / max(1, total_samples)

    # ── Dynamic oversample: giảm xuống vì đã có weighted loss (100x) ───────
    # Trước đây: oversample 15x để cân bằng 99.6% draws
    # Sau fix weighted loss: chỉ cần oversample nhẹ (3-5x) để tăng sample diversity
    # Weighted loss (100x) đã handle imbalance → không cần oversample quá nhiều
    decisive_rate = n_decisive / max(1, total_samples)
    if decisive_rate < 0.03:
        oversample_factor = 5  # Was: 15 (giảm xuống vì có weighted loss)
    elif decisive_rate < 0.06:
        oversample_factor = 4
    elif decisive_rate < 0.10:
        oversample_factor = 3
    elif decisive_rate < 0.20:
        oversample_factor = 2
    else:
        oversample_factor = 2

    if n_decisive > 0:
        idx = decisive_mask.nonzero(as_tuple=True)[0]
        perm = torch.randperm(len(idx))
        idx_shuffled = idx[perm]
        rep_idx = idx_shuffled.repeat(oversample_factor)
        states  = torch.cat([states,  states[rep_idx]])
        moves   = torch.cat([moves,   moves[rep_idx]])
        values  = torch.cat([values,  values[rep_idx]])
    # ────────────────────────────────────────────────────────────────────────
    # ──────────────────────────────────────────────────────────────────────

    for epoch in range(start_epoch, epochs):
        running_loss = 0.0
        running_policy_loss = 0.0
        running_value_loss = 0.0
        total_batches = 0
        current_batch_size = effective_batch_size
        while True:
            try:
                dataset = TensorDataset(states, moves, values)
                loader = DataLoader(
                    dataset,
                    batch_size=current_batch_size,
                    shuffle=True,
                    num_workers=0,
                    pin_memory=(device.type == "cuda"),
                )
                break
            except RuntimeError as exc:  # pragma: no cover
                if device.type == "cuda" and "out of memory" in str(exc).lower():
                    current_batch_size = max(16, current_batch_size // 2)
                    continue
                raise

        for xb, yb, vb in loader:
            xb = xb.to(device, non_blocking=True)
            yb = yb.to(device, non_blocking=True)
            vb = vb.to(device, non_blocking=True).unsqueeze(1) if vb.dim() == 1 else vb.to(device, non_blocking=True)
            optimizer.zero_grad(set_to_none=True)
            if device.type == "cuda":
                with torch.autocast(device_type="cuda", dtype=torch.float16):
                    policy_logits, value_pred = model(xb)
                    policy_loss = F.cross_entropy(policy_logits, yb.long())
                    
                    # ── CRITICAL FIX: Weighted Value Loss ────────────────────────────
                    # ROOT CAUSE của value=0.0000: 99.6% draws với target ∈ [-0.45, -0.35]
                    # → model học predict -0.4 cho mọi position → MSE ≈ 0.0001 (perfect on draws)
                    # → 0.4% decisive samples (±1.0) bị overwhelm và ignored
                    #
                    # FIX: Weight decisive samples 100x để force model học win/loss signals
                    # is_decisive: |value| > 0.5 → catches ±1.0 (wins/losses), not draws (-0.4)
                    is_decisive = (vb.abs() > 0.5)
                    sample_weights = torch.where(is_decisive,
                                                torch.tensor(100.0, device=device, dtype=torch.float16),
                                                torch.tensor(1.0, device=device, dtype=torch.float16))
                    value_loss = (sample_weights * (value_pred - vb.float()) ** 2).mean()
                    # ─────────────────────────────────────────────────────────────────
                    
                    # Dynamic value_weight: tăng khi draw_rate cao
                    _vw = 3.0 if draw_rate > 0.85 else (2.0 if draw_rate > 0.70 else 1.5)
                    loss = policy_loss + _vw * value_loss
                scaler.scale(loss).backward()
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                scaler.step(optimizer)
                scaler.update()
            else:
                policy_logits, value_pred = model(xb)
                policy_loss = F.cross_entropy(policy_logits, yb.long())
                
                # ── CRITICAL FIX: Weighted Value Loss (CPU path) ─────────────────
                is_decisive = (vb.abs() > 0.5)
                sample_weights = torch.where(is_decisive,
                                            torch.tensor(100.0, device=device),
                                            torch.tensor(1.0, device=device))
                value_loss = (sample_weights * (value_pred - vb.float()) ** 2).mean()
                # ─────────────────────────────────────────────────────────────────
                
                _vw = 3.0 if draw_rate > 0.85 else (2.0 if draw_rate > 0.70 else 1.5)
                loss = policy_loss + _vw * value_loss
                loss.backward()
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                optimizer.step()
            running_loss += float(loss.item())
            running_policy_loss += float(policy_loss.item())
            running_value_loss += float(value_loss.item())
            total_batches += 1

        avg_loss = running_loss / max(1, total_batches)
        avg_policy_loss = running_policy_loss / max(1, total_batches)
        avg_value_loss = running_value_loss / max(1, total_batches)

        ckpt_payload = {
            "model_state": model.state_dict(),
            "optimizer_state": optimizer.state_dict(),
            "epoch": epoch + 1,
            "loss": avg_loss,
            "policy_loss": avg_policy_loss,
            "value_loss": avg_value_loss,
        }
        if checkpoint_path is not None:
            checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
            torch.save(ckpt_payload, checkpoint_path)
        if latest_checkpoint_path is not None:
            latest_checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
            torch.save(ckpt_payload, latest_checkpoint_path)

        if device.type == "cuda":
            torch.cuda.empty_cache()
        gc.collect()
        _vw = 3.0 if draw_rate > 0.85 else (2.0 if draw_rate > 0.70 else 1.5)
        print(f"[Train] epoch={epoch + 1}/{epochs} | policy={avg_policy_loss:.4f} value={avg_value_loss:.4f} "
              f"| vw={_vw:.1f} draw={draw_rate:.1%}")
        history["epochs"].append({"epoch": epoch + 1, "loss": avg_loss, "policy_loss": avg_policy_loss, "value_loss": avg_value_loss})
        if metrics_output_dir is not None:
            export_training_metrics(history, metrics_output_dir)

        if best_loss - avg_loss > min_delta:
            best_loss = avg_loss
            patience_counter = 0
        else:
            patience_counter += 1
            if patience_counter >= patience:
                break

    model.eval()
    return model, history


def save_traced_model(model: nn.Module, path: Path, device: torch.device) -> None:
    model = model.to(device)
    model.eval()
    # Đảm bảo tất cả BN layer ở eval mode (running stats, không dùng batch stats)
    for m in model.modules():
        if isinstance(m, torch.nn.BatchNorm2d):
            m.eval()
    # Must use NUM_INPUT_PLANES=20 channels — conv_init expects exactly 20.
    # A 12-channel dummy here would make torch.jit.trace throw at the first
    # conv layer (weight shape [128, 20, 3, 3] vs input [1, 12, 8, 8]).
    dummy = torch.randn(1, ChessPolicyNet.NUM_INPUT_PLANES, 8, 8, device=device)
    with torch.no_grad():
        traced = torch.jit.trace(model, dummy)
        # Verify output is tuple (policy, value)
        out = traced(dummy)
        if not isinstance(out, (tuple, list)):
            raise RuntimeError(
                f"[ERROR] Traced model phải output tuple (policy, value), got {type(out)}. "
                "Kiểm tra ChessPolicyNet.forward() có return 2 tensors không."
            )
    traced.save(str(path))


def save_training_summary(history: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(history, handle, indent=2)


def export_training_metrics(history: dict, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    if not history.get("epochs"):
        return

    epochs = [entry["epoch"] for entry in history["epochs"]]
    losses = [entry["loss"] for entry in history["epochs"]]
    policy_losses = [entry.get("policy_loss", entry.get("loss", 0.0)) for entry in history["epochs"]]
    value_losses = [entry.get("value_loss", 0.0) for entry in history["epochs"]]

    csv_path = output_dir / "training_metrics.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["epoch", "loss", "policy_loss", "value_loss"])
        writer.writeheader()
        for epoch, loss, policy_loss, value_loss in zip(epochs, losses, policy_losses, value_losses):
            writer.writerow({"epoch": epoch, "loss": loss, "policy_loss": policy_loss, "value_loss": value_loss})

    if plt is not None:
        fig, axes = plt.subplots(1, 3, figsize=(15, 4))
        axes[0].plot(epochs, losses, marker="o")
        axes[0].set_title("Total Loss")
        axes[0].set_xlabel("Epoch")
        axes[0].set_ylabel("Loss")
        axes[1].plot(epochs, policy_losses, marker="o", color="blue")
        axes[1].set_title("Policy Loss")
        axes[1].set_xlabel("Epoch")
        axes[1].set_ylabel("Loss")
        axes[2].plot(epochs, value_losses, marker="o", color="orange")
        axes[2].set_title("Value Loss")
        axes[2].set_xlabel("Epoch")
        axes[2].set_ylabel("Loss")
        fig.tight_layout()
        fig.savefig(output_dir / "training_metrics.png", dpi=150)
        plt.close(fig)


def export_generation_comparison(summaries: List[dict], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / "generation_comparison.csv"
    md_path = output_dir / "generation_comparison.md"

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "generation",
                "model_path",
                "replay_path",
                "samples",
                "epochs_trained",
                "final_loss",
                "final_value_loss",
            ],
        )
        writer.writeheader()
        for summary in summaries:
            writer.writerow(summary)

    with md_path.open("w", encoding="utf-8") as handle:
        handle.write("# Generation comparison\n\n")
        handle.write("| Generation | Samples | Epochs | Final Loss | Final Value Loss |\n")
        handle.write("| --- | ---: | ---: | ---: | ---: |\n")
        for summary in summaries:
            handle.write(
                f"| {summary['generation']} | {summary['samples']} | {summary['epochs_trained']} | {summary['final_loss']:.4f} | {summary['final_value_loss']:.4f} |\n"
            )


def find_latest_checkpoint(drive_root: Path, checkpoint_dir: Optional[Path] = None) -> Optional[Path]:
    candidates: List[Path] = []
    if checkpoint_dir is not None:
        candidates.extend([checkpoint_dir / "latest_checkpoint.pt", checkpoint_dir / "checkpoint_latest.pt"])
    candidates.extend(
        sorted(
            drive_root.glob("checkpoint_gen_*.pt"),
            key=lambda p: int(p.stem.split("_")[-1].split(".")[0]),
        )
    )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def detect_resume_generation(drive_root: Path) -> int:
    generations: List[int] = []
    for pattern in ["model_gen_*.pt", "checkpoint_gen_*.pt", "training_summary_gen_*.json"]:
        for path in drive_root.glob(pattern):
            match = re.search(r"(\d+)", path.name)
            if match is not None:
                generations.append(int(match.group(1)))
    return max(generations) if generations else 0


def load_resume_state(output_dir: Path) -> Optional[dict]:
    state_path = output_dir / "resume_state.json"
    if not state_path.exists():
        return None
    try:
        with state_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return None


def save_resume_state(
    output_dir: Path,
    generation: int,
    checkpoint_path: Optional[Path],
    best_model_path: Path,
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    state_path = output_dir / "resume_state.json"
    payload = {
        "generation": generation,
        "checkpoint_path": str(checkpoint_path) if checkpoint_path is not None else None,
        "best_model_path": str(best_model_path),
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with state_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
    return state_path


def reinit_value_head(model: nn.Module) -> None:
    """Reinitialize value head weights to break draw collapse.

    ROOT CAUSE của draw collapse:
    Train.py (PGN training) dùng `value_target = zeros`, khiến value head
    học output ~0 cho mọi vị trí. MCTS không phân biệt được thắng/thua,
    dẫn đến tỉ lệ hòa >95%.

    Hàm này reinit value head về Xavier normal để thoát khỏi attractor "mọi
    thứ là hòa". Chỉ gọi 1 lần khi phát hiện value head bị collapse.
    """
    value_modules = {name: m for name, m in model.named_modules()
                     if 'value' in name and isinstance(m, (nn.Linear, nn.Conv2d))}
    if not value_modules:
        print("[Model] Không tìm thấy value head modules để reinit")
        return
    for name, module in value_modules.items():
        nn.init.xavier_normal_(module.weight, gain=0.5)
        if module.bias is not None:
            nn.init.zeros_(module.bias)


def detect_value_collapse(model: nn.Module, device: torch.device, threshold: float = 0.05) -> bool:
    """Kiểm tra value head có bị collapse về 0 không.

    Chạy 128 vị trí ngẫu nhiên. Nếu std(value_outputs) < threshold
    → value head bị collapse, cần reinit.
    """
    model.eval()
    with torch.no_grad():
        # Must match NUM_INPUT_PLANES=20; 12-channel input throws at conv_init.
        dummy = torch.randn(128, ChessPolicyNet.NUM_INPUT_PLANES, 8, 8, device=device)
        _, values = model(dummy)
        val_std = values.std().item()
        val_mean = values.abs().mean().item()
    model.train()
    is_collapsed = (val_std < threshold) and (val_mean < threshold)
    return is_collapsed


def load_checkpoint(model: nn.Module, checkpoint_path: Path, device: torch.device) -> Tuple[nn.Module, dict]:
    checkpoint = torch.load(checkpoint_path, map_location=device)
    state_dict = checkpoint["model_state"]
    # Backward compat: checkpoint cũ (chỉ có policy head) → load strict=False
    has_value_head = any(k.startswith("value_") for k in state_dict.keys())
    if not has_value_head:
        model.load_state_dict(state_dict, strict=False)
        reinit_value_head(model)
    else:
        model.load_state_dict(state_dict)
        model.to(device)
        if detect_value_collapse(model, device):
            reinit_value_head(model)
    model.to(device)
    return model, checkpoint


def _is_writable(p: Path) -> bool:
    """Kiểm tra path có thể ghi không (tránh crash khi project_root là /kaggle/input)."""
    try:
        p.mkdir(parents=True, exist_ok=True)
        test = p / ".write_test"
        test.touch()
        test.unlink()
        return True
    except (OSError, PermissionError):
        return False


def publish_latest_model(gen_model_path: Path, best_model_path: Path, project_root: Path) -> None:
    best_model_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gen_model_path, best_model_path)

    project_model_path = project_root / "AI" / "data" / "best_model_traced.pt"
    if _is_writable(project_model_path.parent):
        shutil.copy2(gen_model_path, project_model_path)


def _run_single_selfplay_worker(
    binary: Path,
    model_path: Path,
    output_path: Path,
    simulations: int,
    games: int,
    log_every: int,
    temperature_moves: int,
    seed: int,
    project_root: Path,
    heartbeat_seconds: float,
    selfplay_timeout: float,
    env: Optional[dict] = None,
    log_prefix: str = "",
    resign_thresh: float = -1.0,
    min_resign_ply: int = 20,
) -> None:
    """Run one selfplay worker subprocess (blocking)."""
    cmd = [
        str(binary),
        "--model_path",   str(model_path),
        "--simulations",  str(simulations),
        "--games",        str(games),
        "--log_every",    str(log_every),
        "--output",       str(output_path),
        "--temperature_moves", str(temperature_moves),
        "--seed",         str(seed),
        "--resign_thresh",     str(resign_thresh),
        "--min_resign_ply",    str(min_resign_ply),
    ]
    run(cmd, cwd=str(project_root), env=env,
        heartbeat_seconds=heartbeat_seconds, timeout=selfplay_timeout)


def run_generation(
    binary: Path,
    generation: int,
    project_root: Path,
    workdir: Path,
    drive_root: Path,
    best_model_path: Path,
    simulations: int,
    games: int,
    log_every: int = 50,
    heartbeat_seconds: float = 30.0,
    selfplay_timeout: float = 8 * 3600.0,
    temperature_moves: int = 50,  # FIX: 30→50 tăng exploration
    resign_thresh: float = -1.0,
    min_resign_ply: int = 20,
) -> Path:
    local_generation_file = workdir / f"selfplay_gen_{generation}.bin"
    drive_generation_file = drive_root / f"selfplay_gen_{generation}.bin"

    # ── Detect available GPUs ─────────────────────────────────────────────────
    num_gpus = torch.cuda.device_count() if torch.cuda.is_available() else 0
    num_workers = max(1, min(num_gpus, 2))

    start_ts = time.time()

    if num_workers == 1:
        # ── Single worker (CPU or single-GPU) ────────────────────────────────
        env = os.environ.copy()
        if num_gpus >= 1:
            env["CUDA_VISIBLE_DEVICES"] = "0"
        try:
            _run_single_selfplay_worker(
                binary=binary, model_path=best_model_path,
                output_path=local_generation_file,
                simulations=simulations, games=games, log_every=log_every,
                temperature_moves=temperature_moves, seed=42,
                project_root=project_root,
                heartbeat_seconds=heartbeat_seconds, selfplay_timeout=selfplay_timeout,
                env=env,
                resign_thresh=resign_thresh,
                min_resign_ply=min_resign_ply,
            )
        except subprocess.CalledProcessError as exc:
            print(f"[ERROR] Self-play binary exited with code {exc.returncode}")
            print(f"[ERROR] Output: {exc.output[-2000:] if exc.output else '(none)'}")
            raise RuntimeError(f"[ERROR] Self-play failed for generation {generation}") from exc

    else:
        # ── Parallel workers: split games across GPUs ─────────────────────────
        # Distribute games evenly; last worker picks up any remainder
        base_games   = games // num_workers
        extra_games  = games % num_workers
        games_split  = [base_games + (1 if i < extra_games else 0) for i in range(num_workers)]

        partial_files = [
            workdir / f"selfplay_gen_{generation}_worker{i}.bin"
            for i in range(num_workers)
        ]

        errors: List[Exception] = []
        errors_lock = threading.Lock()

        def run_worker(worker_idx: int) -> None:
            env = os.environ.copy()
            env["CUDA_VISIBLE_DEVICES"] = str(worker_idx)
            try:
                _run_single_selfplay_worker(
                    binary=binary, model_path=best_model_path,
                    output_path=partial_files[worker_idx],
                    simulations=simulations, games=games_split[worker_idx],
                    log_every=max(1, log_every // num_workers),
                    temperature_moves=temperature_moves,
                    seed=42 + worker_idx * 1000,
                    project_root=project_root,
                    heartbeat_seconds=heartbeat_seconds,
                    selfplay_timeout=selfplay_timeout,
                    env=env,
                    log_prefix=f"[GPU{worker_idx}]",
                    resign_thresh=resign_thresh,
                    min_resign_ply=min_resign_ply,
                )
            except Exception as exc:
                with errors_lock:
                    errors.append(exc)

        worker_threads = [
            threading.Thread(target=run_worker, args=(i,), daemon=False)
            for i in range(num_workers)
        ]
        for t in worker_threads:
            t.start()
        for t in worker_threads:
            t.join()

        if errors:
            raise RuntimeError(
                f"[ERROR] {len(errors)} self-play worker(s) failed for generation {generation}: "
                + str(errors[0])
            )

        with open(local_generation_file, "wb") as outf:
            for pf in partial_files:
                if pf.exists() and pf.stat().st_size > 0:
                    outf.write(pf.read_bytes())
                    pf.unlink(missing_ok=True)

    elapsed = time.time() - start_ts

    if not local_generation_file.exists() or local_generation_file.stat().st_size == 0:
        raise RuntimeError(f"[ERROR] Self-play output file missing/empty: {local_generation_file}")

    print(f"[Progress] Gen {generation}: self-play done ({elapsed:.1f}s, {local_generation_file.stat().st_size/1e6:.1f}MB)", flush=True)

    shutil.copy2(local_generation_file, drive_generation_file)
    return drive_generation_file


def iter_model_candidate_paths(project_root: Path, drive_root: Path) -> List[Path]:
    project_root = project_root.expanduser().resolve()
    drive_root = drive_root.expanduser().resolve()

    search_roots = []
    seen: set[Path] = set()
    for candidate_root in [project_root, project_root / "AI", project_root.parent if project_root.name == "AI" else None]:
        if candidate_root is None:
            continue
        candidate_root = candidate_root.expanduser().resolve()
        if candidate_root not in seen:
            search_roots.append(candidate_root)
            seen.add(candidate_root)

    candidates: List[Path] = [drive_root / "best_model_traced.pt"]
    for root in search_roots:
        candidates.extend(
            [
                root / "data" / "best_model_traced.pt",
                root / "AI" / "data" / "best_model_traced.pt",
                root / "best_model_traced.pt",
                root / "models" / "best_model_traced.pt",
            ]
        )
    return candidates


def resolve_best_model_path(project_root: Path, drive_root: Path, explicit_path: Optional[Path] = None) -> Path:
    if explicit_path is not None:
        explicit_path = explicit_path.expanduser().resolve()
        return explicit_path

    candidates = iter_model_candidate_paths(project_root, drive_root)
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def run_pipeline(
    project_root: Path,
    workdir: Path,
    drive_root: Path,
    initial_model_path: Optional[Path] = None,
    best_model_path_override: Optional[Path] = None,
    simulations: int = 800,
    games_per_generation: int = 500,
    epochs: int = 3,
    batch_size: int = 256,
    learning_rate: float = 1e-3,
    max_generations: Optional[int] = None,
    infinite: bool = True,
    log_every_games: int = 50,
    heartbeat_seconds: float = 30.0,
    resume: bool = False,
    checkpoint_dir: Optional[Path] = None,
    temperature_moves: int = 50,  # FIX: 30→50 tăng exploration
    resign_thresh: float = -1.0,
    min_resign_ply: int = 20,
    max_runtime_seconds: Optional[float] = None,  # Time limit when max_generations is None
) -> None:
    workdir.mkdir(parents=True, exist_ok=True)
    drive_root.mkdir(parents=True, exist_ok=True)
    if checkpoint_dir is None:
        checkpoint_dir = drive_root / "checkpoints"
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    seed_everything()
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    configure_torch_runtime(device)

    best_model_path = resolve_best_model_path(project_root, drive_root, best_model_path_override)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    if initial_model_path is not None and initial_model_path.exists():
        shutil.copy2(initial_model_path, best_model_path)
    elif not best_model_path.exists():
        for fallback_model_path in iter_model_candidate_paths(project_root, drive_root):
            if fallback_model_path.exists():
                shutil.copy2(fallback_model_path, best_model_path)
                break

    model = ChessPolicyNet()
    if best_model_path.exists():
        try:
            script_module = torch.jit.load(str(best_model_path), map_location="cpu")
            old_sd = script_module.state_dict()
            new_sd = model.state_dict()
            matched = {k: v for k, v in old_sd.items() if k in new_sd and new_sd[k].shape == v.shape}
            model.load_state_dict(matched, strict=False)
        except Exception:
            pass
    else:
        save_traced_model(model, best_model_path, device)

    model.to(device)
    if detect_value_collapse(model, device):
        reinit_value_head(model)
        save_traced_model(model, best_model_path, device)

    validate_torchscript_model(best_model_path, device)

    latest_checkpoint = find_latest_checkpoint(drive_root, checkpoint_dir)
    if latest_checkpoint is not None:
        try:
            model, checkpoint = load_checkpoint(model, latest_checkpoint, device)
            save_traced_model(model, best_model_path, device)
        except Exception:
            pass

    engine_binary = build_engine(project_root, setup_libtorch(project_root, workdir), build_base=workdir)

    generation = 0
    generation_summaries: List[dict] = []
    resume_state = load_resume_state(drive_root) if resume else None
    resume_generation = 0
    if resume_state is not None:
        resume_generation = int(resume_state.get("generation", 0))
    elif resume:
        resume_generation = detect_resume_generation(drive_root)

    pipeline_start_time = time.time()

    generation = resume_generation
    while True:
        generation += 1
        if resume and generation <= resume_generation:
            continue
        
        if max_generations is None and max_runtime_seconds is not None:
            elapsed = time.time() - pipeline_start_time
            if elapsed >= max_runtime_seconds:
                print(f"\n⏱️  Time limit reached ({elapsed / 3600:.1f}h) — stopped after gen {generation - 1}")
                
                break
            remaining = max_runtime_seconds - elapsed
            print(f"\n===== Generation {generation} | {remaining / 3600:.1f}h remaining =====")
        else:
            print(f"\n===== Generation {generation}/{max_generations if max_generations is not None else '∞'} =====")

        generation_file = run_generation(
            binary=engine_binary,
            generation=generation,
            project_root=project_root,
            workdir=workdir,
            drive_root=drive_root,
            best_model_path=best_model_path,
            simulations=simulations,
            games=games_per_generation,
            log_every=log_every_games,
            heartbeat_seconds=heartbeat_seconds,
            temperature_moves=temperature_moves,
            resign_thresh=resign_thresh,
            min_resign_ply=min_resign_ply,
        )

        validate_torchscript_model(best_model_path, device)
        replay_files = select_replay_files(drive_root, generation_file)
        states, moves, values = load_replay_buffer(replay_files)
        validate_training_inputs(states.tolist(), moves.tolist(), values.tolist())
        print(f"[Progress] Gen {generation}: training {states.shape[0]} samples")
        checkpoint_path = drive_root / f"checkpoint_gen_{generation}.pt"
        latest_checkpoint_path = checkpoint_dir / "latest_checkpoint.pt"
        metrics_output_dir = drive_root / f"metrics_gen_{generation}"
        model, history = train_policy_model(
            model=model,
            states=states,
            moves=moves,
            values=values,
            lr=learning_rate,
            batch_size=batch_size,
            epochs=epochs,
            device=device,
            checkpoint_path=checkpoint_path,
            latest_checkpoint_path=latest_checkpoint_path,
            metrics_output_dir=metrics_output_dir,
            patience=2,
            min_delta=1e-4,
        )

        gen_model_path = drive_root / f"model_gen_{generation}.pt"
        save_traced_model(model, gen_model_path, device)
        save_training_summary(history, drive_root / f"training_summary_gen_{generation}.json")
        export_training_metrics(history, metrics_output_dir)
        publish_latest_model(gen_model_path, best_model_path, project_root)

        write_model_output_summary(
            output_dir=drive_root,
            generation=generation,
            artifacts={
                "generation_model": gen_model_path,
                "best_model": best_model_path,
                "project_model": project_root / "AI" / "data" / "best_model_traced.pt",
            },
            replay_path=generation_file,
            checkpoint_path=checkpoint_path,
        )

        generation_summary = {
            "generation": generation,
            "model_path": str(gen_model_path),
            "replay_path": str(generation_file),
            "samples": int(states.shape[0]),
            "epochs_trained": len(history.get("epochs", [])),
            "final_loss": history["epochs"][-1]["loss"] if history.get("epochs") else float("nan"),
            "final_value_loss": history["epochs"][-1].get("value_loss", 0.0) if history.get("epochs") else 0.0,
        }
        generation_summaries.append(generation_summary)
        export_generation_comparison(generation_summaries, drive_root)
        save_resume_state(drive_root, generation, checkpoint_path, best_model_path)
        print(f"[Progress] Gen {generation}: complete\n")

        if max_generations is not None and generation >= max_generations:
            print(f"\n✓ Completed {generation} generations")
            break
        if not infinite and max_generations is None:
            print(f"\n✓ Completed 1 generation")
            break

    print(f"\n✓ Pipeline complete — final model: {best_model_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Colab/Kaggle self-play training loop")
    parser.add_argument("--project_root", type=str, default="")
    parser.add_argument("--drive_root", type=str, default="")
    parser.add_argument("--archive_path", type=str, default="")
    parser.add_argument("--workdir", type=str, default="")
    parser.add_argument("--initial_model", type=str, default="")
    parser.add_argument("--best_model_path", type=str, default="", help="Explicit path for the best model file")
    parser.add_argument("--simulations", type=int, default=800)
    parser.add_argument("--games", type=int, default=500)
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch_size", type=int, default=256)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--max_generations", type=int, default=None)
    parser.add_argument("--log_every", type=int, default=50, help="Print self-play progress every N games")
    parser.add_argument("--heartbeat", type=float, default=60.0, help="Print a heartbeat every N seconds while the engine is running")
    parser.add_argument("--checkpoint_dir", type=str, default="", help="Directory for persistent checkpoints and resume state")
    parser.add_argument("--resume", action="store_true", help="Resume from the latest completed generation in the output directory")
    parser.add_argument("--temperature_moves", type=int, default=50, help="Number of opening moves to use temperature=1 sampling (default 50; was 30)")
    parser.add_argument("--resign_thresh", type=float, default=-1.0,
                        help="Resign when MCTS root Q < this value for current player. -1.0 = disabled (default).")
    parser.add_argument("--min_resign_ply", type=int, default=20,
                        help="Do not resign before this half-move count (default 20).")
    parser.add_argument("--max_runtime_hours", type=float, default=None,
                        help="Maximum runtime in hours when max_generations is None (default: None = no limit)")
    parser.add_argument("--no_infinite", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ensure_drive_mount()

    default_project_root, default_workdir, default_output_root = detect_runtime_defaults()
    project_root = Path(args.project_root).expanduser().resolve() if args.project_root else default_project_root
    workdir = Path(args.workdir).expanduser().resolve() if args.workdir else default_workdir
    drive_root = Path(args.drive_root).expanduser().resolve() if args.drive_root else default_output_root
    initial_model_path = Path(args.initial_model).expanduser().resolve() if args.initial_model else None
    best_model_path_override = Path(args.best_model_path).expanduser().resolve() if args.best_model_path else None
    archive_path = Path(args.archive_path).expanduser().resolve() if args.archive_path else None
    checkpoint_dir = Path(args.checkpoint_dir).expanduser().resolve() if args.checkpoint_dir else drive_root / "checkpoints"

    project_root = prepare_project_root(project_root, archive_path)

    max_runtime_seconds = None
    if args.max_runtime_hours is not None:
        max_runtime_seconds = args.max_runtime_hours * 3600
    
    run_pipeline(
        project_root=project_root,
        workdir=workdir,
        drive_root=drive_root,
        initial_model_path=initial_model_path,
        best_model_path_override=best_model_path_override,
        simulations=args.simulations,
        games_per_generation=args.games,
        epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.lr,
        max_generations=args.max_generations,
        infinite=not args.no_infinite,
        log_every_games=args.log_every,
        heartbeat_seconds=args.heartbeat,
        resume=args.resume,
        checkpoint_dir=checkpoint_dir,
        temperature_moves=args.temperature_moves,
        resign_thresh=args.resign_thresh,
        min_resign_ply=args.min_resign_ply,
        max_runtime_seconds=max_runtime_seconds,
    )


if __name__ == "__main__":
    main()