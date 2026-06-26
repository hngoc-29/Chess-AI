# -*- coding: utf-8 -*-
"""
Train.py cho Chess AI (PyTorch 2.x) – Tối ưu cho Google Colab
================================================================
HƯỚNG DẪN:
  1. Upload chess_data.tar.gz lên Google Drive
     (cấu trúc bên trong: src/ChessEnv.cpp  và  data/<tên>.bin)
  2. Chỉnh DRIVE_TAR_PATH + CHECKPOINT_DIR ở phần "CẤU HÌNH".
  3. Copy toàn bộ file vào 1 cell Colab (hoặc chia theo dấu # %%).
"""

# ==============================================================
# %% [1] IMPORTS
# ==============================================================
import glob
import os
import re
import shutil
import struct
import tarfile
import time
import warnings
from typing import Optional

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader, Subset


# ==============================================================
# %% [2] CẤU HÌNH  ← CHỈ CẦN CHỈNH 2 DÒNG NÀY
# ==============================================================
DRIVE_TAR_PATH = "/content/drive/MyDrive/chess_data.tar.gz"
CHECKPOINT_DIR = "/content/drive/MyDrive/chess_checkpoints"

# Thư mục local trên Colab VM (tốc độ đọc cao hơn Drive ~10×)
EXTRACT_DIR    = "/content/chess_data"


# ==============================================================
# %% [3] COLAB SETUP
# ==============================================================
def setup_colab(
    drive_tar_path: str = DRIVE_TAR_PATH,
    extract_dir:    str = EXTRACT_DIR,
) -> str:
    """
    Mount Google Drive → giải nén tar.gz về local → trả về path .bin.
    Giải nén chỉ thực hiện 1 lần (dùng sentinel file).
    """
    # 1. Mount Drive
    try:
        from google.colab import drive  # type: ignore
        drive.mount("/content/drive", force_remount=False)
        print("[COLAB] Google Drive đã mount.")
    except ImportError:
        print("[INFO] Không phát hiện Colab – bỏ qua mount Drive.")

    if not os.path.exists(drive_tar_path):
        raise FileNotFoundError(
            f"Không tìm thấy: {drive_tar_path}\n"
            "→ Kiểm tra lại DRIVE_TAR_PATH ở đầu file."
        )

    # 2. Giải nén về local disk (bỏ qua nếu đã làm)
    sentinel = os.path.join(extract_dir, ".extracted")
    if not os.path.exists(sentinel):
        os.makedirs(extract_dir, exist_ok=True)
        print(f"[INFO] Đang giải nén: {drive_tar_path} → {extract_dir}")
        t0 = time.time()
        with tarfile.open(drive_tar_path, "r:gz") as tar:
            tar.extractall(extract_dir)
        open(sentinel, "w").close()
        print(f"[INFO] Giải nén xong ({time.time() - t0:.1f}s).")
    else:
        print(f"[INFO] Dùng lại bản đã giải nén: {extract_dir}")

    # 3. Tìm file .bin (đệ quy, không phụ thuộc cấu trúc bên trong tar)
    bin_files = sorted(
        glob.glob(os.path.join(extract_dir, "**", "*.bin"), recursive=True)
    )
    if not bin_files:
        raise FileNotFoundError(
            f"Không tìm thấy file .bin trong {extract_dir}\n"
            "→ Kiểm tra cấu trúc bên trong tar.gz: phải có thư mục data/<tên>.bin"
        )
    if len(bin_files) > 1:
        warnings.warn(
            f"Tìm thấy {len(bin_files)} file .bin, dùng: {bin_files[0]}"
        )
    print(f"[INFO] Dataset: {bin_files[0]}")
    return bin_files[0]


