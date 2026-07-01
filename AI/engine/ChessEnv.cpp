#ifndef CHESS_ENV_CPP_INCLUDED
#define CHESS_ENV_CPP_INCLUDED

#include "chess.hpp"

#include <array>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <algorithm>
#include <vector>
#include <iostream>

// ------------------------------------------------------------
// Enum-based outputs (no strings)
// ------------------------------------------------------------

enum class TerminationReason : std::uint8_t {
    Ongoing = 0,
    IllegalMove,
    Checkmate,
    Stalemate,
    FiftyMoveRule,
    InsufficientMaterial,
    ThreefoldRepetition
};

enum class CastleRights : std::uint8_t {
    None            = 0,
    WhiteKingSide    = 1u << 0,
    WhiteQueenSide   = 1u << 1,
    BlackKingSide    = 1u << 2,
    BlackQueenSide   = 1u << 3
};

inline constexpr std::uint8_t castle_mask(CastleRights r) noexcept {
    return static_cast<std::uint8_t>(r);
}

inline constexpr std::uint8_t operator|(CastleRights a, CastleRights b) noexcept {
    return castle_mask(a) | castle_mask(b);
}

inline constexpr bool has_castle(std::uint8_t mask, CastleRights r) noexcept {
    return (mask & castle_mask(r)) != 0;
}

struct StepResult {
    float reward = 0.0f;
    bool done = false;
    TerminationReason termination_reason = TerminationReason::Ongoing;
};

// ------------------------------------------------------------
// High-throughput ChessEnv
// ------------------------------------------------------------

class ChessEnv final {
public:
    static constexpr std::size_t kPiecePlanes   = 12;
    static constexpr std::size_t kTotalNNPlanes = 20;  // 12 piece + turn + 4 castle + EP + rep1 + rep2
    static constexpr std::size_t kSquaresPerPlane = 64;
    static constexpr std::size_t kStateSize = kTotalNNPlanes * kSquaresPerPlane; // 1280
    static constexpr std::size_t kHistoryFrames = 8;
    // 5 board scalars + 1 en-passant file → 6 total
    static constexpr std::size_t kScalarCount = 6;
    static constexpr std::size_t kMaxPlies = 1024;

    struct FrameSnapshot {
        std::array<std::uint64_t, 12> planes{}; // 12 bitboards only, no Board objects
    };

public:
    ChessEnv() {
        reset();
    }

    void reset() {
        board_ = chess::Board(chess::constants::STARTPOS);

        ply_ = 0;
        history_head_ = 0;
        history_count_ = 1;

        castle_mask_ = castle_mask(CastleRights::WhiteKingSide) |
                       castle_mask(CastleRights::WhiteQueenSide) |
                       castle_mask(CastleRights::BlackKingSide) |
                       castle_mask(CastleRights::BlackQueenSide);

        move_history_.fill(chess::Move::NO_MOVE);

        history_[0] = snapshot_from_board(board_);
        castle_history_[0] = castle_mask_;
    }

    const chess::Board& get_board() const noexcept { return board_; }

    // Use get_legal_moves(out) instead – this overload returns a ref to an
    // internal mutable cache that is invalidated on the next call.
    // Kept only for backward-compatibility; prefer get_legal_moves().
    void get_legal_moves(chess::Movelist& out) const {
        out.clear();
        chess::movegen::legalmoves(out, board_);
    }

    bool is_terminal() const noexcept {
        const auto [reason, result] = board_.isGameOver();
        return reason != chess::GameResultReason::NONE;
    }

    StepResult step(const chess::Move& move) {
        StepResult result;

        const auto [reason_before, outcome_before] = board_.isGameOver();
        if (reason_before != chess::GameResultReason::NONE) {
            result.done = true;
            result.reward = terminal_reward(reason_before);
            result.termination_reason = map_reason(reason_before);
            return result;
        }

        if (!board_.isLegal(move)) {
            result.done = true;
            result.reward = -1.0f;
            result.termination_reason = TerminationReason::IllegalMove;
            return result;
        }

        const FrameSnapshot before = history_[history_head_];
        const std::uint8_t next_castle_mask = update_castle_mask(before, move, castle_mask_);

        board_.makeMove(move);

        move_history_[ply_++] = move;

        push_history(snapshot_from_board(board_), next_castle_mask);

        const auto [reason_after, outcome_after] = board_.isGameOver();
        if (reason_after == chess::GameResultReason::NONE) {
            result.done = false;
            result.reward = 0.0f;
            result.termination_reason = TerminationReason::Ongoing;
            return result;
        }

        result.done = true;
        result.reward = terminal_reward(reason_after);
        result.termination_reason = map_reason(reason_after);
        return result;
    }

