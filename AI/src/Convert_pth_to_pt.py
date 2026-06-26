import os
from pathlib import Path
from typing import Dict


def resolve_model_paths(project_root: Path | None = None) -> Dict[str, Path]:
    project_root = Path(project_root or Path(__file__).resolve().parents[1]).expanduser().resolve()

    candidate_roots = [project_root]
    if project_root.name != "AI":
        candidate_roots.append(project_root / "AI")
    else:
        candidate_roots.append(project_root.parent)

    for root in candidate_roots:
        for rel_path in [Path("data") / "best_model.pth", Path("best_model.pth"), Path("models") / "best_model.pth"]:
            candidate = root / rel_path
            if candidate.exists():
                pth_model_path = candidate
                break
        else:
            continue
        break
    else:
        default_root = project_root if (project_root / "data").exists() else (project_root / "AI")
        pth_model_path = default_root / "data" / "best_model.pth"

    pt_output_path = pth_model_path.with_name(f"{pth_model_path.stem}_traced.pt")
    return {"pth_model_path": pth_model_path, "pt_output_path": pt_output_path}


# 1. Định nghĩa cấu trúc mạng (bắt buộc phải giống hệt lúc train trên Colab)
def _build_model():
    import torch
    import torch.nn as nn
    import torch.nn.functional as F

    class ResidualBlock(nn.Module):
        def __init__(self, channels: int, dropout: float = 0.3):
            super().__init__()
            self.conv1 = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
            self.bn1 = nn.BatchNorm2d(channels)
            self.dropout = nn.Dropout2d(p=dropout)
            self.conv2 = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
            self.bn2 = nn.BatchNorm2d(channels)

        def forward(self, x):
            out = F.relu(self.bn1(self.conv1(x)))
            out = self.dropout(out)
            out = self.bn2(self.conv2(out))
            return F.relu(out + x)

    class ChessPolicyNet(nn.Module):
        def __init__(self, num_blocks: int = 6, hidden_channels: int = 128, dropout: float = 0.3):
            super().__init__()
            self.conv_init = nn.Conv2d(12, hidden_channels, 3, padding=1, bias=False)
            self.bn_init = nn.BatchNorm2d(hidden_channels)
            self.blocks = nn.ModuleList([ResidualBlock(hidden_channels, dropout) for _ in range(num_blocks)])
            self.policy_conv = nn.Conv2d(hidden_channels, 32, 1, bias=False)
            self.policy_bn = nn.BatchNorm2d(32)
            self.fc = nn.Linear(32 * 64, 4096)

        def forward(self, x):
            out = F.relu(self.bn_init(self.conv_init(x)))
            for block in self.blocks:
                out = block(out)
            policy = F.relu(self.policy_bn(self.policy_conv(out)))
            return self.fc(policy.flatten(1))

    return ChessPolicyNet


def convert(project_root: Path | None = None):
    import torch

    paths = resolve_model_paths(project_root)
    pth_model_path = paths["pth_model_path"]
    pt_output_path = paths["pt_output_path"]

    if not pth_model_path.exists():
        print(f"❌ Không tìm thấy file {pth_model_path} ở thư mục hiện tại!")
        return

    print("-> Đang khởi tạo model...")
    device = torch.device("cpu")
    ChessPolicyNet = _build_model()

    model = ChessPolicyNet(num_blocks=6, hidden_channels=128, dropout=0.0).to(device)

    print(f"-> Đang tải trọng số từ {pth_model_path}...")
    checkpoint = torch.load(pth_model_path, map_location=device)

    if "model_state_dict" in checkpoint:
        model.load_state_dict(checkpoint["model_state_dict"])
    else:
        model.load_state_dict(checkpoint)

    model.eval()

    print("-> Đang thực hiện Tracing bằng TorchScript...")
    dummy_input = torch.randn(1, 12, 8, 8, dtype=torch.float32).to(device)

    with torch.no_grad():
        traced_model = torch.jit.trace(model, dummy_input)

    pt_output_path.parent.mkdir(parents=True, exist_ok=True)
    traced_model.save(pt_output_path)
    print(f"✅ THÀNH CÔNG! Đã tạo file: {pt_output_path}")
    print("Sẵn sàng nạp file này vào C++ qua LibTorch.")

if __name__ == "__main__":
    convert()
