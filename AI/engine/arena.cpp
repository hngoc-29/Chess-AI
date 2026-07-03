// arena.cpp
//
// Head-to-head evaluation match between two TorchScript models
// (model_a = candidate, e.g. the model just trained this generation;
//  model_b = reference,  e.g. the current best_model_traced.pt).
//
// Unlike selfplay.cpp (which generates *training* data with an exploring,
// noisy, temperature-sampling model), arena.cpp is only used to decide
// "is the new model actually stronger?" before we let it overwrite the
// current best model. So it deliberately plays differently:
//   - Dirichlet noise is OFF on both bots (see MCTS::set_dirichlet_enabled).
//   - Moves are picked greedily (argmax visit count), not temperature-sampled.
//   - Colors alternate every game so neither model always plays White.
//   - A handful of random opening plies (no NN needed) keep games from being
//     100% identical when the same two models are re-matched.
//
// Output: progress lines to stdout plus one machine-parseable
//   "[Arena] RESULT model_a_wins=W model_b_wins=L draws=D games=N a_score=S"
// line, and optionally a small JSON summary file (--output).

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <random>
#include <sstream>
#include <string>
#include <vector>

#include "mcts.hpp"
#include "ChessEnv.cpp"

namespace {

constexpr int      kDefaultSimulations        = 200;
constexpr int       kDefaultGames              = 40;
constexpr int      kDefaultMaxMoves            = 512;
constexpr int      kDefaultOpeningRandomPlies  = 6;
constexpr unsigned kDefaultSeed                = 1234;
// Disabled by default: arena is mainly about who's stronger, not speed.
// Pass --resign_thresh -0.95 (etc.) to speed up lopsided games.
constexpr float    kDefaultResignThresh        = -1.0f;
constexpr int      kDefaultMinResignPly        = 20;

using Clock = std::chrono::steady_clock;
using Ms    = std::chrono::milliseconds;

inline long long elapsed_ms(const Clock::time_point& t0) {
    return std::chrono::duration_cast<Ms>(Clock::now() - t0).count();
}

// Same action-index scheme as selfplay.cpp / mcts.cpp. Duplicated here on
// purpose: this project compiles each engine .cpp as a separate translation
// unit precisely so anonymous-namespace helpers like this one don't collide
// at link time (see the comment block in CMakeLists.txt).
constexpr int kPromoOffset = 4096;

int make_action_index(const chess::Move& move) {
    const int from_sq = static_cast<int>(move.from().index());
    const int to_sq   = static_cast<int>(move.to().index());

    if (move.typeOf() == chess::Move::PROMOTION) {
        const chess::PieceType promo = move.promotionType();
        int promo_idx = -1;
        if      (promo == chess::PieceType::KNIGHT) promo_idx = 0;
        else if (promo == chess::PieceType::BISHOP) promo_idx = 1;
        else if (promo == chess::PieceType::ROOK)   promo_idx = 2;
        if (promo_idx >= 0) {
            return kPromoOffset + promo_idx * 64 + to_sq;
        }
    }
    return from_sq * 64 + to_sq;
}

chess::Move action_index_to_move(const ChessEnv& env, int action_idx) {
    chess::Movelist legal;
    env.get_legal_moves(legal);
    for (const auto& m : legal) {
        if (make_action_index(m) == action_idx) return m;
    }
    return chess::Move::NO_MOVE;
}

// Greedy move choice: argmax visit count. No temperature — arena games
// should reflect each model's genuinely strongest play, not exploration.
chess::Move best_move_from_counts(const ChessEnv& env,
                                   const std::vector<std::pair<int, int>>& counts) {
    if (counts.empty()) return chess::Move::NO_MOVE;
    int best_a = counts[0].first;
    int best_v = counts[0].second;
    for (const auto& [a, v] : counts) {
        if (v > best_v) { best_v = v; best_a = a; }
    }
    return action_index_to_move(env, best_a);
}

struct MatchTally {
    int model_a_wins = 0;
    int model_b_wins = 0;
    int draws        = 0;
};

void print_usage(const char* argv0) {
    std::cerr << "Usage: " << argv0
              << " --model_a <path> --model_b <path>"
              << " [--games <n>] [--simulations <n>] [--max_moves <n>]"
              << " [--opening_random_plies <n>] [--seed <n>]"
              << " [--resign_thresh <float>] [--min_resign_ply <n>]"
              << " [--output <path>]\n"
              << "  model_a : candidate model (e.g. model_gen_N.pt just trained)\n"
              << "  model_b : reference model (e.g. current best_model_traced.pt)\n"
              << "  Colors alternate every game. Prints a '[Arena] RESULT ...' line\n"
              << "  and, if --output is given, a small JSON summary with a_score.\n";
}

}  // namespace

