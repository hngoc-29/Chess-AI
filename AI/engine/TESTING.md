# Hướng dẫn test Engine Cờ vua MCTS

## 1. Yêu cầu môi trường

- CMake >= 3.12
- Compiler hỗ trợ C++17
- LibTorch đã được cài đặt hoặc tải vào thư mục `/content/libtorch` trên Colab, hoặc vào `engine/libtorch` trên máy local
- File mô hình TorchScript: `data/best_model_traced.pt`

## 2. Build project

### 2.1 Trên máy local

```bash
cd /home/hn/Code/Python/ChessAI/engine
cmake -S . -B build -DCMAKE_PREFIX_PATH=/home/hn/Code/Python/ChessAI/engine/libtorch
cmake --build build -j4
```

### 2.2 Trên Colab

```bash
cd /content/ChessAI/engine
cmake -S . -B build -DCMAKE_PREFIX_PATH=/content/libtorch
cmake --build build -j4
```

Nếu build thành công, sẽ tạo file thực thi:

```bash
engine/build/chess_mcts
engine/build/selfplay
```

## 3. Test cơ bản

### 3.1 Chạy chương trình interactive

```bash
cd /home/hn/Code/Python/ChessAI/engine/build
./chess_mcts
```

### 3.2 Test bằng input tự động

```bash
cd /home/hn/Code/Python/ChessAI/engine/build
printf 'e2e4\nexit\n' | ./chess_mcts
```

Kết quả mong đợi:
- Chương trình khởi động thành công
- Nhận nước đi `e2e4`
- AI trả về một nước đi hợp lệ
- Chương trình kết thúc đúng khi nhập `exit`

## 4. Test các tình huống quan trọng

### 4.1 Test nước đi hợp lệ

Nhập:

```text
e2e4
```

Kiểm tra:
- Nước đi được chấp nhận
- AI phản hồi một nước đi tiếp theo

### 4.2 Test nước đi không hợp lệ

Nhập:

```text
e2e5
```

Kiểm tra:
- Chương trình báo lỗi
- Yêu cầu nhập lại nước đi hợp lệ

### 4.3 Test lệnh thoát

Nhập:

```text
exit
```

Kiểm tra:
- Chương trình dừng ngay
- Không bị crash

## 5. Test kiểm tra mô hình

Nếu mô hình TorchScript không load được, chương trình vẫn nên chạy nhưng có thể dùng prior đều thay cho policy từ mạng.

Để kiểm tra mô hình:

```bash
ls /home/hn/Code/Python/ChessAI/data/best_model_traced.pt
```

Nếu file không tồn tại, cần kiểm tra lại đường dẫn model trong `main.cpp` hoặc `mcts.cpp`.

## 6. Test self-play

Sau khi build xong, bạn có thể thử chạy binary self-play:

```bash
cd /home/hn/Code/Python/ChessAI/engine/build
./selfplay --model_path /home/hn/Code/Python/ChessAI/data/best_model_traced.pt --simulations 50 --games 1 --output /tmp/selfplay_test.bin
```

Kiểm tra:
- chương trình chạy xong mà không crash
- file `/tmp/selfplay_test.bin` được tạo

## 7. Test sau khi sửa code

Sau mỗi thay đổi quan trọng, nên chạy lại ít nhất 2 bước:

```bash
cd /home/hn/Code/Python/ChessAI/engine
cmake --build build -j4
printf 'e2e4\nexit\n' | ./build/chess_mcts
```

## 8. Gợi ý kiểm tra thêm

- Thử các nước đi khác nhau như `g1f3`, `d2d4`
- Thử một vài trạng thái gần endgame
- Kiểm tra xem AI có luôn chọn nước đi hợp lệ không
- Nếu có thể, so sánh kết quả trước và sau khi chỉnh sửa

## 9. Nếu có lỗi

Nếu chương trình crash hoặc build lỗi, hãy kiểm tra:

1. Đường dẫn tới LibTorch
2. File `.pt` có tồn tại không
3. Compiler có hỗ trợ C++17 không
4. CMake có phát hiện đúng Torch không
5. Thư mục `engine/libtorch` hoặc `/content/libtorch` có đúng cấu trúc không
