#include <array>
#include <chrono>
#include <cmath>
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

constexpr std::size_t kStateSize     = 768;
constexpr int kDefaultSimulations    = 800;
constexpr int kDefaultGames          = 500;
constexpr int kDefaultMaxMoves       = 512;
constexpr int kDefaultLogEvery       = 10;
constexpr int kDefaultTemperatureMoves = 30;

// ── Helpers ──────────────────────────────────────────────────────────────────

using Clock    = std::chrono::steady_clock;
using Ms       = std::chrono::milliseconds;

inline long long elapsed_ms(const Clock::time_point& t0) {
    return std::chrono::duration_cast<Ms>(Clock::now() - t0).count();
}

// Format milliseconds as "1h 23m 45s" or "4m 05s" or "38s"
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

// Format throughput as "X.XX moves/s"
std::string fmt_speed(double moves_per_s) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(2) << moves_per_s << " moves/s";
    return oss.str();
}

int sample_action_from_counts(const std::vector<std::pair<int, int>>& counts, int temperature_moves, int ply, std::mt19937& rng) {
    if (counts.empty()) {
        return -1;
    }
    if (ply >= temperature_moves) {
        return counts.front().first;
    }
    std::vector<float> weights;
    weights.reserve(counts.size());
    for (const auto& [action_idx, visit_count] : counts) {
        (void)action_idx;
        if (visit_count <= 0) {
            weights.push_back(1.0f);
        } else {
            weights.push_back(std::pow(static_cast<float>(visit_count), 1.0f));
        }
    }
    float total = 0.0f;
    for (float weight : weights) {
        total += weight;
    }
    if (total <= 0.0f) {
        return counts.front().first;
    }
    std::uniform_real_distribution<float> dist(0.0f, total);
    const float target = dist(rng);
    float running = 0.0f;
    for (std::size_t i = 0; i < counts.size(); ++i) {
        running += weights[i];
        if (target <= running) {
            return counts[i].first;
        }
    }
    return counts.back().first;
}

// ── Data structures ──────────────────────────────────────────────────────────

struct SelfPlaySample {
    std::array<float, kStateSize> state{};
    float move_idx = 0.0f;
    float value    = 0.0f;
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
    return static_cast<int>(move.from().index()) * 64 +
           static_cast<int>(move.to().index());
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

void print_usage(const char* argv0) {
    std::cerr << "Usage: " << argv0
              << " --model_path <path> --simulations <n>"
              << " --games <n> --output <path>"
              << " [--max_moves <n>] [--log_every <n>] [--temperature_moves <n>]\n";
}

}  // namespace

// ── main ─────────────────────────────────────────────────────────────────────

