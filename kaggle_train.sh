#!/usr/bin/env bash
set -euo pipefail

export PYTHONPATH=""
export PYTHONNOUSERSITE=1
export PYTHONDONTWRITEBYTECODE=1
export PIP_NO_CACHE_DIR=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
export MPLBACKEND=Agg

PROJECT_ROOT="${PROJECT_ROOT:-}"
WORKDIR="${WORKDIR:-/kaggle/working/chess_selfplay}"
OUTPUT_ROOT="${OUTPUT_ROOT:-/kaggle/working/chess_outputs}"
CHECKPOINT_DIR="${CHECKPOINT_DIR:-$OUTPUT_ROOT/checkpoints}"
REPO_URL="${REPO_URL:-https://github.com/hngoc-29/Chess-AI.git}"
SIMULATIONS="${SIMULATIONS:-400}"
GAMES="${GAMES:-40}"
EPOCHS="${EPOCHS:-2}"
BATCH_SIZE="${BATCH_SIZE:-128}"
LR="${LR:-0.001}"
MAX_GENERATIONS="${MAX_GENERATIONS:-3}"
HEARTBEAT="${HEARTBEAT:-30}"
LOG_EVERY="${LOG_EVERY:-10}"
RESUME="${RESUME:-1}"

if [ -z "$PROJECT_ROOT" ]; then
  for candidate in "$PWD" "$PWD/ChessAI" /kaggle/working/ChessAI /content/ChessAI; do
    if [ -f "$candidate/AI/src/colab_selfplay_pipeline.py" ] || [ -f "$candidate/src/colab_selfplay_pipeline.py" ]; then
      PROJECT_ROOT="$candidate"
      break
    fi
  done
fi

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="/kaggle/working/ChessAI"
fi

mkdir -p "$(dirname "$PROJECT_ROOT")" "$WORKDIR" "$OUTPUT_ROOT"
if [ ! -d "$PROJECT_ROOT/.git" ]; then
  echo "[Setup] Repository not found at $PROJECT_ROOT; cloning from $REPO_URL"
  rm -rf "$PROJECT_ROOT"
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to fetch the repository" >&2
    exit 1
  fi
  git clone --depth 1 "$REPO_URL" "$PROJECT_ROOT"
fi
cd "$PROJECT_ROOT"

PIPELINE_SCRIPT="${PIPELINE_SCRIPT:-}"
if [ -z "$PIPELINE_SCRIPT" ]; then
  for candidate in \
    "$PROJECT_ROOT/AI/src/colab_selfplay_pipeline.py" \
    "$PROJECT_ROOT/src/colab_selfplay_pipeline.py" \
    "$PWD/AI/src/colab_selfplay_pipeline.py" \
    "$PWD/src/colab_selfplay_pipeline.py"; do
    if [ -f "$candidate" ]; then
      PIPELINE_SCRIPT="$candidate"
      break
    fi
  done
fi

if [ -z "$PIPELINE_SCRIPT" ] || [ ! -f "$PIPELINE_SCRIPT" ]; then
  echo "[Setup] Pipeline script not found. Checked:" >&2
  echo "  - $PROJECT_ROOT/AI/src/colab_selfplay_pipeline.py" >&2
  echo "  - $PROJECT_ROOT/src/colab_selfplay_pipeline.py" >&2
  exit 1
fi

echo "[Setup] Using pipeline script: $PIPELINE_SCRIPT"

PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"
if [ -z "$PYTHON_BIN" ]; then
  echo "No Python interpreter found" >&2
  exit 1
fi

VENV_DIR="${VENV_DIR:-/kaggle/working/chess_venv}"
USE_VENV="${USE_VENV:-}"
if [ -z "${USE_VENV}" ]; then
  if [ -d /kaggle ] || [ -n "${KAGGLE_KERNEL_RUN_TYPE:-}" ] || [ -n "${KAGGLE_URL_BASE:-}" ]; then
    USE_VENV="1"
  else
    USE_VENV="0"
  fi
fi

"$PYTHON_BIN" -V
apt-get update -qq
apt-get install -y -qq build-essential cmake python3-venv >/dev/null

if [ "$USE_VENV" = "1" ]; then
  if [ ! -x "$VENV_DIR/bin/python" ]; then
    echo "[Setup] Creating virtual environment at $VENV_DIR"
    if "$PYTHON_BIN" -m venv "$VENV_DIR" 2>/dev/null; then
      :
    elif command -v virtualenv >/dev/null 2>&1; then
      virtualenv "$VENV_DIR"
    else
      "$PYTHON_BIN" -m venv --without-pip "$VENV_DIR" 2>/dev/null || true
    fi
  fi

  if [ -x "$VENV_DIR/bin/python" ]; then
    PYTHON_BIN="$VENV_DIR/bin/python"
    echo "[Setup] Using virtual environment Python: $PYTHON_BIN"
  else
    echo "[Setup] Virtual environment creation failed; falling back to system Python" >&2
    USE_VENV="0"
    PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"
  fi
fi

if [ "$USE_VENV" = "1" ] && [ -x "$VENV_DIR/bin/python" ] && [ ! -x "$VENV_DIR/bin/pip" ]; then
  echo "[Setup] Installing pip into virtual environment"
  curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
  "$VENV_DIR/bin/python" /tmp/get-pip.py --break-system-packages || \
  "$VENV_DIR/bin/python" /tmp/get-pip.py
fi