    bool undo_move() {
        if (ply_ == 0) {
            return false;
        }

        const chess::Move last = move_history_[--ply_];
        board_.unmakeMove(last);

        if (history_count_ > 1) {
            history_head_ = (history_head_ + kHistoryFrames - 1) % kHistoryFrames;
            --history_count_;
        }

        castle_mask_ = castle_history_[history_head_];
        return true;
    }

    // ── Primary NN input: 20 planes × 64 squares = 1280 floats ──────────────
    // Layout (must match Python encode_board exactly):
    //   Planes  0-11: piece bitboards (W_P,W_N,W_B,W_R,W_Q,W_K, B_P..B_K)
    //   Plane   12  : turn (all 1.0 = white to move, all 0.0 = black)
    //   Planes 13-16: castling rights WK, WQ, BK, BQ (all 1.0 / all 0.0)
    //   Plane   17  : en-passant square (1.0 at EP square only)
    //   Plane   18  : rep1 — this position seen ≥1 time before (all 1.0 or 0.0)
    //   Plane   19  : rep2 — this position seen ≥2 times before (all 1.0 or 0.0)
    void write_nn_planes(float* dst) const noexcept {
        std::fill_n(dst, kStateSize, 0.0f);

        // ── Planes 0-11: piece positions ────────────────────────────────────
        const FrameSnapshot& snap = history_[history_head_];
        encode_snapshot_into(snap, dst);    // writes planes 0-11

        // ── Plane 12: turn ──────────────────────────────────────────────────
        float* turn_plane = dst + 12 * 64;
        if (board_.sideToMove() == chess::Color::WHITE) {
            std::fill_n(turn_plane, 64, 1.0f);
        }
        // else: already 0.0 from fill_n above

        // ── Planes 13-16: castling rights ───────────────────────────────────
        if (has_castle(castle_mask_, CastleRights::WhiteKingSide))
            std::fill_n(dst + 13 * 64, 64, 1.0f);
        if (has_castle(castle_mask_, CastleRights::WhiteQueenSide))
            std::fill_n(dst + 14 * 64, 64, 1.0f);
        if (has_castle(castle_mask_, CastleRights::BlackKingSide))
            std::fill_n(dst + 15 * 64, 64, 1.0f);
        if (has_castle(castle_mask_, CastleRights::BlackQueenSide))
            std::fill_n(dst + 16 * 64, 64, 1.0f);

        // ── Plane 17: en passant ────────────────────────────────────────────
        {
            const int ep_idx = static_cast<int>(board_.enpassantSq().index());
            if (ep_idx < 64) {
                dst[17 * 64 + ep_idx] = 1.0f;
            }
        }

        // ── Planes 18-19: repetition counters ──────────────────────────────
        // Count how many earlier frames have the same piece configuration.
        {
            const auto& cur = history_[history_head_];
            int rep_count = 0;
            const std::size_t frames_to_check = std::min(history_count_ - 1, kHistoryFrames - 1);
            for (std::size_t f = 1; f <= frames_to_check; ++f) {
                const std::size_t idx = (history_head_ + kHistoryFrames - f) % kHistoryFrames;
                if (history_[idx].planes == cur.planes) {
                    ++rep_count;
                }
            }
            if (rep_count >= 1) std::fill_n(dst + 18 * 64, 64, 1.0f);
            if (rep_count >= 2) std::fill_n(dst + 19 * 64, 64, 1.0f);
        }
    }

    void write_nn_planes(std::vector<float>& out) const {
        out.resize(kStateSize);
        write_nn_planes(out.data());
    }

