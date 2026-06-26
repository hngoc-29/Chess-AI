#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include "mcts.hpp"
#include "ChessEnv.cpp"

namespace {

std::filesystem::path resolve_model_path(int argc, char** argv) {
    if (argc > 1 && argv[1] != nullptr && std::string(argv[1]) != "") {
        return std::filesystem::path(argv[1]);
    }

    const std::filesystem::path cwd = std::filesystem::current_path();
    std::vector<std::filesystem::path> candidates = {
        cwd / "data" / "best_model_traced.pt",
        cwd / "AI" / "data" / "best_model_traced.pt",
    };

    if (argv[0] != nullptr) {
        const std::filesystem::path exe_path = argv[0];
        const std::filesystem::path exe_dir = exe_path.parent_path().empty() ? cwd : exe_path.parent_path();
        candidates.push_back(exe_dir / ".." / ".." / "data" / "best_model_traced.pt");
        candidates.push_back(exe_dir / ".." / ".." / "AI" / "data" / "best_model_traced.pt");
        candidates.push_back(exe_dir / ".." / "data" / "best_model_traced.pt");
    }

    for (const auto& candidate : candidates) {
        if (std::filesystem::exists(candidate)) {
            return candidate;
        }
    }

    return candidates.empty() ? std::filesystem::path("data/best_model_traced.pt") : candidates.front();
}

}  // namespace

int main(int argc, char** argv) {
    std::cout << "========================================================\n";
    std::cout << "          CHESS ENGINE AI - MONTE CARLO TREE SEARCH     \n";
    std::cout << "========================================================\n";

    const std::string model_path = resolve_model_path(argc, argv).string();

    constexpr int simulations = 1600;
    constexpr float c_puct = 1.5f;
    MCTS bot(model_path, simulations, c_puct);

    ChessEnv env;
    chess::Movelist legal_moves;

    std::cout << "\nTrò chơi bắt đầu! Bạn cầm quân TRẮNG đi trước.\n";
    std::cout << "Nhập nước đi của bạn theo chuẩn UCI (Ví dụ: e2e4, g1f3):\n";

    while (!env.is_terminal()) {
        env.get_legal_moves(legal_moves);
        if (legal_moves.empty()) {
            std::cout << "Trận đấu kết thúc!\n";
            break;
        }

        std::string user_input;
        std::cout << "\nLượt của bạn [UCI]> ";
        std::cin >> user_input;

        if (user_input == "exit" || user_input == "quit") {
            break;
        }

        bool valid_move = false;
        chess::Move player_move;
        for (int i = 0; i < legal_moves.size(); ++i) {
            if (chess::uci::moveToUci(legal_moves[i]) == user_input) {
                valid_move = true;
                player_move = legal_moves[i];
                break;
            }
        }

        if (!valid_move) {
            std::cout << "❌ Nước đi không hợp lệ hoặc sai luật! Vui lòng nhập lại.\n";
            continue;
        }

        env.step(player_move);
        std::cout << "\nBàn cờ sau nước đi của người chơi:\n";
        std::cout << env.get_board() << "\n";

        if (env.is_terminal()) {
            std::cout << "Chúc mừng! Bạn đã thắng Bot.\n";
            break;
        }

        std::cout << "🤖 AI đang suy nghĩ (Duyệt cây MCTS)... \n";
        const std::string ai_move_uci = bot.search(env);
        std::cout << "👉 AI quyết định đi nước: " << ai_move_uci << "\n";

        chess::Movelist ai_legal_moves;
        env.get_legal_moves(ai_legal_moves);

        chess::Move ai_move = chess::uci::uciToMove(env.get_board(), ai_move_uci);
        bool ai_move_is_valid = false;
        for (int i = 0; i < ai_legal_moves.size(); ++i) {
            if (ai_legal_moves[i] == ai_move) {
                ai_move_is_valid = true;
                break;
            }
        }
        if (!ai_move_is_valid) {
            if (!ai_legal_moves.empty()) {
                ai_move = ai_legal_moves[0];
            }
        }
        env.step(ai_move);
        std::cout << "\nBàn cờ sau nước đi của AI:\n";
        std::cout << env.get_board() << "\n";
    }

    std::cout << "Cảm ơn bạn đã chơi thử nghiệm!\n";
    return 0;
}
