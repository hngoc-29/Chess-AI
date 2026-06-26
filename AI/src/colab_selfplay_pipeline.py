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


class ChessPolicyNet(nn.Module):
    """A compact policy network for 12x8x8 board inputs."""

    def __init__(self, num_actions: int = 4096) -> None:
        super().__init__()
        self.conv1 = nn.Conv2d(12, 64, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
        self.conv3 = nn.Conv2d(128, 128, kernel_size=3, padding=1)
        self.fc1 = nn.Linear(128 * 8 * 8, 512)
        self.policy_head = nn.Linear(512, num_actions)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = F.relu(self.conv1(x))
        x = F.relu(self.conv2(x))
        x = F.relu(self.conv3(x))
        x = torch.flatten(x, start_dim=1)
        x = F.relu(self.fc1(x))
        return self.policy_head(x)


def should_log_output(line: str) -> bool:
    text = line.strip()
    if not text:
        return False
    if text.startswith(("[CMD]", "[Heartbeat]", "[SelfPlay]", "[Drive]", "[Pipeline]", "[Model]", "[Train]", "[Runtime]", "[Torch]", "[Archive]", "[LibTorch]")):
        return True
    lowered = text.lower()
    return any(token in lowered for token in ("error", "failed", "exception", "traceback", "warning"))


def run(
    cmd: List[str],
    cwd: Optional[str] = None,
    env: Optional[dict] = None,
    check: bool = True,
    heartbeat_seconds: Optional[float] = None,
) -> subprocess.CompletedProcess:
    print("[CMD]", " ".join(cmd))
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
                print(line, end="")
        process.stdout.close()

    def heartbeat() -> None:
        while not stop_event.is_set():
            if heartbeat_seconds is not None and heartbeat_seconds > 0:
                print(f"[Heartbeat] still running after {time.time() - start_time:.1f}s")
            if stop_event.wait(heartbeat_seconds or 1.0):
                break

    stream_thread = threading.Thread(target=stream_output, daemon=True)
    stream_thread.start()
    heartbeat_thread: Optional[threading.Thread] = None
    if heartbeat_seconds is not None and heartbeat_seconds > 0:
        heartbeat_thread = threading.Thread(target=heartbeat, daemon=True)
        heartbeat_thread.start()

    returncode = process.wait()
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
        print('[Drive] Already mounted.')
        return
    try:
        from google.colab import drive  # type: ignore
        drive.mount('/content/drive', force_remount=False)
        print('[Drive] Mounted successfully.')
    except Exception as exc:  # pragma: no cover
        print(f'[Drive] Mount skipped: {exc}')


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
    """Pick a LibTorch archive compatible with the installed PyTorch runtime."""
    cuda_ver = torch.version.cuda or ""
    torch_ver = torch.__version__.split("+", 1)[0]
    print(f"[Torch] torch={torch.__version__}, cuda={cuda_ver}")
    if cuda_ver.startswith("12.4") or torch_ver.startswith("2.5"):
        return "https://download.pytorch.org/libtorch/cu124/libtorch-cxx11-abi-shared-with-deps-2.5.1%2Bcu124.zip"
    if cuda_ver.startswith("12.1") or torch_ver.startswith("2.3"):
        return "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.3.1%2Bcu121.zip"
    if cuda_ver.startswith("11.8"):
        return "https://download.pytorch.org/libtorch/cu118/libtorch-cxx11-abi-shared-with-deps-2.3.1%2Bcu118.zip"
    return "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.3.1%2Bcu121.zip"


def setup_libtorch(project_root: Path, workdir: Path) -> Path:
    libtorch_dir = workdir / "libtorch"
    if not libtorch_dir.exists():
        url = select_libtorch_url()
        archive = workdir / "libtorch.zip"
        print(f"[LibTorch] Downloading {url}")
        run(["wget", "-q", url, "-O", str(archive)])
        run(["unzip", "-q", str(archive), "-d", str(workdir)])
        if not libtorch_dir.exists():
            raise RuntimeError("LibTorch unzip did not create the expected directory.")
    else:
        print(f"[LibTorch] Reusing {libtorch_dir}")

    return libtorch_dir


def build_engine(project_root: Path, libtorch_dir: Path) -> Path:
    engine_dir = project_root / "AI" / "engine"
    if not (engine_dir / "CMakeLists.txt").exists():
        engine_dir = project_root / "engine"
    build_dir = engine_dir / "build"
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

    binary = build_dir / "selfplay"
    if not binary.exists():
        raise RuntimeError("The self-play binary was not built successfully.")
    return binary


def load_generation_samples(path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    if not path.exists():
        raise FileNotFoundError(path)
    data = np.fromfile(path, dtype=np.float32)
    if data.size == 0:
        raise ValueError(f"No samples found in {path}")
    if data.size % 770 != 0:
        raise ValueError(f"Unexpected sample size in {path}: {data.size}")
    samples = data.reshape(-1, 770)
    states = samples[:, :768].astype(np.float32).reshape(-1, 12, 8, 8)
    moves = samples[:, 768].astype(np.int64)
    values = samples[:, 769].astype(np.float32)
    return states, moves, values


def load_replay_buffer(paths: List[Path]) -> Tuple[torch.Tensor, torch.Tensor]:
    all_states = []
    all_moves = []
    for path in paths:
        if not path.exists():
            continue
        states, moves, _ = load_generation_samples(path)
        all_states.append(states)
        all_moves.append(moves)
    if not all_states:
        raise RuntimeError("No generation data found for training.")
    states_np = np.concatenate(all_states, axis=0)
    moves_np = np.concatenate(all_moves, axis=0)
    x = torch.from_numpy(states_np)
    y = torch.from_numpy(moves_np)
    return x, y


def validate_torchscript_model(model_path: Path, device: torch.device) -> None:
    if not model_path.exists():
        raise FileNotFoundError(f"TorchScript model not found: {model_path}")
    try:
        scripted = torch.jit.load(str(model_path), map_location=device)
        with torch.no_grad():
            dummy = torch.randn(1, 12, 8, 8, device=device)
            scripted(dummy)
        print(f"[Model] validated TorchScript model: {model_path}")
    except Exception as exc:  # pragma: no cover
        raise RuntimeError(f"TorchScript model validation failed for {model_path}: {exc}") from exc


def select_replay_files(drive_root: Path, generation_file: Path, min_samples: int = 4096, max_files: int = 6) -> List[Path]:
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
    print(f"[Pipeline] using {len(replay_files)} replay files with {total_samples} total samples")
    return replay_files


def train_policy_model(
    model: nn.Module,
    states: torch.Tensor,
    moves: torch.Tensor,
    lr: float = 1e-3,
    batch_size: int = 256,
    epochs: int = 3,
    device: torch.device = torch.device("cpu"),
    checkpoint_path: Optional[Path] = None,
    metrics_output_dir: Optional[Path] = None,
    patience: int = 2,
    min_delta: float = 1e-4,
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

    for epoch in range(epochs):
        running_loss = 0.0
        running_value_loss = 0.0
        total_batches = 0
        current_batch_size = effective_batch_size
        while True:
            try:
                dataset = TensorDataset(states, moves)
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
                    print(f"[Train] reducing batch size to {current_batch_size} after OOM")
                    continue
                raise

        for xb, yb in loader:
            xb = xb.to(device, non_blocking=True)
            yb = yb.to(device, non_blocking=True)
            optimizer.zero_grad(set_to_none=True)
            if device.type == "cuda":
                with torch.autocast(device_type="cuda", dtype=torch.float16):
                    logits = model(xb)
                    loss = F.cross_entropy(logits, yb.long())
                scaler.scale(loss).backward()
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                scaler.step(optimizer)
                scaler.update()
            else:
                logits = model(xb)
                loss = F.cross_entropy(logits, yb.long())
                loss.backward()
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                optimizer.step()
            running_loss += float(loss.item())
            total_batches += 1

        avg_loss = running_loss / max(1, total_batches)
        avg_value_loss = running_value_loss / max(1, total_batches)
        if checkpoint_path is not None:
            checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
            torch.save({
                "model_state": model.state_dict(),
                "optimizer_state": optimizer.state_dict(),
                "epoch": epoch + 1,
                "loss": avg_loss,
            }, checkpoint_path)

        if device.type == "cuda":
            torch.cuda.empty_cache()
        gc.collect()
        print(f"[Train] epoch={epoch + 1}/{epochs} loss={avg_loss:.4f} value_loss={avg_value_loss:.4f}")
        history["epochs"].append({"epoch": epoch + 1, "loss": avg_loss, "value_loss": avg_value_loss})
        if metrics_output_dir is not None:
            export_training_metrics(history, metrics_output_dir)

        if best_loss - avg_loss > min_delta:
            best_loss = avg_loss
            patience_counter = 0
        else:
            patience_counter += 1
            if patience_counter >= patience:
                print(f"[Train] early stopping at epoch {epoch + 1}/{epochs} due to no improvement")
                break

    model.eval()
    return model, history


def save_traced_model(model: nn.Module, path: Path, device: torch.device) -> None:
    model = model.to(device).eval()
    dummy = torch.randn(1, 12, 8, 8, device=device)
    traced = torch.jit.trace(model, dummy)
    traced.save(str(path))
    print(f"[Model] saved TorchScript: {path}")


def save_training_summary(history: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(history, handle, indent=2)
    print(f"[Train] saved summary: {path}")


def export_training_metrics(history: dict, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    if not history.get("epochs"):
        return

    epochs = [entry["epoch"] for entry in history["epochs"]]
    losses = [entry["loss"] for entry in history["epochs"]]
    value_losses = [entry.get("value_loss", 0.0) for entry in history["epochs"]]

    csv_path = output_dir / "training_metrics.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["epoch", "loss", "value_loss"])
        writer.writeheader()
        for epoch, loss, value_loss in zip(epochs, losses, value_losses):
            writer.writerow({"epoch": epoch, "loss": loss, "value_loss": value_loss})

    if plt is not None:
        fig, axes = plt.subplots(1, 2, figsize=(10, 4))
        axes[0].plot(epochs, losses, marker="o")
        axes[0].set_title("Loss")
        axes[0].set_xlabel("Epoch")
        axes[0].set_ylabel("Loss")
        axes[1].plot(epochs, value_losses, marker="o", color="orange")
        axes[1].set_title("Value Loss")
        axes[1].set_xlabel("Epoch")
        axes[1].set_ylabel("Value Loss")
        fig.tight_layout()
        fig.savefig(output_dir / "training_metrics.png", dpi=150)
        plt.close(fig)

    print(f"[Train] exported metrics to {output_dir}")


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

    print(f"[Train] exported generation comparison to {csv_path} and {md_path}")


def find_latest_checkpoint(drive_root: Path) -> Optional[Path]:
    checkpoints = sorted(drive_root.glob("checkpoint_gen_*.pt"), key=lambda p: int(p.stem.split("_")[-1].split(".")[0]))
    return checkpoints[-1] if checkpoints else None


def load_checkpoint(model: nn.Module, checkpoint_path: Path, device: torch.device) -> Tuple[nn.Module, dict]:
    checkpoint = torch.load(checkpoint_path, map_location=device)
    model.load_state_dict(checkpoint["model_state"])
    model.to(device)
    return model, checkpoint


def publish_latest_model(gen_model_path: Path, best_model_path: Path, project_root: Path) -> None:
    best_model_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gen_model_path, best_model_path)

    project_model_path = project_root / "data" / "best_model_traced.pt"
    project_model_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gen_model_path, project_model_path)

    legacy_project_model_path = project_root / "best_model_traced.pt"
    legacy_project_model_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gen_model_path, legacy_project_model_path)

    print(f"[Model] published new model to {best_model_path}")
    print(f"[Model] synced project model to {project_model_path}")
    print(f"[Model] synced legacy project model to {legacy_project_model_path}")


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
) -> Path:
    local_generation_file = workdir / f"selfplay_gen_{generation}.bin"
    drive_generation_file = drive_root / f"selfplay_gen_{generation}.bin"
    cmd = [
        str(binary),
        "--model_path",
        str(best_model_path),
        "--simulations",
        str(simulations),
        "--games",
        str(games),
        "--log_every",
        str(log_every),
        "--output",
        str(local_generation_file),
    ]
    start_ts = time.time()
    print(f"[Progress] Generation {generation}: starting self-play ({games} games, {simulations} simulations)")
    run(cmd, cwd=str(project_root), heartbeat_seconds=heartbeat_seconds)
    elapsed = time.time() - start_ts
    print(f"[Progress] Generation {generation}: self-play complete in {elapsed:.1f}s")
    shutil.copy2(local_generation_file, drive_generation_file)
    print(f"[Progress] Generation {generation}: replay saved -> {drive_generation_file}")
    print(f"[Progress] Generation {generation}: replay size={local_generation_file.stat().st_size} bytes")
    return drive_generation_file


def resolve_best_model_path(project_root: Path, drive_root: Path, explicit_path: Optional[Path] = None) -> Path:
    if explicit_path is not None:
        return explicit_path

    candidates = [
        drive_root / "best_model_traced.pt",
        project_root / "data" / "best_model_traced.pt",
        project_root / "best_model_traced.pt",
        project_root / "models" / "best_model_traced.pt",
    ]
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
) -> None:
    workdir.mkdir(parents=True, exist_ok=True)
    drive_root.mkdir(parents=True, exist_ok=True)

    seed_everything()
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    configure_torch_runtime(device)
    print(f"[Runtime] using device={device}")
    if device.type == "cuda":
        print(f"[Runtime] gpu={torch.cuda.get_device_name(0)}")
        print(f"[Runtime] gpu_memory_gb={torch.cuda.get_device_properties(0).total_memory / (1024 ** 3):.2f}")

    best_model_path = resolve_best_model_path(project_root, drive_root, best_model_path_override)
    if initial_model_path is not None and initial_model_path.exists():
        shutil.copy2(initial_model_path, best_model_path)
    elif not best_model_path.exists() and (project_root / "data" / "best_model_traced.pt").exists():
        shutil.copy2(project_root / "data" / "best_model_traced.pt", best_model_path)

    model = ChessPolicyNet()
    if best_model_path.exists():
        try:
            script_module = torch.jit.load(str(best_model_path))
            model.load_state_dict(script_module.state_dict(), strict=False)
            print(f"[Model] loaded weights from {best_model_path}")
        except Exception as exc:  # pragma: no cover
            print(f"[Model] could not load {best_model_path}: {exc}")
    else:
        print("[Model] no initial model found; creating a fresh TorchScript model")
        save_traced_model(model, best_model_path, device)

    validate_torchscript_model(best_model_path, device)

    latest_checkpoint = find_latest_checkpoint(drive_root)
    if latest_checkpoint is not None:
        print(f"[Checkpoint] found latest checkpoint: {latest_checkpoint}")
        try:
            model, checkpoint = load_checkpoint(model, latest_checkpoint, device)
            save_traced_model(model, best_model_path, device)
            print(f"[Checkpoint] resumed from epoch {checkpoint.get('epoch', 0)} and synced weights to {best_model_path}")
        except Exception as exc:  # pragma: no cover
            print(f"[Checkpoint] could not resume from {latest_checkpoint}: {exc}")

    engine_binary = build_engine(project_root, setup_libtorch(project_root, workdir))
    print(f"[Pipeline] self-play logging interval: every {log_every_games} games")
    print(f"[Pipeline] heartbeat interval: every {heartbeat_seconds:.0f}s")

    generation = 0
    generation_summaries: List[dict] = []
    while True:
        generation += 1
        print(f"\n===== Generation {generation}/{max_generations if max_generations is not None else '∞'} =====")
        print(f"[Progress] Using model: {best_model_path}")

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
        )

        validate_torchscript_model(best_model_path, device)
        replay_files = select_replay_files(drive_root, generation_file)
        states, moves = load_replay_buffer(replay_files)
        print(f"[Progress] Generation {generation}: training with {states.shape[0]} samples")
        checkpoint_path = drive_root / f"checkpoint_gen_{generation}.pt"
        metrics_output_dir = drive_root / f"metrics_gen_{generation}"
        model, history = train_policy_model(
            model=model,
            states=states,
            moves=moves,
            lr=learning_rate,
            batch_size=batch_size,
            epochs=epochs,
            device=device,
            checkpoint_path=checkpoint_path,
            metrics_output_dir=metrics_output_dir,
            patience=2,
            min_delta=1e-4,
        )

        gen_model_path = drive_root / f"model_gen_{generation}.pt"
        save_traced_model(model, gen_model_path, device)
        save_training_summary(history, drive_root / f"training_summary_gen_{generation}.json")
        export_training_metrics(history, metrics_output_dir)
        publish_latest_model(gen_model_path, best_model_path, project_root)

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
        print(f"[Progress] Generation {generation}: training complete")
        print(f"[Progress] Generation {generation}: model saved -> {gen_model_path}")

        if max_generations is not None and generation >= max_generations:
            print(f"[Progress] Generation {generation}: completed ({generation}/{max_generations})")
            print("[Pipeline] session completed")
            break
        if not infinite:
            print(f"[Progress] Generation {generation}: completed ({generation}/{max_generations if max_generations is not None else '∞'})")
            print("[Pipeline] session completed")
            break

        print(f"[Progress] Generation {generation}: next generation starting")

    print("[Pipeline] session completed")
    print(f"[Pipeline] final_model={best_model_path}")
    print(f"[Pipeline] final_output_dir={drive_root}")


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

    project_root = prepare_project_root(project_root, archive_path)

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
    )


if __name__ == "__main__":
    main()
