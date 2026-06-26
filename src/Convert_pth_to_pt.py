import os
import torch
import torch.nn as nn
import torch.nn.functional as F

# 1. Định nghĩa cấu trúc mạng (bắt buộc phải giống hệt lúc train trên Colab)
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
    def __init__(self, num_blocks: int = 6, hidden_channels: int = 128, dropout: float = 0.3):
        super().__init__()
        self.conv_init  = nn.Conv2d(12, hidden_channels, 3, padding=1, bias=False)
        self.bn_init    = nn.BatchNorm2d(hidden_channels)
        self.blocks     = nn.ModuleList([ResidualBlock(hidden_channels, dropout) for _ in range(num_blocks)])
        self.policy_conv = nn.Conv2d(hidden_channels, 32, 1, bias=False)
        self.policy_bn   = nn.BatchNorm2d(32)
        self.fc          = nn.Linear(32 * 64, 4096)
    def forward(self, x):
        out = F.relu(self.bn_init(self.conv_init(x)))
        for block in self.blocks: 
            out = block(out)
        policy = F.relu(self.policy_bn(self.policy_conv(out)))
        return self.fc(policy.flatten(1))

def convert():
    # Cấu hình đường dẫn (Hãy chỉnh lại tên file .pth cho đúng với file của bạn nếu cần)
    pth_model_path = "/home/hn/Code/Python/ChessAI/data/best_model.pth" 
    pt_output_path = "/home/hn/Code/Python/ChessAI/data/best_model_traced.pt"

    if not os.path.exists(pth_model_path):
        print(f"❌ Không tìm thấy file {pth_model_path} ở thư mục hiện tại!")
        return

    print("-> Đang khởi tạo model...")
    device = torch.device("cpu") # Export trên CPU giúp LibTorch chạy linh hoạt hơn
    
    # Lúc Inference/Export đặt dropout = 0.0 để cố định kết quả dự đoán
    model = ChessPolicyNet(num_blocks=6, hidden_channels=128, dropout=0.0).to(device)

    print(f"-> Đang tải trọng số từ {pth_model_path}...")
    checkpoint = torch.load(pth_model_path, map_location=device)
    
    # Kiểm tra xem file lưu dưới dạng state_dict hay lưu cả checkpoint
    if "model_state_dict" in checkpoint:
        model.load_state_dict(checkpoint["model_state_dict"])
    else:
        model.load_state_dict(checkpoint)
        
    model.eval()

    print("-> Đang thực hiện Tracing bằng TorchScript...")
    # Tạo tensor giả lập đúng kích thước đầu vào (batch_size=1, planes=12, 8x8)
    dummy_input = torch.randn(1, 12, 8, 8, dtype=torch.float32).to(device)

    # Chuyển đổi mô hình thành đồ thị nhị phân
    with torch.no_grad():
        traced_model = torch.jit.trace(model, dummy_input)

    # Lưu lại thành file .pt
    traced_model.save(pt_output_path)
    print(f"✅ THÀNH CÔNG! Đã tạo file: {pt_output_path}")
    print("Sẵn sàng nạp file này vào C++ qua LibTorch.")

if __name__ == "__main__":
    convert()
