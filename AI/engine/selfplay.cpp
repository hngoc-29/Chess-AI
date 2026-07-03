#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <random>
#include <sstream>
#include <string>
#include <vector>

#include "mcts.hpp"
#include "ChessEnv.cpp"

namespace {

constexpr std::size_t kStateSize          = 1280;  // 20 planes × 64 sq (matches ChessEnv::kStateSize)
constexpr int kDefaultSimulations         = 800;
constexpr int kDefaultGames               = 500;
constexpr int kDefaultMaxMoves            = 512;
constexpr int kDefaultLogEvery            = 50;  // Log every 50 games để giảm spam
constexpr int kDefaultTemperatureMoves    = 80;   // FIX: increased from 30 → 80 for more exploration   // use T=1 sampling for first N moves
constexpr unsigned kDefaultSeed          = 42;
// Resign when MCTS root Q < resign_thresh for current player.
// FIX: Enable resign to create decisive games and break draw loop.
// -0.90 means resign when losing with ~10% win probability (AlphaZero standard).
// -1.0 = disabled; typical value: -0.9.
// Resign is suppressed for the first kDefaultMinResignPly half-moves.
constexpr float kDefaultResignThresh     = -0.90f;  // Was: -1.0f (disabled)
constexpr int   kDefaultMinResignPly     = 20;

// ── Helpers ──────────────────────────────────────────────────────────────────

using Clock = std::chrono::steady_clock;
using Ms    = std::chrono::milliseconds;

inline long long elapsed_ms(const Clock::time_point& t0) {
    return std::chrono::duration_cast<Ms>(Clock::now() - t0).count();
}

std::string fmt_duration(long long ms) {
    long long s = ms / 1000;
    long long m = s / 60;  s %= 60;
    long long h = m / 60;  m %= 60;
    std::ostringstream oss;
    if (h > 0) oss << h << "h " << std::setw(2) << std::setfill('0') << m << "m " << std::setw(2) << s << "s";
    else if (m > 0) oss << m << "m " << std::setw(2) << std::setfill('0') << s << "s";
    else oss << s << "s";
    return oss.str();
}

std::string fmt_speed(double moves_per_s) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(2) << moves_per_s << " moves/s";
    return oss.str();
}

// ── Data structures ──────────────────────────────────────────────────────────

struct SelfPlaySample {
    std::array<float, kStateSize> state{};
    float move_idx = 0.0f;
    float value    = 0.0f;
};

std::vector<float> encode_state(const ChessEnv& env) {
    // Use 20-plane encoding: turn bit, castling, EP, repetition — matches Python encode_board()
    std::vector<float> features(kStateSize, 0.0f);
    env.write_nn_planes(features.data());
    return features;
}

// Start of the underpromotion slice within the action space (NUM_ACTIONS=4288
// total); matches Python's _PROMO_OFFSET. Underpromotion piece order (matches
// _PROMO_IDX): knight=0, bishop=1, rook=2. Queen promotions and normal moves
// stay in the 0..4095 from*64+to range.
constexpr int kPromoOffset = 4096;

int make_action_index(const chess::Move& move) {
    const int from_sq = static_cast<int>(move.from().index());
    const int to_sq   = static_cast<int>(move.to().index());

    // Underpromotion (knight/bishop/rook) maps into the 4096..4287 slice of
    // the action space; normal moves and queen promotions keep the original
    // from*64+to encoding. Mirrors Python move_to_idx()/_PROMO_IDX exactly.
    // NOTE: promotionType() is only meaningful when typeOf()==PROMOTION (see
    // chess-library src/move.hpp) — must guard on typeOf() first.
    if (move.typeOf() == chess::Move::PROMOTION) {
        const chess::PieceType promo = move.promotionType();
        int promo_idx = -1;
        if      (promo == chess::PieceType::KNIGHT) promo_idx = 0;
        else if (promo == chess::PieceType::BISHOP) promo_idx = 1;
        else if (promo == chess::PieceType::ROOK)   promo_idx = 2;
        // promo_idx stays -1 for QUEEN (and any unexpected piece), matching
        // Python's "idx is None" fallback to the plain from*64+to encoding.

        if (promo_idx >= 0) {
            return kPromoOffset + promo_idx * 64 + to_sq;
        }
    }
    return from_sq * 64 + to_sq;
}

bool resolve_move(const ChessEnv& env, const std::string& uci, chess::Move& out_move) {
    chess::Movelist legal;
    env.get_legal_moves(legal);
    for (const auto& m : legal) {
        if (chess::uci::moveToUci(m) == uci) {
            out_move = m;
            return true;
        }
    }
    return false;
}