# ==============================================================
# %% [4] COPY FILE TỪ DRIVE VỀ LOCAL (fallback nếu không dùng tar)
# ==============================================================
def maybe_copy_to_local(file_path: str, cache_dir: str = "/content/chess_cache") -> str:
    abs_path = os.path.abspath(file_path)
    if not abs_path.startswith("/content/drive/"):
        return abs_path  # Đã là local, không cần copy

    os.makedirs(cache_dir, exist_ok=True)
    dst_path = os.path.join(cache_dir, os.path.basename(abs_path))

    need_copy = not os.path.exists(dst_path)
    if not need_copy:
        try:
            need_copy = os.path.getsize(dst_path) != os.path.getsize(abs_path)
        except OSError:
            need_copy = True

    if need_copy:
        print(f"[INFO] Copy từ Drive → local: {dst_path}")
        shutil.copy2(abs_path, dst_path)
    else:
        print(f"[INFO] Dùng bản cache local: {dst_path}")

    return dst_path


# ==============================================================
# %% [5] DATASET
# ==============================================================
class ChessBinaryDataset(Dataset):
    """
    Đọc file binary cờ vua.

    Layout:
      Global header : 36 bytes
      Mỗi game      : game_header (11 bytes) + N × sample (776 bytes)

    Mỗi sample:
      768 bytes : 12 planes × 8 × 8  (uint8, 0/1)
        8 bytes : move info (from_sq, to_sq, promo, flags, padding×4)
    """

    GLOBAL_HEADER_SIZE = 36
    GAME_HEADER_SIZE   = 11
    SAMPLE_SIZE        = 776
    PLANES_SIZE        = 768
    NUM_PLANES         = 12
    BOARD_SIZE         = 8

    def __init__(self, file_path: str, return_promotion: bool = False):
        super().__init__()
        self.file_path        = os.path.abspath(file_path)
        self.return_promotion = return_promotion
        self._fh              = None

        if not os.path.exists(self.file_path):
            raise FileNotFoundError(self.file_path)

        self.file_size = os.path.getsize(self.file_path)
        if self.file_size < self.GLOBAL_HEADER_SIZE:
            raise ValueError("File quá nhỏ, không đủ global header.")

        self._read_global_header()
        self._build_game_index()

        if self.total_samples_header != self.num_samples:
            warnings.warn(
                f"Header totalSamples={self.total_samples_header}, "
                f"thực tế quét được {self.num_samples}."
            )
        if self.total_games_header != self.game_count:
            warnings.warn(
                f"Header totalGames={self.total_games_header}, "
                f"thực tế quét được {self.game_count}."
            )

    def _read_global_header(self):
        with open(self.file_path, "rb") as f:
            header = f.read(self.GLOBAL_HEADER_SIZE)
            if len(header) != self.GLOBAL_HEADER_SIZE:
                raise ValueError("Không đọc đủ global header.")

            magic, version, header_size, total_samples, total_games, \
                sample_bytes, game_header_size, _reserved = struct.unpack(
                    "<8sHHQIIII", header
                )

            if magic != b"CHSDBIN2":
                raise ValueError(f"Magic bytes sai: {magic!r}")
            if version != 2:
                raise ValueError(f"Version không hỗ trợ: {version}")
            if header_size != self.GLOBAL_HEADER_SIZE:
                raise ValueError(f"Header size sai: {header_size}")
            if sample_bytes != self.SAMPLE_SIZE:
                raise ValueError(f"Sample bytes sai: {sample_bytes}")
            if game_header_size != self.GAME_HEADER_SIZE:
                raise ValueError(f"Game header size sai: {game_header_size}")

            self.total_samples_header = total_samples
            self.total_games_header   = total_games

    def _build_game_index(self):
        game_sample_offsets = []
        game_sample_counts  = []
        game_sample_starts  = []

        pos               = self.GLOBAL_HEADER_SIZE
        total_samples_seen = 0
        game_count        = 0

        with open(self.file_path, "rb") as f:
            f.seek(pos, os.SEEK_SET)

            while True:
                game_header = f.read(self.GAME_HEADER_SIZE)
                if not game_header:
                    break
                if len(game_header) != self.GAME_HEADER_SIZE:
                    raise ValueError(f"Game header bị cụt tại offset {pos}.")

                try:
                    _marker, sample_count, _welo, _belo, _result, _reserved = \
                        struct.unpack("<BIHHbB", game_header)
                except struct.error as e:
                    raise ValueError(f"Không parse game header tại {pos}: {e}")

                pos        += self.GAME_HEADER_SIZE
                game_count += 1

                if sample_count == 0:
                    raise ValueError(f"Game #{game_count}: sample_count = 0")
                if sample_count > 10 ** 8:
                    raise ValueError(f"Game #{game_count}: sample_count quá lớn ({sample_count})")

                block_end = pos + sample_count * self.SAMPLE_SIZE
                if block_end > self.file_size:
                    raise ValueError(
                        f"Game #{game_count} bị cụt: cần {block_end}B, file {self.file_size}B."
                    )

                game_sample_offsets.append(pos)
                game_sample_counts.append(sample_count)
                game_sample_starts.append(total_samples_seen)

                total_samples_seen += sample_count
                pos = block_end
                f.seek(pos, os.SEEK_SET)

        if pos != self.file_size:
            trailing = self.file_size - pos
            if trailing > 0:
                warnings.warn(f"File còn {trailing} byte dư ở cuối, bỏ qua.")

        self.game_sample_offsets = np.asarray(game_sample_offsets, dtype=np.uint64)
        self.game_sample_counts  = np.asarray(game_sample_counts,  dtype=np.int64)
        self.game_sample_starts  = np.asarray(game_sample_starts,  dtype=np.int64)
        self.game_sample_ends    = self.game_sample_starts + self.game_sample_counts

        self.game_count  = int(game_count)
        self.num_samples = int(total_samples_seen)

    # ── file handle ──────────────────────────────────────────────────
    def _open_file(self):
        if self._fh is None or self._fh.closed:
            self._fh = open(self.file_path, "rb", buffering=1 << 20)
        return self._fh

    def __len__(self):
        return self.num_samples

    # ── đọc 1 sample ────────────────────────────────────────────────
    def get_sample_from_game(self, game_id: int, sample_in_game: int):
        if not (0 <= game_id < self.game_count):
            raise IndexError(f"game_id out of range: {game_id}")
        if not (0 <= sample_in_game < int(self.game_sample_counts[game_id])):
            raise IndexError(f"sample_in_game out of range: {sample_in_game}")

        fh     = self._open_file()
        offset = int(self.game_sample_offsets[game_id]) + sample_in_game * self.SAMPLE_SIZE
        fh.seek(offset, os.SEEK_SET)
        sample = fh.read(self.SAMPLE_SIZE)
        if len(sample) != self.SAMPLE_SIZE:
            raise IOError(f"Không đọc đủ sample tại game={game_id}, idx={sample_in_game}")

        # ── planes ──
        planes_np = np.frombuffer(sample, dtype=np.uint8,
                                  count=self.PLANES_SIZE, offset=0).copy()
        planes_tensor = torch.from_numpy(planes_np).view(
            self.NUM_PLANES, self.BOARD_SIZE, self.BOARD_SIZE
        ).float()

        # ── move decode (tự phát hiện ASCII UCI cũ hay Binary mới) ──
        b = [int(sample[self.PLANES_SIZE + i]) for i in range(5)]

        if b[0] > 63:
            # ASCII UCI format (dataset cũ)
            from_sq   = (b[1] - ord('1')) * 8 + (b[0] - ord('a'))
            to_sq     = (b[3] - ord('1')) * 8 + (b[2] - ord('a'))
            promo_map = {ord('q'): 5, ord('Q'): 5,
                         ord('r'): 4, ord('R'): 4,
                         ord('b'): 3, ord('B'): 3,
                         ord('n'): 2, ord('N'): 2}
            promotion = promo_map.get(b[4], 0)
        else:
            # Binary format (C++ mới)  byte[2]=promo (0=none,2=N,3=B,4=R,5=Q)
            from_sq   = b[0]
            to_sq     = b[1]
            promotion = b[2]

        policy_label = torch.tensor(from_sq * 64 + to_sq, dtype=torch.long)
        if not (0 <= policy_label.item() < 4096):
            policy_label = torch.tensor(0, dtype=torch.long)

        if self.return_promotion:
            return planes_tensor, policy_label, torch.tensor(promotion, dtype=torch.long)
        return planes_tensor, policy_label

    def __getitem__(self, idx):
        if idx < 0:
            idx += len(self)
        if not (0 <= idx < len(self)):
            raise IndexError(idx)

        game_id       = int(np.searchsorted(self.game_sample_ends, idx, side="right"))
        prev_end      = 0 if game_id == 0 else int(self.game_sample_ends[game_id - 1])
        sample_in_game = int(idx - prev_end)
        return self.get_sample_from_game(game_id, sample_in_game)

    def build_sample_indices_for_games(self, game_ids):
        game_ids = np.asarray(game_ids, dtype=np.int64)
        parts    = [
            np.arange(int(self.game_sample_starts[g]),
                      int(self.game_sample_starts[g]) + int(self.game_sample_counts[g]),
                      dtype=np.int64)
            for g in game_ids
        ]
        return np.concatenate(parts) if parts else np.asarray([], dtype=np.int64)

    def close(self):
        if self._fh is not None:
            try:    self._fh.close()
            finally: self._fh = None

    def __del__(self):
        try:    self.close()
        except Exception: pass

    def __getstate__(self):
        state       = self.__dict__.copy()
        state["_fh"] = None
        return state

    def __setstate__(self, state):
        self.__dict__.update(state)
        self._fh = None