install_python_package() {
  local package="$1"
  shift || true
  echo "[Setup] Installing Python package: $package"
  if "$PYTHON_BIN" -m pip install -q --disable-pip-version-check --no-input --no-cache-dir "$package" "$@"; then
    return 0
  fi
  if "$PYTHON_BIN" -m pip install -q --disable-pip-version-check --no-input --no-cache-dir --break-system-packages "$package" "$@"; then
    return 0
  fi
  "$PYTHON_BIN" -m pip install --disable-pip-version-check --no-input --no-cache-dir "$package" "$@"
}

"$PYTHON_BIN" -m pip install -q --upgrade pip setuptools wheel >/dev/null 2>&1 || true
install_python_package "wrapt"
if ! "$PYTHON_BIN" -c "import wrapt" >/dev/null 2>&1; then
  echo "[Setup] wrapt is still unavailable after installation" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Detect CUDA version → pick pinned library versions
# Versions are frozen here. To upgrade, change ALL four variables together.
# ---------------------------------------------------------------------------
CUDA_VER=$("$PYTHON_BIN" -c "import torch; print(torch.version.cuda or '')" 2>/dev/null \
           || nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' | head -1 \
           || echo "12.1")

if echo "$CUDA_VER" | grep -q "^12\.4"; then
  CU="cu124"
  TORCH_VER="2.5.1"
  TORCHVISION_VER="0.20.1"
  TORCHAUDIO_VER="2.5.1"
elif echo "$CUDA_VER" | grep -q "^12\.1"; then
  CU="cu121"
  TORCH_VER="2.3.1"
  TORCHVISION_VER="0.18.1"
  TORCHAUDIO_VER="2.3.1"
elif echo "$CUDA_VER" | grep -q "^11\.8"; then
  CU="cu118"
  TORCH_VER="2.3.1"
  TORCHVISION_VER="0.18.1"
  TORCHAUDIO_VER="2.3.1"
else
  # Unknown CUDA — fall back to a generic PyTorch wheel set
  CU="cu121"
  TORCH_VER="2.3.1"
  TORCHVISION_VER="0.18.1"
  TORCHAUDIO_VER="2.3.1"
fi

LIBTORCH_URL="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-${TORCH_VER}%2Bcpu.zip"

echo "[Setup] CUDA=${CUDA_VER} → pinning torch==${TORCH_VER}+${CU}"
echo "[Setup] Using CPU-only LibTorch for the C++ engine: ${LIBTORCH_URL}"

# Force-overwrite all Python packages with exact pinned versions.
# --force-reinstall ensures we never silently run a different version.
rm -rf /tmp/pip-* /root/.cache/pip 2>/dev/null || true
"$PYTHON_BIN" -m pip install -q \
  --force-reinstall \
  --disable-pip-version-check \
  --no-input \
  --no-cache-dir \
  "numpy==1.26.4" \
  "torch==${TORCH_VER}+${CU}" \
  "torchvision==${TORCHVISION_VER}+${CU}" \
  "torchaudio==${TORCHAUDIO_VER}+${CU}" \
  --extra-index-url "https://download.pytorch.org/whl/${CU}" >/dev/null 2>&1 || true

# Optional deps — also pinned so they cannot drift
"$PYTHON_BIN" -m pip install -q \
  --force-reinstall \
  --disable-pip-version-check \
  --no-input \
  --no-cache-dir \
  "pandas==2.2.3" \
  "matplotlib==3.9.4" >/dev/null 2>&1 || true

# Print final installed versions for the log
echo "[Setup] Installed versions:"
"$PYTHON_BIN" -c "
import os
os.environ['MPLBACKEND'] = 'Agg'
import numpy, torch, torchvision, torchaudio, pandas, matplotlib
print(f'  numpy=={numpy.__version__}')
print(f'  torch=={torch.__version__}')
print(f'  torchvision=={torchvision.__version__}')
print(f'  torchaudio=={torchaudio.__version__}')
print(f'  pandas=={pandas.__version__}')
print(f'  matplotlib=={matplotlib.__version__}')
"
mkdir -p "$WORKDIR"
if [ ! -d "$WORKDIR/libtorch/share/cmake/Torch/TorchConfig.cmake" ]; then
  rm -rf "$WORKDIR/libtorch" "$WORKDIR/libtorch.zip"
  wget -q "$LIBTORCH_URL" -O "$WORKDIR/libtorch.zip"
  unzip -q "$WORKDIR/libtorch.zip" -d "$WORKDIR"
fi

if [ -d "$PROJECT_ROOT/AI/engine" ] && [ ! -e "$PROJECT_ROOT/engine" ]; then
  ln -s "$PROJECT_ROOT/AI/engine" "$PROJECT_ROOT/engine"
  echo "[Setup] Created engine compatibility link: $PROJECT_ROOT/engine"
fi

RESUME_ARGS=()
if [ "$RESUME" = "1" ]; then
  RESUME_ARGS+=(--resume)
fi

"$PYTHON_BIN" "$PIPELINE_SCRIPT" \
  --project_root "$PROJECT_ROOT" \
  --drive_root "$OUTPUT_ROOT" \
  --workdir "$WORKDIR" \
  --checkpoint_dir "$CHECKPOINT_DIR" \
  --simulations "$SIMULATIONS" \
  --games "$GAMES" \
  --epochs "$EPOCHS" \
  --batch_size "$BATCH_SIZE" \
  --lr "$LR" \
  --max_generations "$MAX_GENERATIONS" \
  --log_every "$LOG_EVERY" \
  --heartbeat "$HEARTBEAT" \
  --no_infinite
