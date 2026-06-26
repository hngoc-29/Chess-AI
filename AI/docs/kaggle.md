# Hướng dẫn chạy tự train trên Kaggle

## 1. Chuẩn bị notebook Kaggle

- Tạo notebook mới trên Kaggle.
- Bật accelerator: GPU T4 x2 (nếu có) hoặc GPU T4.
- Bật Internet để có thể tải LibTorch.

## 2. Clone hoặc upload dự án

Trong notebook, chạy:

```bash
!git clone https://github.com/<your-user>/ChessAI.git /kaggle/working/ChessAI
cd /kaggle/working/ChessAI
```

Nếu bạn đã có thư mục dự án trong workspace, có thể dùng luôn thư mục đó.

## 3. Cài dependency cơ bản

```bash
!pip install -q numpy torch==2.2.2
```

## 4. Chạy training

```bash
bash kaggle_train.sh
```

Nếu muốn tùy chỉnh tham số:

```bash
SIMULATIONS=200 GAMES=50 EPOCHS=2 BATCH_SIZE=128 LR=0.001 MAX_GENERATIONS=2 bash kaggle_train.sh
```

## 5. Output sẽ được lưu ở đâu

- Model mới: /kaggle/working/chess_outputs/model_gen_*.pt
- Best model: /kaggle/working/chess_outputs/best_model_traced.pt
- Replay self-play: /kaggle/working/chess_outputs/selfplay_gen_*.bin

## 6. Gợi ý cấu hình khởi đầu

- Với Kaggle GPU T4x2, cấu hình mạnh hơn nên dùng:
  - simulations: 400
  - games: 100
  - epochs: 3
  - batch_size: 256
  - max_generations: 3

- Nếu muốn chạy nhẹ hơn để tránh quá tải, giảm dần thành:
  - simulations: 200
  - games: 50
  - epochs: 2
  - batch_size: 128
  - max_generations: 2

## 7. Lưu ý

- Kaggle có giới hạn thời gian session, nên nên dùng tham số nhỏ ở lần đầu để kiểm tra.
- Nếu notebook bị disconnect, bạn vẫn có thể tiếp tục từ thư mục /kaggle/working.
- Nếu muốn lưu lâu hơn, download output về hoặc bật Kaggle Dataset / Drive sync.