# ==============================================================
# %% [6] SPLIT & LOADERS
# ==============================================================
def split_game_ids(num_games: int, val_ratio: float = 0.1, seed: int = 42):
    if num_games <= 1:
        raise ValueError("Cần ít nhất 2 game.")
    rng   = np.random.default_rng(seed)
    perm  = rng.permutation(num_games)
    n_val = max(1, min(int(round(num_games * val_ratio)), num_games - 1))
    return perm[n_val:], perm[:n_val]


def build_loaders(
    file_path:        str,
    batch_size:       int            = 512,
    seed:             int            = 42,
    num_workers:      Optional[int]  = None,
    return_promotion: bool           = False,
    copy_from_drive:  bool           = False,
    val_ratio:        float          = 0.1,
):
    original_path = os.path.abspath(file_path)
    if copy_from_drive:
        file_path = maybe_copy_to_local(file_path)

    dataset = ChessBinaryDataset(file_path, return_promotion=return_promotion)

    train_game_ids, val_game_ids = split_game_ids(
        dataset.game_count, val_ratio=val_ratio, seed=seed
    )
    train_ds = Subset(dataset, dataset.build_sample_indices_for_games(train_game_ids))
    val_ds   = Subset(dataset, dataset.build_sample_indices_for_games(val_game_ids))

    if num_workers is None:
        # Drive trực tiếp (không copy) → không dùng workers để tránh deadlock
        num_workers = 0 if (original_path.startswith("/content/drive/") and not copy_from_drive) else 2

    use_cuda     = torch.cuda.is_available()
    common_kwargs = dict(
        batch_size=batch_size,
        num_workers=num_workers,
        pin_memory=use_cuda,
    )
    if num_workers > 0:
        common_kwargs["persistent_workers"] = True
        common_kwargs["prefetch_factor"]    = 2
    else:
        common_kwargs["persistent_workers"] = False

    train_loader = DataLoader(train_ds, shuffle=True,  drop_last=True,  **common_kwargs)
    val_loader   = DataLoader(val_ds,   shuffle=False, drop_last=False, **common_kwargs)

    return dataset, train_ds, val_ds, train_loader, val_loader


