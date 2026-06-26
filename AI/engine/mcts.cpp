#include "mcts.hpp"
#include "ChessEnv.cpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <tuple>
#include <utility>

namespace {

constexpr std::size_t kBatchSize = 16;
constexpr std::size_t kStateSize = 768;
constexpr std::size_t kPolicySize = 4096;

std::vector<float> make_uniform_prior(std::size_t size) {
    std::vector<float> probs(size, 1.0f / static_cast<float>(std::max<std::size_t>(size, 1)));
    return probs;
}

std::vector<float> get_current_12_planes(const ChessEnv& env) {
    std::vector<float> full_state;
    env.write_stacked_state_tensor(full_state, 1);
    if (full_state.size() > kStateSize) {
        full_state.resize(kStateSize);
    }
    return full_state;
}

int popcount_u64(std::uint64_t value) noexcept {
#if defined(_MSC_VER)
    return static_cast<int>(__popcnt64(value));
#else
    return __builtin_popcountll(value);
#endif
}

int make_action_index(const chess::Move& move) {
    return static_cast<int>(move.from().index()) * 64 + static_cast<int>(move.to().index());
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
    return (env.get_board().sideToMove() == chess::Color::BLACK) ? -material_score : material_score;
}

float evaluate_terminal_result(const ChessEnv& env) {
    if (!env.is_terminal()) {
        return evaluate_position(env);
    }

    chess::Movelist legal_moves;
    env.get_legal_moves(legal_moves);
    if (legal_moves.empty()) {
        return (env.get_board().sideToMove() == chess::Color::WHITE) ? -1.0f : 1.0f;
    }
    return 0.0f;
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

}  // namespace

MCTS::MCTS(const std::string& m_path, int sims, float c)
    : model_path(m_path), num_simulations(sims), c_puct(c) {
    try {
        module = torch::jit::load(model_path);
        module.eval();
        model_loaded_ = true;
    } catch (const c10::Error& e) {
        std::cerr << "❌ Lỗi nghiêm trọng: Không thể tải mô hình TorchScript!\n";
    }
}

std::vector<float> MCTS::run_nn_inference(const std::vector<float>& planes) {
    std::vector<std::vector<float>> batch_planes;
    batch_planes.emplace_back(planes);
    const auto policies = run_nn_inference_batch(batch_planes);
    return policies.empty() ? make_uniform_prior(kPolicySize) : policies.front();
}

std::vector<std::vector<float>> MCTS::run_nn_inference_batch(const std::vector<std::vector<float>>& batch_planes) {
    if (!model_loaded_ || batch_planes.empty()) {
        std::vector<std::vector<float>> fallback(batch_planes.size(), make_uniform_prior(kPolicySize));
        return fallback;
    }

    torch::NoGradGuard no_grad;

    auto options = torch::TensorOptions().dtype(torch::kFloat32);
    std::vector<float> flattened;
    flattened.reserve(batch_planes.size() * kStateSize);
    for (const auto& planes : batch_planes) {
        flattened.insert(flattened.end(), planes.begin(), planes.end());
    }

    torch::Tensor input_tensor = torch::tensor(flattened, options).reshape({static_cast<int64_t>(batch_planes.size()), 12, 8, 8});

    std::vector<torch::jit::IValue> inputs;
    inputs.emplace_back(input_tensor);

    try {
        torch::Tensor output = module.forward(inputs).toTensor();
        if (output.dim() == 1) {
            output = output.unsqueeze(0);
        }
        if (output.dim() == 2 && output.size(0) == 1 && batch_planes.size() > 1) {
            output = output.expand({static_cast<int64_t>(batch_planes.size()), output.size(1)});
        }
        if (output.dim() != 2 || output.size(0) != static_cast<int64_t>(batch_planes.size())) {
            std::vector<std::vector<float>> fallback(batch_planes.size(), make_uniform_prior(kPolicySize));
            return fallback;
        }

        torch::Tensor probs = torch::softmax(output, 1);
        std::vector<std::vector<float>> policies;
        policies.reserve(batch_planes.size());
        for (std::size_t i = 0; i < batch_planes.size(); ++i) {
            const auto row = probs[i];
            policies.emplace_back(row.data_ptr<float>(), row.data_ptr<float>() + row.numel());
        }
        return policies;
    } catch (const c10::Error& e) {
        std::cerr << "⚠️  Lỗi khi chạy suy luận mạng, dùng prior đều.\n";
        std::vector<std::vector<float>> fallback(batch_planes.size(), make_uniform_prior(kPolicySize));
        return fallback;
    }
}

std::string MCTS::search(const ChessEnv& current_env) {
    if (current_env.is_terminal()) {
        return "none";
    }

    auto root = std::make_shared<MCTSNode>(-1, nullptr, 1.0f);
    ChessEnv global_env = current_env;

    const auto start_time = std::chrono::steady_clock::now();
    std::size_t total_node_visits = 0;
    std::size_t max_depth = 0;

    using PendingRequest = std::tuple<std::shared_ptr<MCTSNode>, ChessEnv, std::vector<std::shared_ptr<MCTSNode>>>;
    std::vector<PendingRequest> pending_requests;
    pending_requests.reserve(kBatchSize);

    auto process_pending_batch = [&](std::vector<PendingRequest>& batch) {
        if (batch.empty()) {
            return;
        }

        std::vector<std::vector<float>> batch_states;
        batch_states.reserve(batch.size());
        for (const auto& entry : batch) {
            const auto& [node, env, path] = entry;
            (void)path;
            if (node == nullptr || !node->has_untried_moves()) {
                continue;
            }
            batch_states.emplace_back(get_current_12_planes(env));
        }

        std::vector<std::vector<float>> batch_policies;
        if (!batch_states.empty()) {
            batch_policies = run_nn_inference_batch(batch_states);
        }

        std::size_t policy_index = 0;
        for (auto& entry : batch) {
            auto& [node, env, path] = entry;
            if (node == nullptr || !node->has_untried_moves()) {
                continue;
            }

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

            if (chosen_move == chess::Move::NO_MOVE) {
                continue;
            }

            const std::vector<float>& policy_row = (policy_index < batch_policies.size()) ? batch_policies[policy_index] : make_uniform_prior(kPolicySize);
            const float prior = (action_idx >= 0 && action_idx < static_cast<int>(policy_row.size())) ? policy_row[action_idx] : 0.0f;
            ++policy_index;

            auto child = std::make_shared<MCTSNode>(action_idx, node, prior, chosen_move);
            node->children[action_idx] = child;
            node->virtual_loss += 1;

            ChessEnv child_env = env;
            child_env.step(chosen_move);
            auto child_path = path;
            child_path.push_back(child);
            backpropagate_path(child_path, evaluate_terminal_result(child_env));
            total_node_visits += child_path.size();
            node->virtual_loss = std::max(0, node->virtual_loss - 1);
        }
    };

    for (int sim = 0; sim < num_simulations; ++sim) {
        auto current_node = root;
        ChessEnv sim_env = global_env;
        std::vector<std::shared_ptr<MCTSNode>> path{current_node};
        std::size_t depth = 0;

        while (current_node->has_children() && !current_node->has_untried_moves() && !sim_env.is_terminal()) {
            float best_puct = -std::numeric_limits<float>::infinity();
            std::shared_ptr<MCTSNode> best_child = nullptr;

            float total_visits = 0.0f;
            for (const auto& [action_idx, child] : current_node->children) {
                (void)action_idx;
                total_visits += static_cast<float>(child->visit_count + child->virtual_loss);
            }

            for (const auto& [action_idx, child] : current_node->children) {
                (void)action_idx;
                const float effective_visits = static_cast<float>(child->visit_count + child->virtual_loss);
                const float u_score = c_puct * child->prior_prob * std::sqrt(total_visits + 1.0f) / (1.0f + effective_visits);
                const float puct = child->get_q_value() + u_score;
                if (puct > best_puct) {
                    best_puct = puct;
                    best_child = child;
                }
            }

            if (best_child == nullptr) {
                break;
            }

            current_node = best_child;
            sim_env.step(best_child->move);
            path.push_back(current_node);
            ++depth;
        }

        max_depth = std::max(max_depth, depth);

        if (sim_env.is_terminal()) {
            backpropagate_path(path, evaluate_terminal_result(sim_env));
            total_node_visits += path.size();
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
                total_node_visits += path.size();
            }
        }

        if (pending_requests.size() >= kBatchSize || sim + 1 == num_simulations) {
            std::vector<decltype(pending_requests)::value_type> batch = std::move(pending_requests);
            process_pending_batch(batch);
            pending_requests.clear();
        }
    }

    const auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start_time).count();
    const double elapsed_s = elapsed_ms / 1000.0;
    const double nps = elapsed_s > 0.0 ? (static_cast<double>(total_node_visits) / elapsed_s) : 0.0;

    int best_final_action = -1;
    int max_visits = -1;
    for (const auto& [action_idx, child] : root->children) {
        if (child->visit_count > max_visits) {
            max_visits = child->visit_count;
            best_final_action = action_idx;
        }
    }

    if (best_final_action != -1) {
        const auto selected = root->children[best_final_action];
        if (selected != nullptr) {
            return chess::uci::moveToUci(selected->move);
        }
    }

    chess::Movelist legal_moves;
    current_env.get_legal_moves(legal_moves);
    if (!legal_moves.empty()) {
        return chess::uci::moveToUci(legal_moves[0]);
    }

    return "none";
}
