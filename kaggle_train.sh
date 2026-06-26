#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/kaggle/working/ChessAI}"
WORKDIR="${WORKDIR:-/kaggle/working/chess_selfplay}"
OUTPUT_ROOT="${OUTPUT_ROOT:-/kaggle/working/chess_outputs}"
REPO_URL="${REPO_URL:-https://github.com/hngoc-29/Chess-AI.git}"
SIMULATIONS="${SIMULATIONS:-400}"
GAMES="${GAMES:-40}"
EPOCHS="${EPOCHS:-2}"
BATCH_SIZE="${BATCH_SIZE:-128}"
LR="${LR:-0.001}"
MAX_GENERATIONS="${MAX_GENERATIONS:-3}"
HEARTBEAT="${HEARTBEAT:-30}"
LOG_EVERY="${LOG_EVERY:-10}"

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

PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || true)}"
if [ -z "$PYTHON_BIN" ]; then
  echo "No Python interpreter found" >&2
  exit 1
fi

"$PYTHON_BIN" -V
apt-get update -qq
apt-get install -y -qq build-essential cmake >/dev/null
"$PYTHON_BIN" -m pip install -q --upgrade pip
"$PYTHON_BIN" -m pip install -q --upgrade --force-reinstall \
  "numpy<2.0" \
  "torch==2.2.2" \
  "torchvision==0.17.2" \
  "torchaudio==2.2.2"

PIPELINE_SCRIPT=""
if [ -f "$PROJECT_ROOT/AI/src/colab_selfplay_pipeline.py" ]; then
  PIPELINE_SCRIPT="$PROJECT_ROOT/AI/src/colab_selfplay_pipeline.py"
elif [ -f "$PROJECT_ROOT/src/colab_selfplay_pipeline.py" ]; then
  PIPELINE_SCRIPT="$PROJECT_ROOT/src/colab_selfplay_pipeline.py"
elif [ -f "$(pwd)/AI/src/colab_selfplay_pipeline.py" ]; then
  PIPELINE_SCRIPT="$(pwd)/AI/src/colab_selfplay_pipeline.py"
else
  echo "Could not find colab_selfplay_pipeline.py under $PROJECT_ROOT" >&2
  exit 1
fi

if [ ! -d /kaggle/working/libtorch ]; then
  rm -f /kaggle/working/libtorch.zip
  wget -q "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip" -O /kaggle/working/libtorch.zip
  unzip -q /kaggle/working/libtorch.zip -d /kaggle/working
fi

"$PYTHON_BIN" "$PIPELINE_SCRIPT" \
  --project_root "$PROJECT_ROOT" \
  --drive_root "$OUTPUT_ROOT" \
  --workdir "$WORKDIR" \
  --simulations "$SIMULATIONS" \
  --games "$GAMES" \
  --epochs "$EPOCHS" \
  --batch_size "$BATCH_SIZE" \
  --lr "$LR" \
  --max_generations "$MAX_GENERATIONS" \
  --log_every "$LOG_EVERY" \
  --heartbeat "$HEARTBEAT" \
  --no_infinite