# ==============================================================
# %% [7] MÔ HÌNH
# ==============================================================
class ResidualBlock(nn.Module):
    def __init__(self, channels: int, dropout: float = 0.3):
        super().__init__()
        self.conv1   = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
        self.bn1     = nn.BatchNorm2d(channels)
        self.dropout = nn.Dropout2d(p=dropout)
        self.conv2   = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
        self.bn2     = nn.BatchNorm2d(channels)

    def forward(self, x):
        out = F.relu(self.bn1(self.conv1(x)))
        out = self.dropout(out)
        out = self.bn2(self.conv2(out))
        return F.relu(out + x)


class ChessPolicyNet(nn.Module):
    """
    Input : [B, 12, 8, 8]
    Output: (policy_logits, value_logits) where policy_logits has shape [B, 4096]
    and value_logits has shape [B, 1].
    """
    def __init__(self, num_blocks: int = 6, hidden_channels: int = 128, dropout: float = 0.3):
        super().__init__()
        self.conv_init  = nn.Conv2d(12, hidden_channels, 3, padding=1, bias=False)
        self.bn_init    = nn.BatchNorm2d(hidden_channels)
        self.blocks     = nn.ModuleList(
            [ResidualBlock(hidden_channels, dropout) for _ in range(num_blocks)]
        )
        self.policy_conv = nn.Conv2d(hidden_channels, 32, 1, bias=False)
        self.policy_bn   = nn.BatchNorm2d(32)
        self.policy_fc   = nn.Linear(32 * 64, 4096)
        self.value_conv  = nn.Conv2d(hidden_channels, 32, 1, bias=False)
        self.value_bn    = nn.BatchNorm2d(32)
        self.value_fc    = nn.Linear(32 * 64, 1)

    def forward(self, x):
        out = F.relu(self.bn_init(self.conv_init(x)))
        for block in self.blocks:
            out = block(out)
        policy_features = F.relu(self.policy_bn(self.policy_conv(out)))
        value_features = F.relu(self.value_bn(self.value_conv(out)))
        policy_logits = self.policy_fc(policy_features.flatten(1))
        value_logits = torch.tanh(self.value_fc(value_features.flatten(1)))
        return policy_logits, value_logits


