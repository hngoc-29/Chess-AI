#include "mcts.hpp"
#include "ChessEnv.cpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <numeric>
#include <random>
#include <tuple>
#include <utility>

namespace {

constexpr std::size_t kBatchSize  = 64;
constexpr std::size_t kStateSize  = 1280;  // 20 planes × 64 sq: 12 piece + turn + 4 castle + EP + rep1 + rep2
// NUM_ACTIONS (Python): 4096 normal/queen-promo slots (from*64+to) + 192
// underpromotion slots (3 piece types × 64 `to` squares) = 4288.
// Was 4096 — silently dropped the underpromotion slice of the model's
// policy head and let knight/bishop/rook promotions collide with the
// queen-promotion action_idx for the same from/to.
constexpr std::size_t kPolicySize  = 4288;
// Start of the underpromotion slice within the action space; matches
// Python's _PROMO_OFFSET. Underpromotion piece order (matches _PROMO_IDX):
// knight=0, bishop=1, rook=2. Queen promotions stay in the 0..4095 range.
constexpr int kPromoOffset = 4096;

// Dirichlet noise hyperparams (AlphaZero)
// epsilon cao hơn (0.35 vs 0.25 default) để MCTS khám phá aggressive hơn,
// tránh stuck trong draw loops. alpha=0.3 (standard chess setting).
constexpr float kDirichletAlpha   = 0.3f;
constexpr float kDirichletEpsilon = 0.35f;  // was 0.25 — tăng để khám phá aggressive hơn

std::vector<float> make_uniform_prior(std::size_t size) {
    std::vector<float> probs(size, 1.0f / static_cast<float>(std::max<std::size_t>(size, 1)));
    return probs;
}

// get_current_nn_planes: 20 planes × 64 sq = 1280 floats (= kStateSize).
// Planes 0-11: piece positions (White P/N/B/R/Q/K, then Black P/N/B/R/Q/K).
// Plane 12: turn (1.0 = white to move, 0.0 = black to move).
// Planes 13-16: castling rights WK/WQ/BK/BQ (all 1.0 or all 0.0 per flag).
// Plane 17: en passant target square (1.0 at EP square, rest 0.0).
// Plane 18: rep1 — position repeated ≥1 time (all 1.0 or 0.0).
// Plane 19: rep2 — position repeated ≥2 times (all 1.0 or 0.0).
// Delegates to ChessEnv::write_nn_planes() which is the verified ground truth.
std::vector<float> get_current_nn_planes(const ChessEnv& env) {
    std::vector<float> state(kStateSize, 0.0f);
    env.write_nn_planes(state.data());
    return state;
}

int popcount_u64(std::uint64_t value) noexcept {
#if defined(_MSC_VER)
    return static_cast<int>(__popcnt64(value));
#else
    return __builtin_popcountll(value);
#endif
}

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

float evaluate_material_from_white_perspective(const ChessEnv& env) {
    const auto& board = env.get_board();
    static constexpr std::array<float, 6> weights = {1.0f, 3.0f, 3.2f, 5.1f, 9.0f, 0.0f};
    static constexpr std::array<chess::PieceType, 6> piece_types = {
        chess::PieceType::PAWN,
        chess::PieceType::KNIGHT,
        chess::PieceType::BISHOP,
        chess::PieceType::ROOK,
        chess::PieceType::QUEEN,
        chess::PieceType::KING
    };

    float score = 0.0f;
    for (std::size_t i = 0; i < piece_types.size(); ++i) {
        const auto white_bits = board.pieces(piece_types[i], chess::Color::WHITE).getBits();
        const auto black_bits = board.pieces(piece_types[i], chess::Color::BLACK).getBits();
        score += weights[i] * static_cast<float>(popcount_u64(white_bits) - popcount_u64(black_bits));
    }
    return score;
}

float evaluate_position(const ChessEnv& env) {
    const float material_score = evaluate_material_from_white_perspective(env);
    constexpr float kMaxMaterial = 39.0f;
    return std::max(-1.0f, std::min(1.0f,
        ((env.get_board().sideToMove() == chess::Color::BLACK) ? -material_score : material_score)
        / kMaxMaterial));
}

// FIX #1 + Bug5: draw terminal = -0.4 (matches training DRAW_VALUE = -0.4).
// Old: returns 0.0 for draws → MCTS prefers terminal draws (0.0) over model pred (-0.4).
// New: returns -0.4 → MCTS avoids draws consistently with training signal.
static constexpr float kDrawValue = -0.4f;

float evaluate_terminal_result(const ChessEnv& env) {
    if (!env.is_terminal()) {
        return evaluate_position(env);
    }

    chess::Movelist legal_moves;
    env.get_legal_moves(legal_moves);

    if (legal_moves.empty()) {
        // Checkmate: in check with no legal moves → loser is side to move
        if (env.get_board().inCheck()) {
            return (env.get_board().sideToMove() == chess::Color::WHITE) ? -1.0f : 1.0f;
        }
        // Stalemate → draw
        return kDrawValue;
    }
    // Draw by repetition / 50-move rule / insufficient material
    return kDrawValue;
}

void backpropagate_path(const std::vector<std::shared_ptr<MCTSNode>>& path, float value) {
    float current_value = value;
    for (auto it = path.rbegin(); it != path.rend(); ++it) {
        const auto& node = *it;
        node->visit_count += 1;
        node->total_value += current_value;
        current_value = -current_value;
    }
}

std::vector<float> sample_dirichlet(std::size_t n, float alpha, std::mt19937& rng) {
    std::gamma_distribution<float> gamma(alpha, 1.0f);
    std::vector<float> noise(n);
    float sum = 0.0f;
    for (auto& x : noise) {
        x = gamma(rng);
        sum += x;
    }
    if (sum > 0.0f) {
        for (auto& x : noise) x /= sum;
    } else {
        std::fill(noise.begin(), noise.end(), 1.0f / static_cast<float>(n));
    }
    return noise;
}

}  // namespace

