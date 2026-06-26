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
import gc
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
        torch.cuda.set_device(device)
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
    if (cwd / 'src' / 'colab_selfplay_pipeline.py').exists():
        project_root = cwd
    elif (Path('/kaggle/working/ChessAI') / 'src' / 'colab_selfplay_pipeline.py').exists():
        project_root = Path('/kaggle/working/ChessAI')
    elif (Path('/content/ChessAI') / 'src' / 'colab_selfplay_pipeline.py').exists():
        project_root = Path('/content/ChessAI')
    else:
        project_root = cwd

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
    """Pick a LibTorch archive compatible with the current Colab CUDA runtime."""
    cuda_ver = torch.version.cuda or ""
    print(f"[Torch] torch={torch.__version__}, cuda={cuda_ver}")
    if cuda_ver.startswith("12.4"):
        return "https://download.pytorch.org/libtorch/cu124/libtorch-cxx11-abi-shared-with-deps-2.5.1%2Bcu124.zip"
    if cuda_ver.startswith("12.1"):
        return "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip"
    if cuda_ver.startswith("11.8"):
        return "https://download.pytorch.org/libtorch/cu118/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu118.zip"
    return "https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.2%2Bcu121.zip"


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


def train_policy_model(
    model: nn.Module,
    states: torch.Tensor,
    moves: torch.Tensor,
    lr: float = 1e-3,
    batch_size: int = 256,
    epochs: int = 3,
    device: torch.device = torch.device("cpu"),
) -> nn.Module:
    model = model.to(device)
    model.train()

    effective_batch_size = max(16, batch_size)
    if device.type == "cuda":
        effective_batch_size = min(effective_batch_size, 128)

    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    scaler = torch.cuda.amp.GradScaler(enabled=(device.type == "cuda"))

    for epoch in range(epochs):
        running_loss = 0.0
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

        if device.type == "cuda":
            torch.cuda.empty_cache()
        gc.collect()
        print(f"[Train] epoch={epoch + 1}/{epochs} loss={running_loss / max(1, len(loader)):.4f}")

    model.eval()
    return model


def save_traced_model(model: nn.Module, path: Path, device: torch.device) -> None:
    model = model.to(device).eval()
    dummy = torch.randn(1, 12, 8, 8, device=device)
    traced = torch.jit.trace(model, dummy)
    traced.save(str(path))
    print(f"[Model] saved TorchScript: {path}")


def publish_latest_model(gen_model_path: Path, best_model_path: Path, project_root: Path) -> None:
    best_model_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gen_model_path, best_model_path)

    project_model_path = project_root / "data" / "best_model_traced.pt"
    project_model_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gen_model_path, project_model_path)

    print(f"[Model] published new model to {best_model_path}")
    print(f"[Model] synced project model to {project_model_path}")


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


def run_pipeline(
    project_root: Path,
    workdir: Path,
    drive_root: Path,
    initial_model_path: Optional[Path] = None,
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
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    configure_torch_runtime(device)
    print(f"[Runtime] using device={device}")
    if device.type == "cuda":
        print(f"[Runtime] gpu={torch.cuda.get_device_name(0)}")
        print(f"[Runtime] gpu_memory_gb={torch.cuda.get_device_properties(0).total_memory / (1024 ** 3):.2f}")

    best_model_path = drive_root / "best_model_traced.pt"
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

    engine_binary = build_engine(project_root, setup_libtorch(project_root, workdir))
    print(f"[Pipeline] self-play logging interval: every {log_every_games} games")
    print(f"[Pipeline] heartbeat interval: every {heartbeat_seconds:.0f}s")

    generation = 0
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

        replay_files = [generation_file]
        if generation > 1:
            replay_files.append(drive_root / f"selfplay_gen_{generation - 1}.bin")
        if generation > 2:
            replay_files.append(drive_root / f"selfplay_gen_{generation - 2}.bin")

        states, moves = load_replay_buffer(replay_files)
        print(f"[Progress] Generation {generation}: training with {states.shape[0]} samples")
        model = train_policy_model(
            model=model,
            states=states,
            moves=moves,
            lr=learning_rate,
            batch_size=batch_size,
            epochs=epochs,
            device=device,
        )

        gen_model_path = drive_root / f"model_gen_{generation}.pt"
        save_traced_model(model, gen_model_path, device)
        publish_latest_model(gen_model_path, best_model_path, project_root)
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
    archive_path = Path(args.archive_path).expanduser().resolve() if args.archive_path else None

    project_root = prepare_project_root(project_root, archive_path)

    run_pipeline(
        project_root=project_root,
        workdir=workdir,
        drive_root=drive_root,
        initial_model_path=initial_model_path,
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