    void write_stacked_state_tensor(float* out, std::size_t capacity, std::size_t frames = kHistoryFrames) const {
        assert(out != nullptr);
        assert(frames > 0);
        assert(capacity >= stacked_state_size(frames));

        const std::size_t needed = stacked_state_size(frames);
        std::fill_n(out, needed, 0.0f);   // zero-init: absent frames stay as zeros (AlphaZero convention)

        // Only encode the frames we actually have; the rest remain 0-padded
        const std::size_t avail = std::min(frames, history_count_);
        for (std::size_t frame = 0; frame < avail; ++frame) {
            const FrameSnapshot& snap = snapshot_for_frame(frame);
            encode_snapshot_into(snap, out + frame * kStateSize);
        }

        write_scalar_features(out + frames * kStateSize);
    }

    void write_stacked_state_tensor(std::vector<float>& out, std::size_t frames = kHistoryFrames) const {
        const std::size_t needed = stacked_state_size(frames);
        if (out.size() < needed) {
            out.resize(needed);
        }
        write_stacked_state_tensor(out.data(), out.size(), frames);
    }

    std::size_t stacked_state_size(std::size_t frames = kHistoryFrames) const noexcept {
        return frames * kStateSize + kScalarCount;
    }

private:
    chess::Board board_;

    std::array<chess::Move, kMaxPlies> move_history_{};
    std::size_t ply_ = 0;

    std::array<FrameSnapshot, kHistoryFrames> history_{};
    std::array<std::uint8_t, kHistoryFrames> castle_history_{};
    std::size_t history_head_ = 0;
    std::size_t history_count_ = 0;

    std::uint8_t castle_mask_ = 0;

private:
    enum PlaneIndex : std::size_t {
        W_PAWN = 0,
        W_KNIGHT = 1,
        W_BISHOP = 2,
        W_ROOK = 3,
        W_QUEEN = 4,
        W_KING = 5,
        B_PAWN = 6,
        B_KNIGHT = 7,
        B_BISHOP = 8,
        B_ROOK = 9,
        B_QUEEN = 10,
        B_KING = 11
    };

    static constexpr int SQ_A1 = static_cast<int>(chess::Square::SQ_A1);
    static constexpr int SQ_H1 = static_cast<int>(chess::Square::SQ_H1);
    static constexpr int SQ_A8 = static_cast<int>(chess::Square::SQ_A8);
    static constexpr int SQ_H8 = static_cast<int>(chess::Square::SQ_H8);
    static constexpr int SQ_E1 = static_cast<int>(chess::Square::SQ_E1);
    static constexpr int SQ_E8 = static_cast<int>(chess::Square::SQ_E8);

    static inline int ctz64(std::uint64_t x) noexcept {
        assert(x != 0);
    #if defined(_MSC_VER)
        unsigned long idx = 0;
        _BitScanForward64(&idx, x);
        return static_cast<int>(idx);
    #else
        return __builtin_ctzll(x);
    #endif
    }

    static FrameSnapshot snapshot_from_board(const chess::Board& b) {
        FrameSnapshot snap;

        static constexpr std::array<chess::PieceType, 6> order = {
            chess::PieceType::PAWN,
            chess::PieceType::KNIGHT,
            chess::PieceType::BISHOP,
            chess::PieceType::ROOK,
            chess::PieceType::QUEEN,
            chess::PieceType::KING
        };

        for (int i = 0; i < 6; ++i) {
            snap.planes[i]     = b.pieces(order[i], chess::Color::WHITE).getBits();
            snap.planes[6 + i] = b.pieces(order[i], chess::Color::BLACK).getBits();
        }

        return snap;
    }

    static void encode_snapshot_into(const FrameSnapshot& snap, float* dst) noexcept {
        for (std::size_t plane = 0; plane < 12; ++plane) {
            std::uint64_t bits = snap.planes[plane];
            float* plane_out = dst + plane * 64;

            while (bits) {
                const int sq = ctz64(bits);
                plane_out[sq] = 1.0f;
                bits &= (bits - 1);
            }
        }
    }

    const FrameSnapshot& snapshot_for_frame(std::size_t frame) const noexcept {
        // Caller (write_stacked_state_tensor) guarantees frame < history_count_
        assert(history_count_ > 0 && frame < history_count_);
        const std::size_t idx = (history_head_ + kHistoryFrames - frame) % kHistoryFrames;
        return history_[idx];
    }

    void push_history(const FrameSnapshot& snap, std::uint8_t next_castle_mask) {
        history_head_ = (history_head_ + 1) % kHistoryFrames;
        history_[history_head_] = snap;
        castle_history_[history_head_] = next_castle_mask;
        castle_mask_ = next_castle_mask;

        if (history_count_ < kHistoryFrames) {
            ++history_count_;
        }
    }

