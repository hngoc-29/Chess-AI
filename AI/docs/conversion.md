# 4. Chuyển đổi .pth sang .pt (TorchScript)

## Mục tiêu

Chuyển mô hình PyTorch lưu dưới dạng `.pth` sang TorchScript `.pt` để dùng trong engine C++ qua LibTorch.

## File chính

- [src/Convert_pth_to_pt.py](../src/Convert_pth_to_pt.py)

## Quy trình

1. Đảm bảo file `.pth` tồn tại, ví dụ [data/best_model.pth](../data/best_model.pth).
2. Chạy script [src/Convert_pth_to_pt.py](../src/Convert_pth_to_pt.py).
3. Script sẽ tạo file [data/best_model_traced.pt](../data/best_model_traced.pt).

## Lưu ý

- Mạng phải có kiến trúc giống hệt với lúc train.
- Nên dùng `torch.jit.trace` với input giả lập.
- File kết quả dùng cho engine C++.

## Kết quả

File `.pt` được dùng trực tiếp trong:

- [engine/mcts.cpp](../engine/mcts.cpp)
- [engine/selfplay.cpp](../engine/selfplay.cpp)
