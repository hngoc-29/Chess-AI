#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/kaggle/working/ChessAI}"
WORKDIR="${WORKDIR:-/kaggle/working/chess_selfplay}"
OUTPUT_ROOT="${OUTPUT_ROOT:-/kaggle/working/chess_outputs}"
SIMULATIONS="${SIMULATIONS:-200}"
GAMES="${GAMES:-50}"
EPOCHS="${EPOCHS:-2}"
BATCH_SIZE="${BATCH_SIZE:-128}"
LR="${LR:-0.001}"
MAX_GENERATIONS="${MAX_GENERATIONS:-2}"
HEARTBEAT="${HEARTBEAT:-30}"
LOG_EVERY="${LOG_EVERY:-10}"

cd "$PROJECT_ROOT"

python -V
apt-get update -qq
apt-get install -y -qq build-essential cmake >/dev/null

if [ ! -d /kaggle/working/libtorch ]; then
  rm -f /kaggle/working/libtorch.zip
  wget -q "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip" -O /kaggle/working/libtorch.zip
  unzip -q /kaggle/working/libtorch.zip -d /kaggle/working
fi

python src/colab_selfplay_pipeline.py \
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