/// Sample an action index from visit counts using temperature T=1.
/// counts: vector of (action_idx, visit_count)
/// Returns chosen action_idx, or -1 on edge case (all visits==0).
int sample_with_temperature(const std::vector<std::pair<int,int>>& counts,
                             std::mt19937& rng) {
    if (counts.empty()) return -1;

    // T=1: distribute proportional to visit_count
    std::vector<float> weights;
    weights.reserve(counts.size());
    float total = 0.0f;
    for (const auto& [aidx, visits] : counts) {
        float w = static_cast<float>(std::max(0, visits));
        weights.push_back(w);
        total += w;
    }

    if (total <= 0.0f) {
        // Edge case: all visit_count==0 → uniform
        std::uniform_int_distribution<std::size_t> dist(0, counts.size() - 1);
        return counts[dist(rng)].first;
    }

    std::uniform_real_distribution<float> dist(0.0f, total);
    float r = dist(rng);
    float cumsum = 0.0f;
    for (std::size_t i = 0; i < counts.size(); ++i) {
        cumsum += weights[i];
        if (r < cumsum) return counts[i].first;
    }
    return counts.back().first;
}

chess::Move action_index_to_move(const ChessEnv& env, int action_idx) {
    chess::Movelist legal;
    env.get_legal_moves(legal);
    for (const auto& m : legal) {
        if (make_action_index(m) == action_idx) return m;
    }
    return chess::Move::NO_MOVE;
}

void print_usage(const char* argv0) {
    std::cerr << "Usage: " << argv0
              << " --model_path <path> --simulations <n>"
              << " --games <n> --output <path>"
              << " [--max_moves <n>] [--log_every <n>]"
              << " [--temperature_moves <n>] [--seed <n>]"
              << " [--resign_thresh <float>] [--min_resign_ply <n>]\n"
              << "  resign_thresh: MCTS root Q below this → resign (default -1.0 = disabled)\n"
              << "  min_resign_ply: do not resign before this half-move (default 20)\n";
}

}  // namespace

// ── main ─────────────────────────────────────────────────────────────────────