# ==============================================================
# %% [8] CHECKPOINT UTILS
# ==============================================================
def find_latest_checkpoint(checkpoint_dir: str):
    """Trả về (path, epoch) của checkpoint mới nhất, hoặc (None, 0)."""
    files = glob.glob(os.path.join(checkpoint_dir, "chess_model_epoch_*.pth"))
    if not files:
        return None, 0

    def epoch_of(p):
        m = re.search(r"epoch_(\d+)\.pth$", p)
        return int(m.group(1)) if m else 0

    latest = max(files, key=epoch_of)
    return latest, epoch_of(latest)


def load_checkpoint(path, model, optimizer, scheduler, device):
    """Nạp trạng thái và trả về (start_epoch, best_val_loss)."""
    print(f"[RESUME] Nạp checkpoint: {path}")
    ckpt = torch.load(path, map_location=device, weights_only=False)
    model.load_state_dict(ckpt["model_state_dict"])
    optimizer.load_state_dict(ckpt["optimizer_state_dict"])
    if "scheduler_state_dict" in ckpt:
        scheduler.load_state_dict(ckpt["scheduler_state_dict"])
    start_epoch   = int(ckpt["epoch"]) + 1
    best_val_loss = float(ckpt.get("val_loss", float("inf")))
    print(f"[RESUME] → Tiếp tục epoch {start_epoch}, best_val_loss={best_val_loss:.4f}")
    return start_epoch, best_val_loss


def save_checkpoint(path, epoch, model, optimizer, scheduler, val_loss, val_acc):
    # Unwrap torch.compile nếu cần
    raw_model = getattr(model, "_orig_mod", model)
    torch.save({
        "epoch":                epoch,
        "model_state_dict":     raw_model.state_dict(),
        "optimizer_state_dict": optimizer.state_dict(),
        "scheduler_state_dict": scheduler.state_dict(),
        "val_loss":             val_loss,
        "val_acc":              val_acc,
    }, path)


