import torch
import chess
import numpy as np
import torch.nn as nn
import torch.nn.functional as F
import random
from datetime import datetime

# =========================
# PRETTY CONSOLE LOG
# =========================
RUN_COUNT = 0

def line(char="=", width=72):
    print(char * width)

def title(text):
    line("=")
    print(text)
    line("=")

def section(text):
    print(f"\n--- {text} ---")

def log(text=""):
    print(text)

def format_board(board: chess.Board):
    # Bàn cờ đẹp hơn chữ thô
    try:
        return board.unicode(borders=True)
    except:
        return str(board)

# =========================
# MODEL
# =========================
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

# =========================
# BOARD -> PLANES
# =========================
def board_to_planes(board: chess.Board):
    planes = np.zeros((12, 8, 8), dtype=np.float32)
    piece_map = {
        chess.PAWN: 0, chess.KNIGHT: 1, chess.BISHOP: 2,
        chess.ROOK: 3, chess.QUEEN: 4, chess.KING: 5
    }

    for square in chess.SQUARES:
        piece = board.piece_at(square)
        if piece is not None:
            plane_idx = piece_map[piece.piece_type]
            if piece.color == chess.BLACK:
                plane_idx += 6
            row = chess.square_rank(square)
            col = chess.square_file(square)
            planes[plane_idx, row, col] = 1.0

    if board.turn == chess.BLACK:
        planes = np.flip(planes, axis=(1, 2)).copy()

    return torch.from_numpy(planes).unsqueeze(0)

# =========================
# MOVE SCORING
# =========================
def move_to_index(move: chess.Move, board: chess.Board):
    from_sq = move.from_square
    to_sq = move.to_square

    if board.turn == chess.BLACK:
        from_sq = 63 - from_sq
        to_sq = 63 - to_sq

    return from_sq * 64 + to_sq

def suggest_top_moves(board: chess.Board, model, device, topk=5):
    if board.is_game_over():
        return []

    input_planes = board_to_planes(board).to(device)

    with torch.no_grad():
        logits = model(input_planes).squeeze(0).cpu().numpy()

    legal_moves = list(board.legal_moves)
    scored = []

    for move in legal_moves:
        idx = move_to_index(move, board)
        score = logits[idx]
        scored.append((score, move))

    scored.sort(key=lambda x: x[0], reverse=True)

    scores = np.array([s for s, _ in scored], dtype=np.float64)
    probs = np.exp(scores - scores.max())
    probs = probs / probs.sum()

    result = []
    for i in range(min(topk, len(scored))):
        score, move = scored[i]
        result.append((move.uci(), float(probs[i]) * 100.0, float(score)))

    return result

# =========================
# RANDOM POSITION
# =========================
def random_board(max_plies=20):
    board = chess.Board()
    plies = random.randint(0, max_plies)

    for _ in range(plies):
        if board.is_game_over():
            break
        moves = list(board.legal_moves)
        if not moves:
            break
        board.push(random.choice(moves))

    return board

# =========================
# LOAD MODEL
# =========================
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = ChessPolicyNet(num_blocks=6, hidden_channels=128, dropout=0.0).to(device)

BEST_MODEL_PATH = "/home/hn/Code/Python/ChessAI/data/best_model.pth"
checkpoint = torch.load(BEST_MODEL_PATH, map_location=device)

if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
    model.load_state_dict(checkpoint["model_state_dict"])
else:
    model.load_state_dict(checkpoint)

model.eval()

title("CHESS AI TESTER")
log(f"Thời gian: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
log(f"Thiết bị: {'CUDA' if torch.cuda.is_available() else 'CPU'}")
log("Đã tải thành công best_model.pth")
log("Nhập 'rand' để random FEN, Enter để dùng cờ khai cuộc, 'exit' để thoát")

# =========================
# MAIN LOOP
# =========================
while True:
    RUN_COUNT += 1
    line("-")
    print(f"Lần test #{RUN_COUNT}")
    line("-")

    fen = input("FEN> ").strip()

    if fen.lower() in ["exit", "quit", "q"]:
        log("Đã thoát chương trình.")
        break

    if fen.lower() == "rand":
        board = random_board(max_plies=20)
        section("Đã tạo thế cờ random")
    elif fen == "":
        board = chess.Board()
        section("Dùng thế cờ khai cuộc")
    else:
        try:
            board = chess.Board(fen)
            section("Dùng FEN đã nhập")
        except Exception as e:
            log(f"FEN không hợp lệ: {e}")
            continue

    print(format_board(board))
    log(f"\nFEN: {board.fen()}")

    top_moves = suggest_top_moves(board, model, device, topk=5)

    section("Kết quả gợi ý")
    if not top_moves:
        log("Không còn nước đi hợp lệ: ván cờ đã kết thúc.")
    else:
        for i, (uci, prob, score) in enumerate(top_moves, 1):
            log(f"{i:>2}. {uci:<6} | xác suất: {prob:6.2f}% | logit: {score:8.4f}")

    line("=")