int main(int argc, char** argv) {
    std::string model_path   = "best_model_traced.pt";
    int simulations          = kDefaultSimulations;
    int games                = kDefaultGames;
    std::string output_path  = "selfplay_data.bin";
    int max_moves            = kDefaultMaxMoves;
    int log_every            = kDefaultLogEvery;
    int temperature_moves    = kDefaultTemperatureMoves;
    unsigned seed            = kDefaultSeed;
    float resign_thresh      = kDefaultResignThresh;  // < -1.0 = disabled
    int   min_resign_ply     = kDefaultMinResignPly;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if      (arg == "--model_path"       && i + 1 < argc) model_path        = argv[++i];
        else if (arg == "--simulations"      && i + 1 < argc) simulations       = std::stoi(argv[++i]);
        else if (arg == "--games"            && i + 1 < argc) games             = std::stoi(argv[++i]);
        else if (arg == "--output"           && i + 1 < argc) output_path       = argv[++i];
        else if (arg == "--max_moves"        && i + 1 < argc) max_moves         = std::stoi(argv[++i]);
        else if (arg == "--log_every"        && i + 1 < argc) log_every         = std::stoi(argv[++i]);
        else if (arg == "--temperature_moves"&& i + 1 < argc) temperature_moves = std::stoi(argv[++i]);
        else if (arg == "--seed"             && i + 1 < argc) seed              = static_cast<unsigned>(std::stoul(argv[++i]));
        else if (arg == "--resign_thresh"    && i + 1 < argc) resign_thresh     = std::stof(argv[++i]);
        else if (arg == "--min_resign_ply"   && i + 1 < argc) min_resign_ply    = std::stoi(argv[++i]);
        else { print_usage(argv[0]); return 1; }
    }

    std::mt19937 rng(seed);

    // ── Banner ──────────────────────────────────────────────────────────────
    std::cout << "[SelfPlay] ============================================================\n";
    std::cout << "[SelfPlay] Starting self-play session\n";
    std::cout << "[SelfPlay]   model             = " << model_path  << "\n";
    std::cout << "[SelfPlay]   simulations       = " << simulations << " per move\n";
    std::cout << "[SelfPlay]   games             = " << games       << "\n";
    std::cout << "[SelfPlay]   max_moves         = " << max_moves   << " per game\n";
    std::cout << "[SelfPlay]   log_every         = " << log_every   << " games\n";
    std::cout << "[SelfPlay]   temperature_moves = " << temperature_moves << " (T=1 sampling)\n";
    std::cout << "[SelfPlay]   seed              = " << seed        << "\n";
    std::cout << "[SelfPlay]   resign_thresh     = "
              << (resign_thresh > -1.0f
                  ? std::to_string(resign_thresh)
                  : std::string("disabled"))
              << "\n";
    std::cout << "[SelfPlay]   min_resign_ply    = " << min_resign_ply << "\n";
    std::cout << "[SelfPlay]   output            = " << output_path << "\n";
    std::cout << "[SelfPlay] ============================================================\n";
    std::cout.flush();

    // ── Open output file ─────────────────────────────────────────────────────
    std::ofstream out(output_path, std::ios::binary | std::ios::trunc);
    if (!out) {
        std::cerr << "[ERROR] Cannot open output file: " << output_path << "\n";
        std::cerr.flush();
        return 2;
    }

    // ── Load model ONCE ─────────────────────────────────────────────────────
    std::cout << "[SelfPlay] Loading TorchScript model...\n";
    std::cout.flush();
    const auto model_load_t0 = Clock::now();
    // seed passed through so Dirichlet noise is reproducible
    // c_puct=1.5 (was 1.0) — tăng exploration để thoát khỏi draw loops.
    // AlphaZero dùng c_puct=1.25-2.0; 1.5 là hợp lý cho chess self-play.
    MCTS bot(model_path, simulations, 1.5f, seed);
    const long long model_load_ms = elapsed_ms(model_load_t0);
    std::cout << "[SelfPlay] Model loaded in " << fmt_duration(model_load_ms)
              << " (" << model_load_ms << " ms)\n";
    std::cout.flush();

    // ── Self-play loop ───────────────────────────────────────────────────────
    std::size_t total_samples = 0;
    std::size_t total_plies   = 0;
    int         draws         = 0;
    int         decisive      = 0;
    const auto  run_t0        = Clock::now();

    for (int game_idx = 0; game_idx < games; ++game_idx) {
        const auto game_t0 = Clock::now();

        ChessEnv env;
        std::vector<SelfPlaySample> samples;
        std::vector<float> perspectives;
        float terminal_reward = 0.0f;
        int   plies           = 0;

        for (int ply = 0; ply < max_moves; ++ply) {
            if (env.is_terminal()) break;

            chess::Movelist legal;
            env.get_legal_moves(legal);
            if (legal.empty()) break;

            // search_with_counts runs MCTS and returns (action_idx, visit_count) pairs
            const auto counts = bot.search_with_counts(env);

            // ── Resign check ─────────────────────────────────────────────────
            // bot.get_last_root_q() returns the Q-value at the root of the MCTS
            // tree (cached by search_with_counts).  A very negative Q means the
            // current player is losing from the model's perspective.
            // resign_thresh == -1.0 disables resign (default for robustness).
            if (resign_thresh > -1.0f && ply >= min_resign_ply) {
                const float root_q = bot.get_last_root_q();
                if (root_q < resign_thresh) {
                    // The side to move here is the one resigning → they lose,
                    // so the OTHER color wins. terminal_reward must stay
                    // WHITE-PERSPECTIVE ABSOLUTE (+1 white wins / -1 black
                    // wins / 0 draw) — exactly the convention
                    // ChessEnv::step()'s `result.reward` uses for checkmate,
                    // because "samples[i].value = perspectives[i] *
                    // terminal_reward" below assumes that convention.
                    //
                    // BUGFIX: this used to be hardcoded to -1.0f regardless
                    // of which color resigned. That only happened to be
                    // correct when White resigned; whenever Black resigned it
                    // silently flipped the value label of every sample in the
                    // entire game (White's positions logged as losses instead
                    // of wins, and vice versa for Black) — a real source of
                    // mislabeled training data any time resign is enabled.
                    const bool resigning_side_is_white =
                        (env.get_board().sideToMove() == chess::Color::WHITE);
                    terminal_reward = resigning_side_is_white ? -1.0f : 1.0f;
                    ++plies;  // count the resign ply
                    // Debug: uncomment để xem resign details
                    // std::cout << "[SelfPlay] resign at ply=" << ply
                    //           << " root_q=" << root_q
                    //           << " thresh=" << resign_thresh << "\n";
                    break;
                }
            }
            // ─────────────────────────────────────────────────────────────────

            chess::Move chosen = chess::Move::NO_MOVE;
            int chosen_action  = -1;

            if (counts.empty()) {
                chosen = legal[0];
                chosen_action = make_action_index(chosen);
            } else if (ply < temperature_moves) {
                // Temperature sampling for first N moves
                chosen_action = sample_with_temperature(counts, rng);
                if (chosen_action >= 0) {
                    chosen = action_index_to_move(env, chosen_action);
                }
                if (chosen == chess::Move::NO_MOVE) {
                    // Fallback: argmax
                    int best_a = counts[0].first;
                    int best_v = counts[0].second;
                    for (const auto& [a, v] : counts) {
                        if (v > best_v) { best_v = v; best_a = a; }
                    }
                    chosen = action_index_to_move(env, best_a);
                    chosen_action = best_a;
                }
            } else {
                // Argmax
                int best_a = counts[0].first;
                int best_v = counts[0].second;
                for (const auto& [a, v] : counts) {
                    if (v > best_v) { best_v = v; best_a = a; }
                }
                chosen_action = best_a;
                chosen = action_index_to_move(env, chosen_action);
            }

            // Final fallback
            if (chosen == chess::Move::NO_MOVE) {
                chosen = legal[0];
                chosen_action = make_action_index(chosen);
            }

            const bool is_white = env.get_board().sideToMove() == chess::Color::WHITE;
            perspectives.push_back(is_white ? 1.0f : -1.0f);

            SelfPlaySample s;
            const auto state_vec = encode_state(env);
            std::copy(state_vec.begin(), state_vec.end(), s.state.begin());
            s.move_idx = static_cast<float>(chosen_action);
            s.value    = 0.0f;
            samples.push_back(s);

            const auto result = env.step(chosen);
            ++plies;
            if (result.done) {
                terminal_reward = result.reward;
                break;
            }
        }

        // Assign values and write to disk
        for (std::size_t i = 0; i < samples.size(); ++i) {
            samples[i].value = perspectives[i] * terminal_reward;
            out.write(reinterpret_cast<const char*>(&samples[i]), sizeof(samples[i]));
            ++total_samples;
        }

        // Flush after each game to survive Kaggle OOM / timeout kill
        out.flush();

        total_plies += static_cast<std::size_t>(plies);
        if (terminal_reward == 0.0f) ++draws;
        else ++decisive;

        // ── Per-game log ─────────────────────────────────────────────────────
        if ((game_idx + 1) % log_every == 0 || game_idx + 1 == games) {
            const long long run_ms    = elapsed_ms(run_t0);
            const long long game_ms   = elapsed_ms(game_t0);
            const int       done      = game_idx + 1;
            const int       remaining = games - done;

            const double avg_ms_per_game = static_cast<double>(run_ms) / done;
            const long long eta_ms       = static_cast<long long>(avg_ms_per_game * remaining);

            const double run_s        = run_ms / 1000.0;
            const double moves_per_s  = (run_s > 0.0) ? (static_cast<double>(total_plies) / run_s) : 0.0;
            const double games_per_hr = (run_s > 0.0) ? (done / run_s * 3600.0) : 0.0;

            const char* outcome = (terminal_reward > 0.0f) ? "white wins"
                                : (terminal_reward < 0.0f) ? "black wins"
                                :                             "draw";

            std::cout << "[SelfPlay] game=" << done << "/" << games
                      << "  plies=" << plies
                      << "  outcome=" << outcome
                      << "  samples=" << samples.size()
                      << "  total_samples=" << total_samples
                      << "\n";
            std::cout << "[SelfPlay] progress="
                      << std::fixed << std::setprecision(1)
                      << (100.0 * done / games) << "%"
                      << "  elapsed=" << fmt_duration(run_ms)
                      << "  game_time=" << game_ms << "ms"
                      << "  eta=" << fmt_duration(eta_ms)
                      << "\n";
            std::cout << "[SelfPlay] speed=" << fmt_speed(moves_per_s)
                      << "  games/hr="
                      << std::fixed << std::setprecision(1) << games_per_hr
                      << "  decisive=" << decisive
                      << "  draws=" << draws
                      << "\n";
            std::cout.flush();
        }
    }

    // ── Final summary ────────────────────────────────────────────────────────
    const long long total_ms = elapsed_ms(run_t0);
    const double    total_s  = total_ms / 1000.0;
    const double    avg_plies = (games > 0) ? (static_cast<double>(total_plies) / games) : 0.0;
    const double    mps       = (total_s > 0.0) ? (static_cast<double>(total_plies) / total_s) : 0.0;

    std::cout << "[SelfPlay] ============================================================\n";
    std::cout << "[SelfPlay] Session complete\n";
    std::cout << "[SelfPlay]   games          = " << games          << "\n";
    std::cout << "[SelfPlay]   total_samples  = " << total_samples  << "\n";
    std::cout << "[SelfPlay]   total_plies    = " << total_plies    << "\n";
    std::cout << "[SelfPlay]   avg_plies/game = "
              << std::fixed << std::setprecision(1) << avg_plies   << "\n";
    std::cout << "[SelfPlay]   decisive       = " << decisive        << "\n";
    std::cout << "[SelfPlay]   draws          = " << draws           << "\n";
    std::cout << "[SelfPlay]   total_time     = " << fmt_duration(total_ms)
              << " (" << total_ms << " ms)\n";
    std::cout << "[SelfPlay]   throughput     = " << fmt_speed(mps) << "\n";
    std::cout << "[SelfPlay]   output         = " << output_path    << "\n";
    std::cout << "[SelfPlay] ============================================================\n";
    std::cout.flush();

    out.close();
    return 0;
}