int main(int argc, char** argv) {
    std::string model_a_path, model_b_path, output_path;
    int      games                = kDefaultGames;
    int      simulations          = kDefaultSimulations;
    int      max_moves            = kDefaultMaxMoves;
    int      opening_random_plies = kDefaultOpeningRandomPlies;
    unsigned seed                 = kDefaultSeed;
    float    resign_thresh        = kDefaultResignThresh;
    int      min_resign_ply       = kDefaultMinResignPly;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if      (arg == "--model_a"              && i + 1 < argc) model_a_path         = argv[++i];
        else if (arg == "--model_b"              && i + 1 < argc) model_b_path         = argv[++i];
        else if (arg == "--games"                && i + 1 < argc) games                = std::stoi(argv[++i]);
        else if (arg == "--simulations"          && i + 1 < argc) simulations          = std::stoi(argv[++i]);
        else if (arg == "--max_moves"            && i + 1 < argc) max_moves            = std::stoi(argv[++i]);
        else if (arg == "--opening_random_plies" && i + 1 < argc) opening_random_plies = std::stoi(argv[++i]);
        else if (arg == "--seed"                 && i + 1 < argc) seed                 = static_cast<unsigned>(std::stoul(argv[++i]));
        else if (arg == "--resign_thresh"        && i + 1 < argc) resign_thresh        = std::stof(argv[++i]);
        else if (arg == "--min_resign_ply"       && i + 1 < argc) min_resign_ply       = std::stoi(argv[++i]);
        else if (arg == "--output"               && i + 1 < argc) output_path          = argv[++i];
        else { print_usage(argv[0]); return 1; }
    }

    if (model_a_path.empty() || model_b_path.empty()) {
        print_usage(argv[0]);
        return 1;
    }
    if (games <= 0) {
        std::cerr << "[ERROR] --games must be > 0\n";
        return 1;
    }

    std::cout << "[Arena] ============================================================\n";
    std::cout << "[Arena] Starting evaluation match\n";
    std::cout << "[Arena]   model_a (candidate)  = " << model_a_path << "\n";
    std::cout << "[Arena]   model_b (reference)  = " << model_b_path << "\n";
    std::cout << "[Arena]   games                = " << games << "\n";
    std::cout << "[Arena]   simulations           = " << simulations << " per move\n";
    std::cout << "[Arena]   max_moves            = " << max_moves << " per game\n";
    std::cout << "[Arena]   opening_random_plies = " << opening_random_plies << "\n";
    std::cout << "[Arena]   resign_thresh        = "
              << (resign_thresh > -1.0f ? std::to_string(resign_thresh) : std::string("disabled"))
              << "\n";
    std::cout << "[Arena] ============================================================\n";
    std::cout.flush();

    // Dirichlet noise exists purely to encourage exploration during
    // self-play training-data generation. For a strength evaluation we want
    // each model's genuinely best move instead, so disable it on both sides.
    MCTS bot_a(model_a_path, simulations, 1.5f, seed);
    bot_a.set_dirichlet_enabled(false);
    MCTS bot_b(model_b_path, simulations, 1.5f, seed + 1);
    bot_b.set_dirichlet_enabled(false);

    MatchTally tally;
    const auto run_t0 = Clock::now();

    for (int game_idx = 0; game_idx < games; ++game_idx) {
        // Alternate colors every game so the match is fair over the full set.
        const bool a_is_white = (game_idx % 2 == 0);
        std::mt19937 game_rng(seed + 1000u + static_cast<unsigned>(game_idx));

        ChessEnv env;
        float white_reward     = 0.0f;   // +1 white wins, -1 black wins, 0 draw
        bool  reached_terminal = false;

        for (int ply = 0; ply < max_moves; ++ply) {
            if (env.is_terminal()) { reached_terminal = true; break; }

            chess::Movelist legal;
            env.get_legal_moves(legal);
            if (legal.empty()) { reached_terminal = true; break; }

            const bool white_to_move = (env.get_board().sideToMove() == chess::Color::WHITE);
            MCTS& mover_bot = (white_to_move == a_is_white) ? bot_a : bot_b;

            chess::Move chosen = chess::Move::NO_MOVE;

            if (ply < opening_random_plies) {
                // Cheap random opening move (no NN call) so repeated matches
                // between the same two models don't all play out identically.
                std::uniform_int_distribution<int> dist(0, legal.size() - 1);
                chosen = legal[dist(game_rng)];
            } else {
                const auto counts = mover_bot.search_with_counts(env);

                if (resign_thresh > -1.0f && ply >= min_resign_ply) {
                    const float root_q = mover_bot.get_last_root_q();
                    if (root_q < resign_thresh) {
                        // The mover resigns → the OTHER color wins.
                        white_reward = white_to_move ? -1.0f : 1.0f;
                        reached_terminal = true;
                        break;
                    }
                }

                chosen = best_move_from_counts(env, counts);
            }

            if (chosen == chess::Move::NO_MOVE) {
                chosen = legal[0];  // final fallback, mirrors selfplay.cpp
            }

            const auto result = env.step(chosen);
            if (result.done) {
                // ChessEnv::terminal_reward() is already White-perspective
                // absolute (+1 white mates, -1 black mates, 0 draw) — no
                // sign trick needed here, unlike selfplay.cpp's per-sample
                // mover-relative training targets.
                white_reward = result.reward;
                reached_terminal = true;
                break;
            }
        }

        if (!reached_terminal) {
            // Hit max_moves without a decision — score as a draw.
            white_reward = 0.0f;
        }

        const bool white_won = white_reward > 0.0f;
        const bool black_won = white_reward < 0.0f;
        const bool a_won = (white_won && a_is_white) || (black_won && !a_is_white);
        const bool b_won = (white_won && !a_is_white) || (black_won && a_is_white);

        if (a_won)      ++tally.model_a_wins;
        else if (b_won) ++tally.model_b_wins;
        else            ++tally.draws;

        const int    done          = game_idx + 1;
        const double a_score_so_far = (tally.model_a_wins + 0.5 * tally.draws) / static_cast<double>(done);

        std::cout << "[Arena] game=" << done << "/" << games
                  << "  a_is_white=" << (a_is_white ? "yes" : "no")
                  << "  result=" << (a_won ? "A" : (b_won ? "B" : "draw"))
                  << "  tally A/B/D=" << tally.model_a_wins << "/"
                  << tally.model_b_wins << "/" << tally.draws
                  << "  a_score=" << std::fixed << std::setprecision(3) << a_score_so_far
                  << "\n";
        std::cout.flush();
    }

    const long long total_ms = elapsed_ms(run_t0);
    const double a_score = (tally.model_a_wins + 0.5 * tally.draws) / static_cast<double>(games);

    std::cout << "[Arena] ============================================================\n";
    std::cout << "[Arena] Match complete in " << (total_ms / 1000.0) << "s\n";
    std::cout << "[Arena] RESULT model_a_wins=" << tally.model_a_wins
              << " model_b_wins=" << tally.model_b_wins
              << " draws=" << tally.draws
              << " games=" << games
              << " a_score=" << std::fixed << std::setprecision(4) << a_score
              << "\n";
    std::cout << "[Arena] ============================================================\n";
    std::cout.flush();

    if (!output_path.empty()) {
        std::ofstream out(output_path, std::ios::trunc);
        if (out) {
            out << "{\n"
                << "  \"model_a\": \"" << model_a_path << "\",\n"
                << "  \"model_b\": \"" << model_b_path << "\",\n"
                << "  \"games\": " << games << ",\n"
                << "  \"model_a_wins\": " << tally.model_a_wins << ",\n"
                << "  \"model_b_wins\": " << tally.model_b_wins << ",\n"
                << "  \"draws\": " << tally.draws << ",\n"
                << "  \"a_score\": " << std::fixed << std::setprecision(6) << a_score << "\n"
                << "}\n";
        } else {
            std::cerr << "[WARN] Could not open output file for writing: " << output_path << "\n";
        }
    }

    return 0;
}
