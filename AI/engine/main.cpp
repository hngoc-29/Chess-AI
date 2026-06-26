#include <iostream>
#include <string>

#include "mcts.hpp"
#include "ChessEnv.cpp"

int main() {
    std::cout << "========================================================\n";
    std::cout << "          CHESS ENGINE AI - MONTE CARLO TREE SEARCH     \n";
    std::cout << "========================================================\n";

    const std::string model_path = "/home/hn/Code/Python/ChessAI/AI/data/best_model_traced.pt";

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
