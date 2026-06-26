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

    class ChessPolicyNet(nn.Module):
        def __init__(self, num_actions: int = 4096):
            super().__init__()
            self.conv1 = nn.Conv2d(12, 64, kernel_size=3, padding=1)
            self.conv2 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
            self.conv3 = nn.Conv2d(128, 128, kernel_size=3, padding=1)
            self.fc1 = nn.Linear(128 * 8 * 8, 512)
            self.policy_head = nn.Linear(512, num_actions)
            self.value_head = nn.Linear(512, 1)

        def forward(self, x):
            x = F.relu(self.conv1(x))
            x = F.relu(self.conv2(x))
            x = F.relu(self.conv3(x))
            x = torch.flatten(x, start_dim=1)
            x = F.relu(self.fc1(x))
            policy_logits = self.policy_head(x)
            value_logit = self.value_head(x)
            return policy_logits, value_logit

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

    model = ChessPolicyNet().to(device)

    print(f"-> Đang tải trọng số từ {pth_model_path}...")
    checkpoint = torch.load(pth_model_path, map_location=device)

    if isinstance(checkpoint, dict):
        state_dict = checkpoint.get("model_state_dict") or checkpoint.get("model_state") or checkpoint
    else:
        state_dict = checkpoint

    if isinstance(state_dict, dict):
        try:
            model.load_state_dict(state_dict, strict=True)
        except RuntimeError:
            model.load_state_dict(state_dict, strict=False)
    else:
        raise TypeError("Checkpoint payload is not a state dict")

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