// ─────────────────────────────────────────────────────────────────────────────

MCTS::MCTS(const std::string& m_path, int sims, float c, unsigned seed)
    : model_path(m_path), num_simulations(sims), c_puct(c), rng_(seed) {
    try {
        module = torch::jit::load(model_path);
        module.eval();
        model_loaded_ = true;
        if (torch::hasCUDA()) {
            module.to(torch::kCUDA);
            use_cuda_ = true;
            std::cout << "[MCTS] Model moved to CUDA\n";
        } else {
            std::cout << "[MCTS] CUDA not available, running on CPU\n";
        }
        std::cout << "[MCTS] Model loaded: " << model_path << std::endl;
        std::cout.flush();
    } catch (const c10::Error& e) {
        std::cerr << "[ERROR] Cannot load TorchScript model: " << model_path
                  << "\n  " << e.what() << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "[ERROR] Exception loading model: " << e.what() << std::endl;
    }
}

std::vector<float> MCTS::run_nn_inference(const std::vector<float>& planes) {
    std::vector<std::vector<float>> batch_planes;
    batch_planes.emplace_back(planes);
    auto [policies, values] = run_nn_inference_batch(batch_planes);
    return policies.empty() ? make_uniform_prior(kPolicySize) : policies.front();
}

std::pair<std::vector<std::vector<float>>, std::vector<float>>
MCTS::run_nn_inference_batch(const std::vector<std::vector<float>>& batch_planes) {
    const std::size_t N = batch_planes.size();

    std::vector<std::vector<float>> fallback_policies(N, make_uniform_prior(kPolicySize));
    std::vector<float> fallback_values(N, 0.0f);

    if (!model_loaded_ || N == 0) {
        return {fallback_policies, fallback_values};
    }

    torch::NoGradGuard no_grad;

    auto options = torch::TensorOptions().dtype(torch::kFloat32);
    if (use_cuda_) { options = options.device(torch::kCUDA); }
    std::vector<float> flattened;
    flattened.reserve(N * kStateSize);
    for (const auto& planes : batch_planes) {
        flattened.insert(flattened.end(), planes.begin(), planes.end());
    }

    torch::Tensor input_tensor = torch::tensor(flattened, options)
        .reshape({static_cast<int64_t>(N), 20, 8, 8});

    std::vector<torch::jit::IValue> inputs;
    inputs.emplace_back(input_tensor);

    try {
        auto raw_output = module.forward(inputs);

        torch::Tensor policy_tensor;
        std::vector<float> batch_values(N, 0.0f);

        if (raw_output.isTuple()) {
            auto output_tuple = raw_output.toTuple();
            policy_tensor = output_tuple->elements()[0].toTensor();
            torch::Tensor value_tensor = output_tuple->elements()[1].toTensor();
            auto value_flat = value_tensor.flatten();
            for (std::size_t i = 0; i < N && i < static_cast<std::size_t>(value_flat.numel()); ++i) {
                batch_values[i] = value_flat[static_cast<int64_t>(i)].item<float>();
            }
        } else {
            policy_tensor = raw_output.toTensor();
        }

        if (policy_tensor.dim() == 1) {
            policy_tensor = policy_tensor.unsqueeze(0);
        }
        if (policy_tensor.dim() != 2 ||
            policy_tensor.size(0) != static_cast<int64_t>(N)) {
            return {fallback_policies, fallback_values};
        }

        if (use_cuda_) { policy_tensor = policy_tensor.cpu(); }
        torch::Tensor probs = torch::softmax(policy_tensor, 1);
        std::vector<std::vector<float>> policies;
        policies.reserve(N);
        for (std::size_t i = 0; i < N; ++i) {
            const auto row = probs[static_cast<int64_t>(i)];
            policies.emplace_back(row.data_ptr<float>(), row.data_ptr<float>() + row.numel());
        }
        return {policies, batch_values};

    } catch (const c10::Error& e) {
        std::cerr << "[ERROR] NN inference failed: " << e.what() << "\n";
        std::cerr.flush();
        return {fallback_policies, fallback_values};
    } catch (const std::exception& e) {
        std::cerr << "[ERROR] NN inference exception: " << e.what() << "\n";
        std::cerr.flush();
        return {fallback_policies, fallback_values};
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core MCTS search
// ─────────────────────────────────────────────────────────────────────────────

std::vector<std::pair<int, int>> MCTS::search_with_counts(const ChessEnv& current_env) {
    if (current_env.is_terminal()) {
        return {};
    }

    auto root = std::make_shared<MCTSNode>(-1, nullptr, 1.0f);
    ChessEnv global_env = current_env;

    bool root_dirichlet_applied = false;

    // FIX #2: Restructured PendingRequest to track child info separately.
    // Previously, the NN was evaluated on the PARENT state but the returned
    // value was backpropagated as the CHILD's leaf value. This is wrong.
    // Now: NN(parent) → policy priors for children
    //      NN(child)  → leaf value for backpropagation
    struct ChildEvalRequest {
        std::shared_ptr<MCTSNode> child_node;
        ChessEnv child_env;
        std::vector<std::shared_ptr<MCTSNode>> child_path;
    };

    using PendingRequest = std::tuple<std::shared_ptr<MCTSNode>, ChessEnv,
                                      std::vector<std::shared_ptr<MCTSNode>>>;
    std::vector<PendingRequest> pending_requests;
    pending_requests.reserve(kBatchSize);

    auto process_pending_batch = [&](std::vector<PendingRequest>& batch) {
        if (batch.empty()) return;

        // ── Phase 1: Evaluate PARENT states → get policy priors ──────────────
        std::vector<std::vector<float>> batch_states;
        std::vector<std::size_t> valid_indices;
        batch_states.reserve(batch.size());

        for (std::size_t bi = 0; bi < batch.size(); ++bi) {
            const auto& [node, env, path] = batch[bi];
            (void)path;
            if (node == nullptr || !node->has_untried_moves()) continue;
            batch_states.emplace_back(get_current_nn_planes(env));
            valid_indices.push_back(bi);
        }

        std::vector<std::vector<float>> batch_policies;
        if (!batch_states.empty()) {
            auto [p, _v] = run_nn_inference_batch(batch_states);
            batch_policies = std::move(p);
        }

        // ── Phase 2: Pick action, make move, collect children for eval ────────
        std::vector<ChildEvalRequest> children_to_eval;
        children_to_eval.reserve(valid_indices.size());

        std::size_t policy_index = 0;
        for (std::size_t vi = 0; vi < valid_indices.size(); ++vi) {
            auto& [node, env, path] = batch[valid_indices[vi]];
            if (node == nullptr || !node->has_untried_moves()) { ++policy_index; continue; }

            const int action_idx = node->untried_action_indices.back();
            node->untried_action_indices.pop_back();

            chess::Movelist legal_moves;
            env.get_legal_moves(legal_moves);
            chess::Move chosen_move = chess::Move::NO_MOVE;
            for (const auto& move : legal_moves) {
                if (make_action_index(move) == action_idx) {
                    chosen_move = move;
                    break;
                }
            }

            if (chosen_move == chess::Move::NO_MOVE) { ++policy_index; continue; }

            float prior = 0.0f;
            if (policy_index < batch_policies.size()) {
                const auto& policy_row = batch_policies[policy_index];
                if (action_idx >= 0 && action_idx < static_cast<int>(policy_row.size())) {
                    prior = policy_row[action_idx];
                }
            }
            ++policy_index;

            auto child = std::make_shared<MCTSNode>(action_idx, node, prior, chosen_move);
            node->children[action_idx] = child;
            node->virtual_loss += 1;

            ChessEnv child_env = env;
            child_env.step(chosen_move);

            auto child_path = path;
            child_path.push_back(child);

            // ── Apply Dirichlet noise to root children after first expansion ──
            if (!root_dirichlet_applied && node == root && root->has_children()) {
                root_dirichlet_applied = true;
                const std::size_t n_children = root->children.size();
                if (n_children > 1) {
                    auto noise = sample_dirichlet(n_children, kDirichletAlpha, rng_);
                    std::size_t ni = 0;
                    for (auto& [cidx, child_node] : root->children) {
                        child_node->prior_prob =
                            (1.0f - kDirichletEpsilon) * child_node->prior_prob
                            + kDirichletEpsilon * noise[ni++];
                    }
                }
            }

            if (child_env.is_terminal()) {
                // Terminal child: use exact game result immediately
                float leaf_value = evaluate_terminal_result(child_env);
                backpropagate_path(child_path, leaf_value);
                node->virtual_loss = std::max(0, node->virtual_loss - 1);
            } else {
                // Non-terminal: queue child for NN value evaluation
                children_to_eval.push_back({child, child_env, child_path});
            }
        }

        // ── Phase 3: Evaluate CHILD states → get leaf values ─────────────────
        // FIX: We now correctly evaluate the CHILD state for the leaf value,
        // not the parent state. This gives MCTS accurate position evaluations.
        if (!children_to_eval.empty()) {
            std::vector<std::vector<float>> child_states;
            child_states.reserve(children_to_eval.size());
            for (const auto& cr : children_to_eval) {
                child_states.emplace_back(get_current_nn_planes(cr.child_env));
            }
            auto [_child_policies, child_values] = run_nn_inference_batch(child_states);

            for (std::size_t ci = 0; ci < children_to_eval.size(); ++ci) {
                auto& cr = children_to_eval[ci];
                float leaf_value = (ci < child_values.size()) ? child_values[ci] : 0.0f;
                backpropagate_path(cr.child_path, leaf_value);
                // Release virtual loss on parent
                if (!cr.child_path.empty() && cr.child_path.size() >= 2) {
                    auto& parent_node = cr.child_path[cr.child_path.size() - 2];
                    parent_node->virtual_loss = std::max(0, parent_node->virtual_loss - 1);
                }
            }
        }
    };

    for (int sim = 0; sim < num_simulations; ++sim) {
        auto current_node = root;
        ChessEnv sim_env  = global_env;
        std::vector<std::shared_ptr<MCTSNode>> path{current_node};

        // Selection
        while (current_node->has_children() &&
               !current_node->has_untried_moves() &&
               !sim_env.is_terminal()) {
            float best_puct = -std::numeric_limits<float>::infinity();
            std::shared_ptr<MCTSNode> best_child = nullptr;

            float total_visits = 0.0f;
            for (const auto& [aidx, child] : current_node->children) {
                (void)aidx;
                total_visits += static_cast<float>(child->visit_count + child->virtual_loss);
            }

            for (const auto& [aidx, child] : current_node->children) {
                (void)aidx;
                const float eff_visits = static_cast<float>(child->visit_count + child->virtual_loss);
                const float u_score   = c_puct * child->prior_prob *
                                        std::sqrt(total_visits + 1.0f) / (1.0f + eff_visits);
                // FPU (First Play Urgency): node chưa visit → Q = -0.15 (bằng draw penalty)
                // thay vì 0.0 (trước đây). Tránh MCTS ưu tiên move chưa thăm chỉ vì Q=0 = draw.
                const float fpu_q    = (child->visit_count == 0) ? kDrawValue : child->get_q_value();
                const float puct      = fpu_q + u_score;
                if (puct > best_puct) {
                    best_puct  = puct;
                    best_child = child;
                }
            }

            if (best_child == nullptr) break;

            current_node = best_child;
            sim_env.step(best_child->move);
            path.push_back(current_node);
        }

        if (sim_env.is_terminal()) {
            backpropagate_path(path, evaluate_terminal_result(sim_env));
            continue;
        }

        if (current_node->has_untried_moves()) {
            pending_requests.emplace_back(current_node, sim_env, path);
        } else {
            chess::Movelist legal_moves;
            sim_env.get_legal_moves(legal_moves);
            if (!legal_moves.empty()) {
                current_node->untried_action_indices.reserve(legal_moves.size());
                for (const auto& move : legal_moves) {
                    current_node->untried_action_indices.push_back(make_action_index(move));
                }
                pending_requests.emplace_back(current_node, sim_env, path);
            } else {
                backpropagate_path(path, evaluate_terminal_result(sim_env));
            }
        }

        if (pending_requests.size() >= kBatchSize || sim + 1 == num_simulations) {
            auto batch = std::move(pending_requests);
            process_pending_batch(batch);
            pending_requests.clear();
        }
    }

    std::vector<std::pair<int, int>> counts;
    counts.reserve(root->children.size());
    for (const auto& [action_idx, child] : root->children) {
        counts.emplace_back(action_idx, child->visit_count);
    }
    // Cache root Q-value so callers can implement resign logic without
    // re-running inference.  Q = total_value / visit_count from current player's
    // perspective (same sign convention as backpropagation).
    last_root_q_ = (root->visit_count > 0)
        ? (root->total_value / static_cast<float>(root->visit_count))
        : 0.0f;
    return counts;
}

float MCTS::get_last_root_q() const {
    return last_root_q_;
}

std::string MCTS::search(const ChessEnv& current_env) {
    if (current_env.is_terminal()) return "none";

    const auto counts = search_with_counts(current_env);
    if (counts.empty()) {
        chess::Movelist legal_moves;
        current_env.get_legal_moves(legal_moves);
        if (!legal_moves.empty()) {
            return chess::uci::moveToUci(legal_moves[0]);
        }
        return "none";
    }

    int best_action = -1;
    int max_visits  = -1;
    for (const auto& [action_idx, visits] : counts) {
        if (visits > max_visits) {
            max_visits  = visits;
            best_action = action_idx;
        }
    }

    chess::Movelist legal_moves;
    current_env.get_legal_moves(legal_moves);
    for (const auto& move : legal_moves) {
        if (make_action_index(move) == best_action) {
            return chess::uci::moveToUci(move);
        }
    }

    if (!legal_moves.empty()) {
        return chess::uci::moveToUci(legal_moves[0]);
    }
    return "none";
}