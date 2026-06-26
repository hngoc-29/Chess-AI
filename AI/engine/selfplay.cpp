#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "mcts.hpp"
#include "ChessEnv.cpp"

namespace {

constexpr std::size_t kStateSize = 768;
constexpr int kDefaultSimulations = 800;
constexpr int kDefaultGames = 500;
constexpr int kDefaultMaxMoves = 512;
constexpr int kDefaultLogEvery = 50;

struct SelfPlaySample {
    std::array<float, kStateSize> state{};
    float move_idx = 0.0f;
    float value = 0.0f;
};

std::vector<float> encode_state(const ChessEnv& env) {
    std::vector<float> features;
    env.write_stacked_state_tensor(features, 1);
    if (features.size() >= kStateSize) {
        features.resize(kStateSize);
    } else {
        features.resize(kStateSize, 0.0f);
    }
    return features;
}

int make_action_index(const chess::Move& move) {
    return static_cast<int>(move.from().index()) * 64 + static_cast<int>(move.to().index());
}

bool resolve_move(const ChessEnv& env, const std::string& uci, chess::Move& out_move) {
    chess::Movelist legal_moves;
    env.get_legal_moves(legal_moves);
    for (const auto& move : legal_moves) {
        if (chess::uci::moveToUci(move) == uci) {
            out_move = move;
            return true;
        }
    }
    return false;
}

void print_usage(const char* argv0) {
    std::cerr << "Usage: " << argv0 << " --model_path <path> --simulations <n> --games <n> --output <path> [--max_moves <n>] [--log_every <n>]\n";
}

}  // namespace

int main(int argc, char** argv) {
    std::string model_path = "best_model_traced.pt";
    int simulations = kDefaultSimulations;
    int games = kDefaultGames;
    std::string output_path = "selfplay_data.bin";
    int max_moves = kDefaultMaxMoves;
    int log_every = kDefaultLogEvery;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--model_path" && i + 1 < argc) {
            model_path = argv[++i];
        } else if (arg == "--simulations" && i + 1 < argc) {
            simulations = std::stoi(argv[++i]);
        } else if (arg == "--games" && i + 1 < argc) {
            games = std::stoi(argv[++i]);
        } else if (arg == "--output" && i + 1 < argc) {
            output_path = argv[++i];
        } else if (arg == "--max_moves" && i + 1 < argc) {
            max_moves = std::stoi(argv[++i]);
        } else if (arg == "--log_every" && i + 1 < argc) {
            log_every = std::stoi(argv[++i]);
        } else {
            print_usage(argv[0]);
            return 1;
        }
    }

    std::ofstream out(output_path, std::ios::binary | std::ios::trunc);
    if (!out) {
        std::cerr << "Không mở được file output: " << output_path << "\n";
        return 2;
    }

    std::cout << "[SelfPlay] model=" << model_path << " simulations=" << simulations
              << " games=" << games << " output=" << output_path
              << " log_every=" << log_every << "\n";

    std::size_t total_samples_written = 0;
    const auto start_time = std::chrono::steady_clock::now();

    for (int game_idx = 0; game_idx < games; ++game_idx) {
        ChessEnv env;
        std::vector<SelfPlaySample> samples;
        std::vector<float> sample_perspectives;
        bool game_finished = false;
        float terminal_reward_to_white = 0.0f;

        for (int ply = 0; ply < max_moves; ++ply) {
            if (env.is_terminal()) {
                break;
            }

            chess::Movelist legal_moves;
            env.get_legal_moves(legal_moves);
            if (legal_moves.empty()) {
                break;
            }

            MCTS bot(model_path, simulations, 1.5f);
            const std::string move_uci = bot.search(env);
            chess::Move chosen_move = chess::Move::NO_MOVE;
            if (!resolve_move(env, move_uci, chosen_move)) {
                chosen_move = legal_moves[0];
            }

            const bool side_to_move_is_white = env.get_board().sideToMove() == chess::Color::WHITE;
            sample_perspectives.push_back(side_to_move_is_white ? 1.0f : -1.0f);

            SelfPlaySample sample;
            const auto state_vec = encode_state(env);
            std::copy(state_vec.begin(), state_vec.end(), sample.state.begin());
            sample.move_idx = static_cast<float>(make_action_index(chosen_move));
            sample.value = 0.0f;
            samples.push_back(sample);

            const auto step_result = env.step(chosen_move);
            game_finished = step_result.done;
            if (game_finished) {
                terminal_reward_to_white = step_result.reward;
                break;
            }
        }

        for (std::size_t i = 0; i < samples.size(); ++i) {
            samples[i].value = sample_perspectives[i] * terminal_reward_to_white;
            out.write(reinterpret_cast<const char*>(&samples[i]), sizeof(samples[i]));
            ++total_samples_written;
        }

        if ((game_idx + 1) % log_every == 0 || game_idx + 1 == games) {
            const auto now = std::chrono::steady_clock::now();
            const auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - start_time).count();
            std::cout << "[SelfPlay] progress=" << (game_idx + 1) << "/" << games
                      << " games completed | samples_in_last_game=" << samples.size()
                      << " | total_samples_written=" << total_samples_written
                      << " | elapsed_ms=" << elapsed_ms << "\n";
        }
    }

    out.close();
    std::cout << "[SelfPlay] completed games=" << games << " output=" << output_path << "\n";
    return 0;
}
