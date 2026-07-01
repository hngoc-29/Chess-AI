#pragma once

// chess.hpp must come before torch to avoid macro clashes.
// selfplay.cpp and mcts.cpp both #include "ChessEnv.cpp" which itself
// includes "chess.hpp", but since chess.hpp has an include guard the
// duplicate is harmless — putting it here makes mcts.hpp self-contained.
#include "chess.hpp"

#include <memory>
#include <random>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include <torch/script.h>

// Forward-declare ChessEnv — the full definition comes from ChessEnv.cpp,
// which callers (#include "ChessEnv.cpp") already have before they include
// this header.
class ChessEnv;

// ── Action-space constants ────────────────────────────────────────────────────
// NUM_ACTIONS = 4096 (from*64+to, normal moves + queen promotions)
//             + 192  (3 underpromotion piece types × 64 `to` squares)
//             = 4288
// Matches Python NUM_ACTIONS / _PROMO_OFFSET exactly.
// Used as the fallback uniform-prior size when the NN is unavailable.
static constexpr std::size_t kNumActions = 4288;

// ── MCTSNode ─────────────────────────────────────────────────────────────────
struct MCTSNode {
    // Action index that led to this node (-1 for root).
    int action_index;

    // The chess::Move that created this node (needed to replay during selection).
    // chess::Move is a lightweight 16-bit value type — safe to store by value.
    chess::Move move;

    // Parent node (nullptr for root).
    std::weak_ptr<MCTSNode> parent;

    // Prior probability from the NN policy head.
    float prior_prob;

    // MCTS statistics.
    int   visit_count   = 0;
    float total_value   = 0.0f;
    int   virtual_loss  = 0;

    // Children keyed by action_index.
    std::unordered_map<int, std::shared_ptr<MCTSNode>> children;

    // Unexpanded action indices (populated lazily on first visit).
    std::vector<int> untried_action_indices;

    // Root constructor (no move).
    MCTSNode(int action_idx,
             std::shared_ptr<MCTSNode> parent_node,
             float prior)
        : action_index(action_idx),
          move(chess::Move::NO_MOVE),
          parent(std::move(parent_node)),
          prior_prob(prior)
    {}

    // Child constructor (with the move that created this child).
    MCTSNode(int action_idx,
             std::shared_ptr<MCTSNode> parent_node,
             float prior,
             chess::Move m)
        : action_index(action_idx),
          move(m),
          parent(std::move(parent_node)),
          prior_prob(prior)
    {}

    // Mean action value from the current player's perspective.
    float get_q_value() const {
        if (visit_count == 0) return 0.0f;
        return total_value / static_cast<float>(visit_count);
    }

    bool has_children()      const { return !children.empty(); }
    bool has_untried_moves() const { return !untried_action_indices.empty(); }
};

// ── MCTS ─────────────────────────────────────────────────────────────────────
class MCTS {
public:
    // model_path : path to a TorchScript (.pt) file produced by save_traced_model().
    // sims       : number of MCTS simulations per move.
    // c          : c_puct exploration constant (AlphaZero default ≈ 1.25–2.0).
    // seed       : RNG seed for Dirichlet noise (makes self-play reproducible).
    MCTS(const std::string& model_path, int sims, float c, unsigned seed);

    // Run MCTS and return the best move as a UCI string ("e2e4", "a7a8q", …).
    std::string search(const ChessEnv& env);

    // Run MCTS and return raw (action_index, visit_count) pairs for all
    // root children.  Used by selfplay.cpp for temperature sampling and for
    // writing move_idx into the replay buffer.
    std::vector<std::pair<int, int>> search_with_counts(const ChessEnv& env);

    // Root Q-value cached after the most recent search_with_counts() call.
    //   > 0  →  current player is winning from the model's perspective.
    //   < 0  →  current player is losing.
    //   = 0  →  no search has been run yet (or model unavailable).
    // Used by selfplay.cpp to implement resign: if root_q < resign_thresh,
    // the current player concedes immediately, avoiding useless moves.
    float get_last_root_q() const;

private:
    // ── NN inference helpers ─────────────────────────────────────────────────
    std::vector<float>
    run_nn_inference(const std::vector<float>& planes);

    std::pair<std::vector<std::vector<float>>, std::vector<float>>
    run_nn_inference_batch(const std::vector<std::vector<float>>& batch_planes);

    // ── Private state ─────────────────────────────────────────────────────────
    std::string                  model_path;
    int                          num_simulations;
    float                        c_puct;
    std::mt19937                 rng_;

    torch::jit::script::Module   module;
    bool                         model_loaded_ = false;
    bool                         use_cuda_     = false;

    // Q-value at the root of the most recently completed search.
    float                        last_root_q_  = 0.0f;
};
