#ifndef MCTS_HPP
#define MCTS_HPP

#include <map>
#include <memory>
#include <string>
#include <vector>

#include <torch/script.h>

#include "chess.hpp"

class ChessEnv;

struct MCTSNode {
    int move_idx = -1;
    std::weak_ptr<MCTSNode> parent;
    std::map<int, std::shared_ptr<MCTSNode>> children;
    std::vector<int> untried_action_indices;

    chess::Move move = chess::Move::NO_MOVE;

    int visit_count = 0;
    float total_value = 0.0f;
    float prior_prob = 0.0f;
    int virtual_loss = 0;

    MCTSNode(int move, std::shared_ptr<MCTSNode> p_node, float prob, chess::Move actual_move = chess::Move::NO_MOVE)
        : move_idx(move), parent(p_node), prior_prob(prob), move(actual_move) {}

    bool has_children() const noexcept { return !children.empty(); }
    bool has_untried_moves() const noexcept { return !untried_action_indices.empty(); }
    bool is_expanded() const noexcept { return has_children(); }
    float get_q_value() const noexcept { return visit_count == 0 ? 0.0f : total_value / static_cast<float>(visit_count); }
};

class MCTS {
private:
    std::string model_path;
    torch::jit::script::Module module;
    bool model_loaded_ = false;
    int num_simulations;
    float c_puct;

    std::vector<float> run_nn_inference(const std::vector<float>& planes);
    std::vector<std::vector<float>> run_nn_inference_batch(const std::vector<std::vector<float>>& batch_planes);

public:
    MCTS(const std::string& m_path, int sims = 800, float c = 1.5f);

    std::string search(const ChessEnv& current_env);
    std::vector<std::pair<int, int>> search_with_counts(const ChessEnv& current_env);
};

#endif