    void write_scalar_features(float* dst) const noexcept {
        dst[0] = (board_.sideToMove() == chess::Color::WHITE) ? 1.0f : 0.0f;
        dst[1] = has_castle(castle_mask_, CastleRights::WhiteKingSide)  ? 1.0f : 0.0f;
        dst[2] = has_castle(castle_mask_, CastleRights::WhiteQueenSide) ? 1.0f : 0.0f;
        dst[3] = has_castle(castle_mask_, CastleRights::BlackKingSide)  ? 1.0f : 0.0f;
        dst[4] = has_castle(castle_mask_, CastleRights::BlackQueenSide) ? 1.0f : 0.0f;
        // En-passant file: (file_index + 1) / 8.0 ∈ (0, 1]; 0.0 = no EP.
        // NO_SQ has index >= 64 in chess-library.
        const int ep_idx = static_cast<int>(board_.enpassantSq().index());
        dst[5] = (ep_idx < 64)
            ? (static_cast<float>(ep_idx & 7) + 1.0f) / 8.0f
            : 0.0f;
    }

    static TerminationReason map_reason(chess::GameResultReason reason) noexcept {
        switch (reason) {
            case chess::GameResultReason::CHECKMATE:
                return TerminationReason::Checkmate;
            case chess::GameResultReason::STALEMATE:
                return TerminationReason::Stalemate;
            case chess::GameResultReason::FIFTY_MOVE_RULE:
                return TerminationReason::FiftyMoveRule;
            case chess::GameResultReason::INSUFFICIENT_MATERIAL:
                return TerminationReason::InsufficientMaterial;
            case chess::GameResultReason::THREEFOLD_REPETITION:
                return TerminationReason::ThreefoldRepetition;
            case chess::GameResultReason::NONE:
            default:
                return TerminationReason::Ongoing;
        }
    }

    float terminal_reward(chess::GameResultReason reason) const noexcept {
        if (reason == chess::GameResultReason::CHECKMATE) {
            return (board_.sideToMove() == chess::Color::WHITE) ? -1.0f : 1.0f;
        }
        return 0.0f;
    }

    static std::uint8_t update_castle_mask(const FrameSnapshot& before,
                                           const chess::Move& move,
                                           std::uint8_t current_mask) noexcept {
        const int from = static_cast<int>(move.from().index());
        const int to   = static_cast<int>(move.to().index());

        const std::uint64_t from_bb = 1ULL << from;
        const std::uint64_t to_bb   = 1ULL << to;

        if (before.planes[W_KING] & from_bb) {
            current_mask &= ~(castle_mask(CastleRights::WhiteKingSide) |
                              castle_mask(CastleRights::WhiteQueenSide));
        }
        if (before.planes[B_KING] & from_bb) {
            current_mask &= ~(castle_mask(CastleRights::BlackKingSide) |
                              castle_mask(CastleRights::BlackQueenSide));
        }

        if (before.planes[W_ROOK] & from_bb) {
            if (from == SQ_H1) current_mask &= ~castle_mask(CastleRights::WhiteKingSide);
            if (from == SQ_A1) current_mask &= ~castle_mask(CastleRights::WhiteQueenSide);
        }
        if (before.planes[B_ROOK] & from_bb) {
            if (from == SQ_H8) current_mask &= ~castle_mask(CastleRights::BlackKingSide);
            if (from == SQ_A8) current_mask &= ~castle_mask(CastleRights::BlackQueenSide);
        }

        if (before.planes[W_ROOK] & to_bb) {
            if (to == SQ_H1) current_mask &= ~castle_mask(CastleRights::WhiteKingSide);
            if (to == SQ_A1) current_mask &= ~castle_mask(CastleRights::WhiteQueenSide);
        }
        if (before.planes[B_ROOK] & to_bb) {
            if (to == SQ_H8) current_mask &= ~castle_mask(CastleRights::BlackKingSide);
            if (to == SQ_A8) current_mask &= ~castle_mask(CastleRights::BlackQueenSide);
        }

        return current_mask;
    }
};



#endif  // CHESS_ENV_CPP_INCLUDED