# ==============================================================
# %% [9] HELPERS
# ==============================================================
def accuracy_top1(logits, labels):
    return (logits.argmax(dim=1) == labels).float().mean().item()


# ==============================================================
# %% [10] MAIN
# ==============================================================
def main():
    # ── Hyperparameters ─────────────────────────────────────────────
    EPOCHS          = 20
    LEARNING_RATE   = 1e-3
    WEIGHT_DECAY    = 1e-4
    BATCH_SIZE      = 512
    NUM_WORKERS     = 2
    SEED            = 42
    VAL_RATIO       = 0.1
    LOG_INTERVAL    = 200
    NUM_BLOCKS      = 6
    HIDDEN_CHANNELS = 128
    DROPOUT         = 0.3
    # Tắt nếu torch.compile gây lỗi trên phiên bản PyTorch cũ
    USE_COMPILE     = True
    # ────────────────────────────────────────────────────────────────

    os.makedirs(CHECKPOINT_DIR, exist_ok=True)

    # ── 1. Setup: mount Drive, giải nén tar.gz, lấy path .bin ───────
    dataset_path = setup_colab()

    # ── 2. Device + AMP ─────────────────────────────────────────────
    use_cuda = torch.cuda.is_available()
    use_amp  = use_cuda          # AMP chỉ hoạt động tốt trên GPU
    device   = torch.device("cuda" if use_cuda else "cpu")
    print(f"[INFO] Device : {device}")
    print(f"[INFO] AMP    : {use_amp}")
    if use_cuda:
        print(f"[INFO] GPU    : {torch.cuda.get_device_name(0)}")
        torch.backends.cudnn.benchmark = True

    # ── 3. Dataset & loaders ─────────────────────────────────────────
    dataset, train_ds, val_ds, train_loader, val_loader = build_loaders(
        file_path        = dataset_path,
        batch_size       = BATCH_SIZE,
        seed             = SEED,
        num_workers      = NUM_WORKERS,
        return_promotion = False,
        copy_from_drive  = False,   # setup_colab() đã extract về local
        val_ratio        = VAL_RATIO,
    )
    print(f"\n[INFO] Games  : {dataset.game_count:,}")
    print(f"[INFO] Samples: {len(dataset):,}  (train {len(train_ds):,} / val {len(val_ds):,})")

    # ── 4. Model, optimizer, scheduler ──────────────────────────────
    model = ChessPolicyNet(
        num_blocks      = NUM_BLOCKS,
        hidden_channels = HIDDEN_CHANNELS,
        dropout         = DROPOUT,
    ).to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.AdamW(
        model.parameters(), lr=LEARNING_RATE, weight_decay=WEIGHT_DECAY
    )
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode="min", factor=0.5, patience=1
    )

    # ── 5. Resume từ checkpoint ──────────────────────────────────────
    start_epoch   = 1
    best_val_loss = float("inf")
    best_path     = os.path.join(CHECKPOINT_DIR, "best_model.pth")

    ckpt_path, _ = find_latest_checkpoint(CHECKPOINT_DIR)
    if ckpt_path:
        start_epoch, best_val_loss = load_checkpoint(
            ckpt_path, model, optimizer, scheduler, device
        )

    # ── 6. torch.compile (PyTorch 2.x – bỏ qua nếu không hỗ trợ) ──
    if USE_COMPILE and use_cuda and hasattr(torch, "compile"):
        try:
            print("[INFO] Áp dụng torch.compile() ...")
            model = torch.compile(model)
        except Exception as exc:
            print(f"[WARNING] torch.compile() thất bại, bỏ qua: {exc}")

    # AMP GradScaler
    scaler = torch.cuda.amp.GradScaler(enabled=use_amp)

    print(f"\n===== BẮT ĐẦU HUẤN LUYỆN (epoch {start_epoch} → {EPOCHS}) =====\n")

    for epoch in range(start_epoch, EPOCHS + 1):
        t_epoch = time.time()

        # ════════════════════ TRAIN ════════════════════
        model.train()
        train_loss = train_acc = 0.0
        train_samples = skipped = 0

        for batch_idx, batch in enumerate(train_loader, 1):
            planes, labels, values = batch[0], batch[1], batch[2]

            if (labels < 0).any() or (labels >= 4096).any():
                skipped += 1
                continue

            planes = planes.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)
            values = values.to(device, non_blocking=True).float().view(-1, 1)

            with torch.cuda.amp.autocast(enabled=use_amp):
                policy_logits, value_logits = model(planes)
                policy_loss = criterion(policy_logits, labels)
                value_loss = F.mse_loss(value_logits, values)
                loss = policy_loss + value_loss

            optimizer.zero_grad(set_to_none=True)
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            scaler.step(optimizer)
            scaler.update()

            bs           = labels.size(0)
            train_loss  += loss.item() * bs
            train_acc   += accuracy_top1(logits, labels) * bs
            train_samples += bs

            if batch_idx % LOG_INTERVAL == 0 or batch_idx == len(train_loader):
                print(
                    f"  Epoch {epoch:02d} | Batch {batch_idx:5d}/{len(train_loader)} | "
                    f"Loss {train_loss/max(1,train_samples):.4f} | "
                    f"Acc {train_acc/max(1,train_samples)*100:.2f}% | "
                    f"Skip {skipped}"
                )

        avg_train_loss = train_loss / max(1, train_samples)
        avg_train_acc  = train_acc  / max(1, train_samples)

        # ════════════════════ VAL ══════════════════════
        model.eval()
        val_loss = val_acc = 0.0
        val_samples = 0

        with torch.no_grad():
            for batch in val_loader:
                planes, labels, values = batch[0], batch[1], batch[2]
                if (labels < 0).any() or (labels >= 4096).any():
                    continue

                planes = planes.to(device, non_blocking=True)
                labels = labels.to(device, non_blocking=True)
                values = values.to(device, non_blocking=True).float().view(-1, 1)

                with torch.cuda.amp.autocast(enabled=use_amp):
                    policy_logits, value_logits = model(planes)
                    policy_loss = criterion(policy_logits, labels)
                    value_loss = F.mse_loss(value_logits, values)
                    loss = policy_loss + value_loss

                bs          = labels.size(0)
                val_loss   += loss.item() * bs
                val_acc    += accuracy_top1(policy_logits, labels) * bs
                val_samples += bs

        avg_val_loss = val_loss / max(1, val_samples)
        avg_val_acc  = val_acc  / max(1, val_samples)

        scheduler.step(avg_val_loss)
        current_lr = optimizer.param_groups[0]["lr"]

        print(
            f"\nEpoch {epoch:02d} [{time.time()-t_epoch:.0f}s] | "
            f"Train {avg_train_loss:.4f}/{avg_train_acc*100:.2f}% | "
            f"Val {avg_val_loss:.4f}/{avg_val_acc*100:.2f}% | "
            f"LR {current_lr:.2e}"
        )
        print("-" * 80)

        # ── Lưu checkpoint mỗi epoch ─────────────────────────────────
        ckpt_path = os.path.join(CHECKPOINT_DIR, f"chess_model_epoch_{epoch}.pth")
        save_checkpoint(ckpt_path, epoch, model, optimizer, scheduler,
                        avg_val_loss, avg_val_acc)
        print(f"[CKPT] Lưu: {ckpt_path}")

        # ── Lưu best model ───────────────────────────────────────────
        if avg_val_loss < best_val_loss:
            best_val_loss = avg_val_loss
            save_checkpoint(best_path, epoch, model, optimizer, scheduler,
                            avg_val_loss, avg_val_acc)
            print(f"[BEST] best_model.pth cập nhật → val_loss={best_val_loss:.4f}")

    print(f"\n===== HOÀN TẤT =====")
    print(f"Best val_loss = {best_val_loss:.4f}")
    print(f"Best model   → {best_path}")


# ==============================================================
if __name__ == "__main__":
    main()