int main(int argc, char** argv) {
    std::string model_path  = "best_model_traced.pt";
    int         simulations = kDefaultSimulations;
    int         games       = kDefaultGames;
    std::string output_path = "selfplay_data.bin";
    int         max_moves   = kDefaultMaxMoves;
    int         log_every   = kDefaultLogEvery;
    int         temperature_moves = kDefaultTemperatureMoves;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if      (arg == "--model_path"  && i + 1 < argc) model_path  = argv[++i];
        else if (arg == "--simulations" && i + 1 < argc) simulations = std::stoi(argv[++i]);
        else if (arg == "--games"       && i + 1 < argc) games       = std::stoi(argv[++i]);
        else if (arg == "--output"      && i + 1 < argc) output_path = argv[++i];
        else if (arg == "--max_moves"   && i + 1 < argc) max_moves   = std::stoi(argv[++i]);
        else if (arg == "--log_every"   && i + 1 < argc) log_every   = std::stoi(argv[++i]);
        else if (arg == "--temperature_moves" && i + 1 < argc) temperature_moves = std::stoi(argv[++i]);
        else { print_usage(argv[0]); return 1; }
    }

    // ── Banner ──────────────────────────────────────────────────────────────
    std::cout << "[SelfPlay] ============================================================\n";
    std::cout << "[SelfPlay] Starting self-play session\n";
    std::cout << "[SelfPlay]   model       = " << model_path  << "\n";
    std::cout << "[SelfPlay]   simulations = " << simulations << " per move\n";
    std::cout << "[SelfPlay]   games       = " << games       << "\n";
    std::cout << "[SelfPlay]   max_moves   = " << max_moves   << " per game\n";
    std::cout << "[SelfPlay]   log_every   = " << log_every   << " games\n";
    std::cout << "[SelfPlay]   temperature_moves = " << temperature_moves << "\n";
    std::cout << "[SelfPlay]   output      = " << output_path << "\n";
    std::cout << "[SelfPlay] ============================================================\n";
    std::cout.flush();

    // ── Open output file ─────────────────────────────────────────────────────
    std::ofstream out(output_path, std::ios::binary | std::ios::trunc);
    if (!out) {
        std::cerr << "[SelfPlay] ERROR: cannot open output file: " << output_path << "\n";
        return 2;
    }

    // ── Load model (ONCE for all games) ─────────────────────────────────────
    // FIX: previously the MCTS object was constructed inside the ply loop,
    // causing torch::jit::load() to be called ~(games × avg_plies) times.
    // A 40-game run with ~80 plies/game meant ~3 200 model loads from disk.
    // Now we load exactly once and reuse the module for every search call.
    std::cout << "[SelfPlay] Loading TorchScript model...\n";
    std::cout.flush();
    const auto model_load_t0 = Clock::now();
    MCTS bot(model_path, simulations, 1.5f);
    const long long model_load_ms = elapsed_ms(model_load_t0);
    std::cout << "[SelfPlay] Model loaded in " << fmt_duration(model_load_ms)
              << " (" << model_load_ms << " ms)\n";
    std::cout.flush();

    // ── Self-play loop ───────────────────────────────────────────────────────
    std::size_t  total_samples  = 0;
    std::size_t  total_plies    = 0;
    int          draws          = 0;
    int          decisive       = 0;
    const auto   run_t0         = Clock::now();

    for (int game_idx = 0; game_idx < games; ++game_idx) {
        const auto game_t0 = Clock::now();

        ChessEnv env;
        std::vector<SelfPlaySample> samples;
        std::vector<float>          perspectives;
        float terminal_reward = 0.0f;
        int   plies           = 0;
        std::mt19937 rng(static_cast<unsigned>(std::chrono::steady_clock::now().time_since_epoch().count()));

        for (int ply = 0; ply < max_moves; ++ply) {
            chess::Movelist legal;
            env.get_legal_moves(legal);
            if (legal.empty()) break;

            const auto counts = bot.search_with_counts(env);
            std::string move_uci = "none";
            chess::Move chosen = chess::Move::NO_MOVE;
            if (!counts.empty()) {
                const int action_idx = sample_action_from_counts(counts, temperature_moves, ply, rng);
                for (const auto& move : legal) {
                    if (make_action_index(move) == action_idx) {
                        chosen = move;
                        break;
                    }
                }
                if (chosen != chess::Move::NO_MOVE) {
                    move_uci = chess::uci::moveToUci(chosen);
                }
            }
            if (chosen == chess::Move::NO_MOVE) {
                move_uci = bot.search(env);
                if (!resolve_move(env, move_uci, chosen)) chosen = legal[0];
            }

            const bool is_white = env.get_board().sideToMove() == chess::Color::WHITE;
            perspectives.push_back(is_white ? 1.0f : -1.0f);

            SelfPlaySample s;
            const auto state_vec = encode_state(env);
            std::copy(state_vec.begin(), state_vec.end(), s.state.begin());
            s.move_idx = static_cast<float>(make_action_index(chosen));
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

        // FIX: flush after each game so partial data survives if the process is
        // killed by Kaggle's timeout or OOM killer mid-run.
        out.flush();

        // Tally outcome
        total_plies += static_cast<std::size_t>(plies);
        if (terminal_reward == 0.0f) ++draws;
        else ++decisive;

        // ── Per-game log ─────────────────────────────────────────────────────
        if ((game_idx + 1) % log_every == 0 || game_idx + 1 == games) {
            const long long run_ms     = elapsed_ms(run_t0);
            const long long game_ms    = elapsed_ms(game_t0);
            const int       done       = game_idx + 1;
            const int       remaining  = games - done;

            // ETA: average ms/game × remaining games
            const double avg_ms_per_game = static_cast<double>(run_ms) / done;
            const long long eta_ms       = static_cast<long long>(avg_ms_per_game * remaining);

            // Throughput: total plies / total seconds
            const double run_s           = run_ms / 1000.0;
            const double moves_per_s     = (run_s > 0.0) ? (static_cast<double>(total_plies) / run_s) : 0.0;
            const double games_per_hour  = (run_s > 0.0) ? (done / run_s * 3600.0) : 0.0;

            // Outcome label for this game
            const char* outcome = (terminal_reward > 0.0f)  ? "white wins"
                                : (terminal_reward < 0.0f)  ? "black wins"
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
            std::cout << "[SelfPlay] speed="    << fmt_speed(moves_per_s)
                      << "  games/hr="
                      << std::fixed << std::setprecision(1) << games_per_hour
                      << "  decisive=" << decisive
                      << "  draws=" << draws
                      << "\n";
            std::cout.flush();
        }
    }

    // ── Final summary ────────────────────────────────────────────────────────
    const long long total_ms  = elapsed_ms(run_t0);
    const double    total_s   = total_ms / 1000.0;
    const double    avg_plies = (games > 0) ? (static_cast<double>(total_plies) / games) : 0.0;
    const double    mps       = (total_s > 0.0) ? (static_cast<double>(total_plies) / total_s) : 0.0;

    std::cout << "[SelfPlay] ============================================================\n";
    std::cout << "[SelfPlay] Session complete\n";
    std::cout << "[SelfPlay]   games          = " << games          << "\n";
    std::cout << "[SelfPlay]   total_samples  = " << total_samples  << "\n";
    std::cout << "[SelfPlay]   total_plies    = " << total_plies    << "\n";
    std::cout << "[SelfPlay]   avg_plies/game = "
              << std::fixed << std::setprecision(1) << avg_plies    << "\n";
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
