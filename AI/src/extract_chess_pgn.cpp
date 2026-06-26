#include <algorithm>
#include <array>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <signal.h>
#include <stdexcept>
#include <string>
#include <vector>

#ifndef _WIN32
#include <unistd.h>
#include <sys/types.h>
#else
#include <io.h>
#endif

namespace fs = std::filesystem;

static constexpr std::size_t PLANE_COUNT = 12;
static constexpr std::size_t SQUARE_COUNT = 64;
static constexpr std::size_t PLANE_BYTES = PLANE_COUNT * SQUARE_COUNT;
static constexpr std::size_t MOVE_BYTES = 8;
static constexpr std::size_t SAMPLE_BYTES = PLANE_BYTES + MOVE_BYTES;

static constexpr std::uint16_t VERSION = 2;
static constexpr std::uint32_t HEADER_SIZE = 36;
static constexpr std::uint32_t GAME_HEADER_SIZE = 11;

static constexpr int WHITE = 0;
static constexpr int BLACK = 1;

static constexpr int PAWN = 1;
static constexpr int KNIGHT = 2;
static constexpr int BISHOP = 3;
static constexpr int ROOK = 4;
static constexpr int QUEEN = 5;
static constexpr int KING = 6;

static constexpr int CASTLE_WK = 1 << 0;
static constexpr int CASTLE_WQ = 1 << 1;
static constexpr int CASTLE_BK = 1 << 2;
static constexpr int CASTLE_BQ = 1 << 3;

static constexpr std::uint8_t FLAG_CAPTURE = 1 << 0;
static constexpr std::uint8_t FLAG_EP = 1 << 1;
static constexpr std::uint8_t FLAG_CASTLE = 1 << 2;
static constexpr std::uint8_t FLAG_DOUBLE = 1 << 3;

static std::atomic<bool> g_stopRequested{false};

static void onSignal(int) {
    g_stopRequested.store(true, std::memory_order_relaxed);
    std::cerr << "\n[STOP] Đã nhận yêu cầu dừng. Sẽ hoàn tất file hiện tại rồi đóng dataset an toàn...\n";
}

static inline int fileOf(int sq) { return sq & 7; }
static inline int rankOf(int sq) { return sq >> 3; }
static inline bool onBoard(int sq) { return sq >= 0 && sq < 64; }

static inline std::string rstrip_cr(std::string s) {
    if (!s.empty() && s.back() == '\r') s.pop_back();
    return s;
}

static inline std::string trim_copy(const std::string& s) {
    std::size_t b = 0, e = s.size();
    while (b < e && std::isspace(static_cast<unsigned char>(s[b]))) ++b;
    while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1]))) --e;
    return s.substr(b, e - b);
}

static inline bool ends_with(const std::string& s, const std::string& suf) {
    return s.size() >= suf.size() && s.compare(s.size() - suf.size(), suf.size(), suf) == 0;
}

static inline bool is_move_number_token(const std::string& t) {
    if (t.empty()) return false;
    bool hasDot = false;
    for (char c : t) {
        if (c == '.') hasDot = true;
        else if (!std::isdigit(static_cast<unsigned char>(c))) return false;
    }
    return hasDot;
}

static inline int parse_int_safe(const std::string& s, int fallback = -1) {
    try {
        return std::stoi(s);
    } catch (...) {
        return fallback;
    }
}

static inline char piece_letter_upper(int pieceType) {
    switch (pieceType) {
        case KNIGHT: return 'N';
        case BISHOP: return 'B';
        case ROOK:   return 'R';
        case QUEEN:  return 'Q';
        case KING:   return 'K';
        default:     return '\0';
    }
}

static inline char promo_char_lower(int pieceType) {
    switch (pieceType) {
        case KNIGHT: return 'n';
        case BISHOP: return 'b';
        case ROOK:   return 'r';
        case QUEEN:  return 'q';
        default:     return '\0';
    }
}

static inline int make_piece(int color, int pieceType) {
    return color == WHITE ? pieceType : -pieceType;
}

static inline int piece_type(int piece) {
    return piece < 0 ? -piece : piece;
}

static inline int piece_color(int piece) {
    return piece > 0 ? WHITE : BLACK;
}

static inline char file_char(int sq) { return static_cast<char>('a' + fileOf(sq)); }
static inline char rank_char(int sq) { return static_cast<char>('1' + rankOf(sq)); }

static std::string square_to_string(int sq) {
    std::string s;
    s.push_back(file_char(sq));
    s.push_back(rank_char(sq));
    return s;
}

static std::string move_to_uci_string(int from, int to, int promoPieceType = 0) {
    std::string s;
    s.reserve(5);
    s += square_to_string(from);
    s += square_to_string(to);
    if (promoPieceType != 0) s.push_back(promo_char_lower(promoPieceType));
    return s;
}

struct Board {
    int sq[64]{};
    int side = WHITE;
    int castle = CASTLE_WK | CASTLE_WQ | CASTLE_BK | CASTLE_BQ;
    int ep = -1;
    int kingSq[2]{4, 60};
};

struct Move {
    std::uint8_t from = 0;
    std::uint8_t to = 0;
    std::uint8_t promo = 0;
    std::uint8_t flags = 0;
};

struct Undo {
    int captured = 0;
    int capturedSq = -1;
    int castle = 0;
    int ep = -1;
    int kingSqW = 4;
    int kingSqB = 60;
    int side = WHITE;
};

struct GameRecord {
    int whiteElo = -1;
    int blackElo = -1;
    std::string result = "*";
    bool hasFen = false;
    bool setup = false;
    std::string fen;
    std::string movetext;
};

static void write_raw(FILE* f, const void* data, std::size_t n) {
    if (n == 0) return;
    if (std::fwrite(data, 1, n, f) != n) throw std::runtime_error("write failed");
}

static void write_u8(FILE* f, std::uint8_t v) { write_raw(f, &v, 1); }
static void write_s8(FILE* f, std::int8_t v)   { write_raw(f, &v, 1); }

static void write_u16(FILE* f, std::uint16_t v) {
    std::uint8_t b[2];
    b[0] = static_cast<std::uint8_t>(v & 0xFFu);
    b[1] = static_cast<std::uint8_t>((v >> 8) & 0xFFu);
    write_raw(f, b, 2);
}

static void write_u32(FILE* f, std::uint32_t v) {
    std::uint8_t b[4];
    b[0] = static_cast<std::uint8_t>(v & 0xFFu);
    b[1] = static_cast<std::uint8_t>((v >> 8) & 0xFFu);
    b[2] = static_cast<std::uint8_t>((v >> 16) & 0xFFu);
    b[3] = static_cast<std::uint8_t>((v >> 24) & 0xFFu);
    write_raw(f, b, 4);
}

static void write_u64(FILE* f, std::uint64_t v) {
    std::uint8_t b[8];
    b[0] = static_cast<std::uint8_t>(v & 0xFFu);
    b[1] = static_cast<std::uint8_t>((v >> 8) & 0xFFu);
    b[2] = static_cast<std::uint8_t>((v >> 16) & 0xFFu);
    b[3] = static_cast<std::uint8_t>((v >> 24) & 0xFFu);
    b[4] = static_cast<std::uint8_t>((v >> 32) & 0xFFu);
    b[5] = static_cast<std::uint8_t>((v >> 40) & 0xFFu);
    b[6] = static_cast<std::uint8_t>((v >> 48) & 0xFFu);
    b[7] = static_cast<std::uint8_t>((v >> 56) & 0xFFu);
    write_raw(f, b, 8);
}

static std::uint64_t file_tell64(FILE* f) {
#ifdef _WIN32
    return static_cast<std::uint64_t>(_ftelli64(f));
#else
    return static_cast<std::uint64_t>(ftello(f));
#endif
}

static void file_seek64(FILE* f, std::uint64_t pos) {
#ifdef _WIN32
    if (_fseeki64(f, static_cast<__int64>(pos), SEEK_SET) != 0) throw std::runtime_error("seek failed");
#else
    if (fseeko(f, static_cast<off_t>(pos), SEEK_SET) != 0) throw std::runtime_error("seek failed");
#endif
}

static void file_truncate64(FILE* f, std::uint64_t size) {
#ifdef _WIN32
    int fd = _fileno(f);
    if (_chsize_s(fd, static_cast<__int64>(size)) != 0) throw std::runtime_error("truncate failed");
#else
    int fd = fileno(f);
    if (ftruncate(fd, static_cast<off_t>(size)) != 0) throw std::runtime_error("truncate failed");
#endif
}

static void truncate_to(FILE* f, std::uint64_t pos) {
    std::fflush(f);
    file_truncate64(f, pos);
    file_seek64(f, pos);
}

static int result_to_code(const std::string& r) {
    if (r == "1-0") return 1;
    if (r == "0-1") return -1;
    return 0;
}

static void write_dataset_header(FILE* f, std::uint64_t totalSamples, std::uint32_t totalGames) {
    file_seek64(f, 0);
    write_raw(f, "CHSDBIN2", 8);
    write_u16(f, VERSION);
    write_u16(f, static_cast<std::uint16_t>(HEADER_SIZE));
    write_u64(f, totalSamples);
    write_u32(f, totalGames);
    write_u32(f, static_cast<std::uint32_t>(SAMPLE_BYTES));
    write_u32(f, GAME_HEADER_SIZE);
    write_u32(f, 0);
}

// Alias: patching the header after writing is the same operation.
static inline void patch_dataset_header(FILE* f, std::uint64_t totalSamples, std::uint32_t totalGames) {
    write_dataset_header(f, totalSamples, totalGames);
}

static void write_game_header_placeholder(FILE* f, int whiteElo, int blackElo, int resultCode) {
    write_u8(f, 1);
    write_u32(f, 0);
    write_u16(f, static_cast<std::uint16_t>(whiteElo));
    write_u16(f, static_cast<std::uint16_t>(blackElo));
    write_s8(f, static_cast<std::int8_t>(resultCode));
    write_u8(f, 0);
}

static void patch_game_sample_count(FILE* f, std::uint64_t sampleCountPos, std::uint32_t count) {
    auto cur = file_tell64(f);
    file_seek64(f, sampleCountPos);
    write_u32(f, count);
    file_seek64(f, cur);
}

static bool parse_fen(const std::string& fen, Board& b) {
    std::memset(b.sq, 0, sizeof(b.sq));
    b.side = WHITE;
    b.castle = 0;
    b.ep = -1;
    b.kingSq[WHITE] = 4;
    b.kingSq[BLACK] = 60;

    std::vector<std::string> parts;
    parts.reserve(6);
    std::size_t i = 0;
    while (i < fen.size()) {
        while (i < fen.size() && std::isspace(static_cast<unsigned char>(fen[i]))) ++i;
        if (i >= fen.size()) break;
        std::size_t j = i;
        while (j < fen.size() && !std::isspace(static_cast<unsigned char>(fen[j]))) ++j;
        parts.push_back(fen.substr(i, j - i));
        i = j;
    }
    if (parts.size() < 4) return false;

    const std::string& placement = parts[0];
    int sq = 56;
    for (char c : placement) {
        if (c == '/') {
            sq -= 16;
            continue;
        }
        if (c >= '1' && c <= '8') {
            sq += c - '0';
            continue;
        }
        int color = std::islower(static_cast<unsigned char>(c)) ? BLACK : WHITE;
        char u = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
        int pt = 0;
        switch (u) {
            case 'P': pt = PAWN; break;
            case 'N': pt = KNIGHT; break;
            case 'B': pt = BISHOP; break;
            case 'R': pt = ROOK; break;
            case 'Q': pt = QUEEN; break;
            case 'K': pt = KING; break;
            default: return false;
        }
        if (!onBoard(sq)) return false;
        b.sq[sq] = make_piece(color, pt);
        if (pt == KING) b.kingSq[color] = sq;
        ++sq;
    }

    b.side = (parts[1] == "b") ? BLACK : WHITE;

    const std::string& castle = parts[2];
    if (castle.find('K') != std::string::npos) b.castle |= CASTLE_WK;
    if (castle.find('Q') != std::string::npos) b.castle |= CASTLE_WQ;
    if (castle.find('k') != std::string::npos) b.castle |= CASTLE_BK;
    if (castle.find('q') != std::string::npos) b.castle |= CASTLE_BQ;

    const std::string& ep = parts[3];
    if (ep != "-" && ep.size() == 2) {
        if (ep[0] >= 'a' && ep[0] <= 'h' && ep[1] >= '1' && ep[1] <= '8') {
            int f = ep[0] - 'a';
            int r = ep[1] - '1';
            b.ep = r * 8 + f;
        }
    }

    return true;
}

static void init_startpos(Board& b) {
    std::memset(b.sq, 0, sizeof(b.sq));
    b.side = WHITE;
    b.castle = CASTLE_WK | CASTLE_WQ | CASTLE_BK | CASTLE_BQ;
    b.ep = -1;

    auto put = [&](int sq, int color, int pt) { b.sq[sq] = make_piece(color, pt); };

    put(0, WHITE, ROOK);   put(1, WHITE, KNIGHT); put(2, WHITE, BISHOP); put(3, WHITE, QUEEN);
    put(4, WHITE, KING);    put(5, WHITE, BISHOP); put(6, WHITE, KNIGHT); put(7, WHITE, ROOK);
    for (int i = 8; i < 16; ++i) put(i, WHITE, PAWN);

    put(56, BLACK, ROOK);   put(57, BLACK, KNIGHT); put(58, BLACK, BISHOP); put(59, BLACK, QUEEN);
    put(60, BLACK, KING);    put(61, BLACK, BISHOP); put(62, BLACK, KNIGHT); put(63, BLACK, ROOK);
    for (int i = 48; i < 56; ++i) put(i, BLACK, PAWN);

    b.kingSq[WHITE] = 4;
    b.kingSq[BLACK] = 60;
}

static bool parse_tag_line(const std::string& line, GameRecord& g) {
    if (line.empty() || line[0] != '[') return false;
    std::size_t sp = line.find(' ');
    std::size_t q1 = line.find('"', sp == std::string::npos ? 0 : sp);
    std::size_t q2 = line.rfind('"');
    if (sp == std::string::npos || q1 == std::string::npos || q2 == std::string::npos || q2 <= q1) return false;

    std::string key = line.substr(1, sp - 1);
    std::string value = line.substr(q1 + 1, q2 - q1 - 1);

    if (key == "WhiteElo") g.whiteElo = parse_int_safe(value, -1);
    else if (key == "BlackElo") g.blackElo = parse_int_safe(value, -1);
    else if (key == "Result") g.result = value;
    else if (key == "SetUp") g.setup = (value == "1");
    else if (key == "FEN") {
        g.hasFen = true;
        g.fen = value;
    }

    return true;
}

static bool is_result_token(const std::string& t) {
    return t == "1-0" || t == "0-1" || t == "1/2-1/2" || t == "*";
}

static std::string clean_pgn_token(std::string t) {
    t = trim_copy(t);
    if (t.empty()) return t;

    // Remove leading move numbers like "12.", "12...", "1.e4" -> "e4"
    std::size_t i = 0;
    while (i < t.size() && std::isdigit(static_cast<unsigned char>(t[i]))) {
        ++i;
    }
    // Only strip if the token is clearly a move number like "12." or "12...".
    // Keep results like "1-0" and "1/2-1/2" intact.
    if (i > 0 && i < t.size() && t[i] == '.') {
        while (i < t.size() && t[i] == '.') ++i;
        t.erase(0, i);
    }

    // Some PGNs pack move numbers with ellipsis directly into the token.
    while (t.size() >= 3 && t[0] == '.' && t[1] == '.' && t[2] == '.') {
        t.erase(0, 3);
    }

    // Remove NAG suffixes like "$1", "$23".
    std::size_t dollar = t.find('$');
    if (dollar != std::string::npos) {
        t.erase(dollar);
    }

    return trim_copy(t);
}

static std::string normalize_san_token(std::string t) {
    t = clean_pgn_token(std::move(t));
    std::string out;
    out.reserve(t.size());
    for (char c : t) {
        if (c == '+' || c == '#' || c == '!' || c == '?' || c == '.') continue;
        if (c == '0' || c == 'o' || c == 'O') c = 'O';
        out.push_back(c);
    }
    return out;
}

static bool is_ignorable_token(const std::string& raw) {
    std::string t = clean_pgn_token(raw);
    if (t.empty()) return true;
    if (t[0] == '$') return true;
    if (is_move_number_token(t)) return true;
    return false;
}

struct TokenReader {
    const std::string& s;
    std::size_t i = 0;
    int parenDepth = 0;
    bool inBrace = false;

    explicit TokenReader(const std::string& str) : s(str) {}

    bool next(std::string& out) {
        out.clear();
        while (i < s.size()) {
            char c = s[i];

            if (inBrace) {
                ++i;
                if (c == '}') inBrace = false;
                continue;
            }

            if (parenDepth > 0) {
                ++i;
                if (c == '(') ++parenDepth;
                else if (c == ')') --parenDepth;
                continue;
            }

            if (std::isspace(static_cast<unsigned char>(c))) {
                ++i;
                continue;
            }

            if (c == '{') {
                inBrace = true;
                ++i;
                continue;
            }

            if (c == ';') {
                while (i < s.size() && s[i] != '\n') ++i;
                continue;
            }

            if (c == '(') {
                parenDepth = 1;
                ++i;
                continue;
            }

            if (c == ')') {
                ++i;
                continue;
            }

            while (i < s.size()) {
                c = s[i];
                if (std::isspace(static_cast<unsigned char>(c)) || c == '{' || c == ';' || c == '(' || c == ')') break;
                out.push_back(c);
                ++i;
            }

            if (!out.empty()) return true;
        }
        return false;
    }
};

static bool is_square_attacked(const Board& b, int sq, int bySide) {
    int r = rankOf(sq);
    int f = fileOf(sq);

    if (bySide == WHITE) {
        if (r > 0 && f > 0 && b.sq[sq - 9] == make_piece(WHITE, PAWN)) return true;
        if (r > 0 && f < 7 && b.sq[sq - 7] == make_piece(WHITE, PAWN)) return true;
    } else {
        if (r < 7 && f > 0 && b.sq[sq + 7] == make_piece(BLACK, PAWN)) return true;
        if (r < 7 && f < 7 && b.sq[sq + 9] == make_piece(BLACK, PAWN)) return true;
    }

    static constexpr int knightDf[8] = { 1, 2, 2, 1, -1, -2, -2, -1 };
    static constexpr int knightDr[8] = { 2, 1, -1, -2, -2, -1, 1, 2 };
    for (int k = 0; k < 8; ++k) {
        int nf = f + knightDf[k];
        int nr = r + knightDr[k];
        if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
        int t = nr * 8 + nf;
        if (b.sq[t] == make_piece(bySide, KNIGHT)) return true;
    }

    static constexpr int kingDf[8] = { 1, 1, 0, -1, -1, -1, 0, 1 };
    static constexpr int kingDr[8] = { 0, 1, 1, 1, 0, -1, -1, -1 };
    for (int k = 0; k < 8; ++k) {
        int nf = f + kingDf[k];
        int nr = r + kingDr[k];
        if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
        int t = nr * 8 + nf;
        if (b.sq[t] == make_piece(bySide, KING)) return true;
    }

    auto ray_attacked = [&](int df, int dr, bool bishopLike) {
        int nf = f + df;
        int nr = r + dr;
        while (nf >= 0 && nf <= 7 && nr >= 0 && nr <= 7) {
            int t = nr * 8 + nf;
            int p = b.sq[t];
            if (p != 0) {
                if (piece_color(p) == bySide) {
                    int pt = piece_type(p);
                    if (pt == QUEEN) return true;
                    if (bishopLike && pt == BISHOP) return true;
                    if (!bishopLike && pt == ROOK) return true;
                }
                return false;
            }
            nf += df;
            nr += dr;
        }
        return false;
    };

    if (ray_attacked(1, 1, true)) return true;
    if (ray_attacked(-1, 1, true)) return true;
    if (ray_attacked(1, -1, true)) return true;
    if (ray_attacked(-1, -1, true)) return true;
    if (ray_attacked(1, 0, false)) return true;
    if (ray_attacked(-1, 0, false)) return true;
    if (ray_attacked(0, 1, false)) return true;
    if (ray_attacked(0, -1, false)) return true;

    return false;
}

static bool is_in_check(const Board& b, int side) {
    return is_square_attacked(b, b.kingSq[side], side ^ 1);
}

static void make_move(Board& b, const Move& m, Undo& u) {
    u.captured = 0;
    u.capturedSq = -1;
    u.castle = b.castle;
    u.ep = b.ep;
    u.kingSqW = b.kingSq[WHITE];
    u.kingSqB = b.kingSq[BLACK];
    u.side = b.side;

    int side = b.side;
    int moving = b.sq[m.from];
    int from = m.from;
    int to = m.to;

    if (m.flags & FLAG_EP) {
        u.capturedSq = (side == WHITE) ? (to - 8) : (to + 8);
        u.captured = b.sq[u.capturedSq];
        b.sq[u.capturedSq] = 0;
    } else if (m.flags & FLAG_CAPTURE) {
        u.capturedSq = to;
        u.captured = b.sq[to];
        b.sq[to] = 0;
    }

    b.sq[from] = 0;

    int placed = moving;
    if (m.promo != 0) placed = make_piece(side, m.promo);

    b.sq[to] = placed;

    if (piece_type(moving) == KING) {
        b.kingSq[side] = to;
        if (side == WHITE) b.castle &= ~(CASTLE_WK | CASTLE_WQ);
        else b.castle &= ~(CASTLE_BK | CASTLE_BQ);
    }

    if (piece_type(moving) == ROOK) {
        if (from == 0) b.castle &= ~CASTLE_WQ;
        else if (from == 7) b.castle &= ~CASTLE_WK;
        else if (from == 56) b.castle &= ~CASTLE_BQ;
        else if (from == 63) b.castle &= ~CASTLE_BK;
    }

    if (u.captured != 0 && piece_type(u.captured) == ROOK) {
        if (u.capturedSq == 0) b.castle &= ~CASTLE_WQ;
        else if (u.capturedSq == 7) b.castle &= ~CASTLE_WK;
        else if (u.capturedSq == 56) b.castle &= ~CASTLE_BQ;
        else if (u.capturedSq == 63) b.castle &= ~CASTLE_BK;
    }

    if (m.flags & FLAG_CASTLE) {
        if (side == WHITE) {
            if (to == 6) {
                b.sq[5] = b.sq[7];
                b.sq[7] = 0;
            } else if (to == 2) {
                b.sq[3] = b.sq[0];
                b.sq[0] = 0;
            }
        } else {
            if (to == 62) {
                b.sq[61] = b.sq[63];
                b.sq[63] = 0;
            } else if (to == 58) {
                b.sq[59] = b.sq[56];
                b.sq[56] = 0;
            }
        }
    }

    if (m.flags & FLAG_DOUBLE) {
        b.ep = (side == WHITE) ? (from + 8) : (from - 8);
    } else {
        b.ep = -1;
    }

    b.side ^= 1;
}

static void undo_move(Board& b, const Move& m, const Undo& u) {
    b.side = u.side;
    b.castle = u.castle;
    b.ep = u.ep;
    b.kingSq[WHITE] = u.kingSqW;
    b.kingSq[BLACK] = u.kingSqB;

    int side = b.side;
    int from = m.from;
    int to = m.to;

    if (m.flags & FLAG_CASTLE) {
        if (side == WHITE) {
            if (to == 6) {
                b.sq[7] = b.sq[5];
                b.sq[5] = 0;
            } else if (to == 2) {
                b.sq[0] = b.sq[3];
                b.sq[3] = 0;
            }
        } else {
            if (to == 62) {
                b.sq[63] = b.sq[61];
                b.sq[61] = 0;
            } else if (to == 58) {
                b.sq[56] = b.sq[59];
                b.sq[59] = 0;
            }
        }
    }

    b.sq[from] = b.sq[to];
    b.sq[to] = 0;

    if (m.promo != 0) {
        b.sq[from] = make_piece(side, PAWN);
    }

    if (u.captured != 0 && u.capturedSq >= 0) {
        b.sq[u.capturedSq] = u.captured;
    }
}

static void add_legal_if(Board& b, const Move& m, std::vector<Move>& out) {
    int side = b.side;
    Undo u;
    make_move(b, m, u);
    if (!is_in_check(b, side)) out.push_back(m);
    undo_move(b, m, u);
}

static void gen_legal_moves(Board& b, std::vector<Move>& out) {
    out.clear();
    out.reserve(64);
    int side = b.side;

    for (int from = 0; from < 64; ++from) {
        int p = b.sq[from];
        if (p == 0 || piece_color(p) != side) continue;

        int pt = piece_type(p);
        int r = rankOf(from);
        int f = fileOf(from);

        if (pt == PAWN) {
            int dir = (side == WHITE) ? 8 : -8;
            int startRank = (side == WHITE) ? 1 : 6;
            int promoFromRank = (side == WHITE) ? 6 : 1;
            int lastRank = (side == WHITE) ? 7 : 0;

            int one = from + dir;
            if (onBoard(one) && b.sq[one] == 0) {
                if (r == promoFromRank) {
                    for (int promo : {KNIGHT, BISHOP, ROOK, QUEEN}) {
                        Move m{};
                        m.from = static_cast<std::uint8_t>(from);
                        m.to = static_cast<std::uint8_t>(one);
                        m.promo = static_cast<std::uint8_t>(promo);
                        add_legal_if(b, m, out);
                    }
                } else {
                    Move m{};
                    m.from = static_cast<std::uint8_t>(from);
                    m.to = static_cast<std::uint8_t>(one);
                    add_legal_if(b, m, out);

                    if (r == startRank) {
                        int two = from + 2 * dir;
                        if (onBoard(two) && b.sq[two] == 0) {
                            Move d{};
                            d.from = static_cast<std::uint8_t>(from);
                            d.to = static_cast<std::uint8_t>(two);
                            d.flags = FLAG_DOUBLE;
                            add_legal_if(b, d, out);
                        }
                    }
                }
            }

            int capDirs[2] = { dir + 1, dir - 1 };
            for (int k = 0; k < 2; ++k) {
                int to = from + capDirs[k];
                if (!onBoard(to)) continue;
                int tf = fileOf(to);
                int tr = rankOf(to);
                if (std::abs(tf - f) != 1) continue;
                bool isEP = (b.ep == to);
                bool isEnemy = (b.sq[to] != 0 && piece_color(b.sq[to]) != side);
                if (!isEP && !isEnemy) continue;

                if (tr == lastRank) {
                    for (int promo : {KNIGHT, BISHOP, ROOK, QUEEN}) {
                        Move m{};
                        m.from = static_cast<std::uint8_t>(from);
                        m.to = static_cast<std::uint8_t>(to);
                        m.promo = static_cast<std::uint8_t>(promo);
                        m.flags = static_cast<std::uint8_t>(isEP ? FLAG_EP : FLAG_CAPTURE);
                        add_legal_if(b, m, out);
                    }
                } else {
                    Move m{};
                    m.from = static_cast<std::uint8_t>(from);
                    m.to = static_cast<std::uint8_t>(to);
                    m.flags = static_cast<std::uint8_t>(isEP ? FLAG_EP : FLAG_CAPTURE);
                    add_legal_if(b, m, out);
                }
            }
        } else if (pt == KNIGHT) {
            static constexpr int df[8] = { 1, 2, 2, 1, -1, -2, -2, -1 };
            static constexpr int dr[8] = { 2, 1, -1, -2, -2, -1, 1, 2 };
            for (int k = 0; k < 8; ++k) {
                int nf = f + df[k];
                int nr = r + dr[k];
                if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
                int to = nr * 8 + nf;
                if (b.sq[to] != 0 && piece_color(b.sq[to]) == side) continue;
                Move m{};
                m.from = static_cast<std::uint8_t>(from);
                m.to = static_cast<std::uint8_t>(to);
                if (b.sq[to] != 0) m.flags |= FLAG_CAPTURE;
                add_legal_if(b, m, out);
            }
        } else if (pt == BISHOP || pt == ROOK || pt == QUEEN) {
            static constexpr int bishopDirs[4][2] = { {1,1},{-1,1},{1,-1},{-1,-1} };
            static constexpr int rookDirs[4][2]   = { {1,0},{-1,0},{0,1},{0,-1} };

            auto try_dir = [&](int df, int dr) {
                int nf = f + df;
                int nr = r + dr;
                while (nf >= 0 && nf <= 7 && nr >= 0 && nr <= 7) {
                    int to = nr * 8 + nf;
                    if (b.sq[to] != 0) {
                        if (piece_color(b.sq[to]) != side) {
                            Move m{};
                            m.from = static_cast<std::uint8_t>(from);
                            m.to = static_cast<std::uint8_t>(to);
                            m.flags = FLAG_CAPTURE;
                            add_legal_if(b, m, out);
                        }
                        break;
                    } else {
                        Move m{};
                        m.from = static_cast<std::uint8_t>(from);
                        m.to = static_cast<std::uint8_t>(to);
                        add_legal_if(b, m, out);
                    }
                    nf += df;
                    nr += dr;
                }
            };

            if (pt == BISHOP || pt == QUEEN) {
                for (auto& d : bishopDirs) try_dir(d[0], d[1]);
            }
            if (pt == ROOK || pt == QUEEN) {
                for (auto& d : rookDirs) try_dir(d[0], d[1]);
            }
        } else if (pt == KING) {
            static constexpr int df[8] = { 1, 1, 0, -1, -1, -1, 0, 1 };
            static constexpr int dr[8] = { 0, 1, 1, 1, 0, -1, -1, -1 };
            for (int k = 0; k < 8; ++k) {
                int nf = f + df[k];
                int nr = r + dr[k];
                if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
                int to = nr * 8 + nf;
                if (b.sq[to] != 0 && piece_color(b.sq[to]) == side) continue;
                Move m{};
                m.from = static_cast<std::uint8_t>(from);
                m.to = static_cast<std::uint8_t>(to);
                if (b.sq[to] != 0) m.flags |= FLAG_CAPTURE;
                add_legal_if(b, m, out);
            }

            if (!is_in_check(b, side)) {
                if (side == WHITE) {
                    if ((b.castle & CASTLE_WK) && b.sq[5] == 0 && b.sq[6] == 0 && b.sq[7] == make_piece(WHITE, ROOK)) {
                        if (!is_square_attacked(b, 5, BLACK) && !is_square_attacked(b, 6, BLACK)) {
                            Move m{};
                            m.from = 4;
                            m.to = 6;
                            m.flags = FLAG_CASTLE;
                            add_legal_if(b, m, out);
                        }
                    }
                    if ((b.castle & CASTLE_WQ) && b.sq[3] == 0 && b.sq[2] == 0 && b.sq[1] == 0 && b.sq[0] == make_piece(WHITE, ROOK)) {
                        if (!is_square_attacked(b, 3, BLACK) && !is_square_attacked(b, 2, BLACK)) {
                            Move m{};
                            m.from = 4;
                            m.to = 2;
                            m.flags = FLAG_CASTLE;
                            add_legal_if(b, m, out);
                        }
                    }
                } else {
                    if ((b.castle & CASTLE_BK) && b.sq[61] == 0 && b.sq[62] == 0 && b.sq[63] == make_piece(BLACK, ROOK)) {
                        if (!is_square_attacked(b, 61, WHITE) && !is_square_attacked(b, 62, WHITE)) {
                            Move m{};
                            m.from = 60;
                            m.to = 62;
                            m.flags = FLAG_CASTLE;
                            add_legal_if(b, m, out);
                        }
                    }
                    if ((b.castle & CASTLE_BQ) && b.sq[59] == 0 && b.sq[58] == 0 && b.sq[57] == 0 && b.sq[56] == make_piece(BLACK, ROOK)) {
                        if (!is_square_attacked(b, 59, WHITE) && !is_square_attacked(b, 58, WHITE)) {
                            Move m{};
                            m.from = 60;
                            m.to = 58;
                            m.flags = FLAG_CASTLE;
                            add_legal_if(b, m, out);
                        }
                    }
                }
            }
        }
    }
}

struct ParsedSAN {
    bool castle = false;
    bool kingSideCastle = false;
    int pieceType = PAWN;
    bool capture = false;
    int dest = -1;
    int promo = 0;
    char hintFile = 0;
    char hintRank = 0;
};

static std::string strip_san_suffix(std::string t) {
    std::string out;
    out.reserve(t.size());
    for (char c : t) {
        if (c == '+' || c == '#' || c == '!' || c == '?' || c == '.') continue;
        if (c == '0' || c == 'o' || c == 'O') c = 'O';
        out.push_back(c);
    }
    return out;
}

static bool parse_san_token(const std::string& raw, ParsedSAN& ps) {
    std::string t = strip_san_suffix(clean_pgn_token(raw));
    if (t.empty()) return false;

    if (t == "O-O") {
        ps.castle = true;
        ps.kingSideCastle = true;
        return true;
    }
    if (t == "O-O-O") {
        ps.castle = true;
        ps.kingSideCastle = false;
        return true;
    }

    std::size_t eq = t.find('=');
    if (eq != std::string::npos) {
        if (eq + 1 >= t.size()) return false;
        char pc = static_cast<char>(std::toupper(static_cast<unsigned char>(t[eq + 1])));
        switch (pc) {
            case 'N': ps.promo = KNIGHT; break;
            case 'B': ps.promo = BISHOP; break;
            case 'R': ps.promo = ROOK; break;
            case 'Q': ps.promo = QUEEN; break;
            default: return false;
        }
        t = t.substr(0, eq);
    }

    if (t.size() < 2) return false;
    std::string destStr = t.substr(t.size() - 2, 2);
    if (!(destStr[0] >= 'a' && destStr[0] <= 'h' && destStr[1] >= '1' && destStr[1] <= '8')) return false;
    ps.dest = (destStr[1] - '1') * 8 + (destStr[0] - 'a');

    std::string prefix = t.substr(0, t.size() - 2);

    if (!prefix.empty() && (prefix[0] == 'N' || prefix[0] == 'B' || prefix[0] == 'R' || prefix[0] == 'Q' || prefix[0] == 'K')) {
        switch (prefix[0]) {
            case 'N': ps.pieceType = KNIGHT; break;
            case 'B': ps.pieceType = BISHOP; break;
            case 'R': ps.pieceType = ROOK; break;
            case 'Q': ps.pieceType = QUEEN; break;
            case 'K': ps.pieceType = KING; break;
        }
        prefix.erase(prefix.begin());
    } else {
        ps.pieceType = PAWN;
    }

    auto xPos = prefix.find('x');
    if (xPos != std::string::npos) {
        ps.capture = true;
        prefix.erase(xPos, 1);
    }

    if (!prefix.empty()) {
        if (ps.pieceType == PAWN) {
            if (prefix.size() == 1) ps.hintFile = prefix[0];
            else if (prefix.size() == 2) {
                ps.hintFile = prefix[0];
                ps.hintRank = prefix[1];
            } else {
                return false;
            }
        } else {
            if (prefix.size() == 1) {
                if (prefix[0] >= 'a' && prefix[0] <= 'h') ps.hintFile = prefix[0];
                else if (prefix[0] >= '1' && prefix[0] <= '8') ps.hintRank = prefix[0];
                else return false;
            } else if (prefix.size() == 2) {
                ps.hintFile = prefix[0];
                ps.hintRank = prefix[1];
            } else {
                return false;
            }
        }
    }

    return true;
}

static bool san_matches_move(const Board& b, const std::vector<Move>& legal, const Move& m, const ParsedSAN& ps) {
    int moving = b.sq[m.from];
    if (moving == 0) return false;
    if (piece_type(moving) != ps.pieceType) return false;

    if (ps.castle) {
        if (piece_type(moving) != KING) return false;
        if (ps.kingSideCastle) return (m.to == 6 || m.to == 62);
        return (m.to == 2 || m.to == 58);
    }

    if (m.to != ps.dest) return false;
    if (ps.promo != 0 && m.promo != ps.promo) return false;
    if (ps.promo == 0 && m.promo != 0) return false;

    bool isCapture = (m.flags & FLAG_CAPTURE) || (m.flags & FLAG_EP) || (b.sq[m.to] != 0);
    if (ps.capture != isCapture) return false;

    if (ps.hintFile != 0 && file_char(m.from) != ps.hintFile) return false;
    if (ps.hintRank != 0 && rank_char(m.from) != ps.hintRank) return false;

    return true;
}

static bool find_move_from_san(Board& b, const std::string& rawToken, Move& outMove) {
    std::string tok = clean_pgn_token(rawToken);
    if (tok.empty()) return false;
    if (is_ignorable_token(tok)) return false;
    if (is_result_token(tok)) return false;

    ParsedSAN ps;
    if (!parse_san_token(tok, ps)) return false;

    std::vector<Move> legal;
    gen_legal_moves(b, legal);

    int matched = 0;
    Move found{};

    for (const auto& m : legal) {
        if (san_matches_move(b, legal, m, ps)) {
            ++matched;
            found = m;
            if (matched > 1) {
                return false;
            }
        }
    }

    if (matched == 1) {
        outMove = found;
        return true;
    }

    return false;
}

static void write_sample(FILE* out, const Board& b, const Move& m) {
    std::array<std::uint8_t, PLANE_BYTES> planes{};
    for (int sq = 0; sq < 64; ++sq) {
        int p = b.sq[sq];
        if (p == 0) continue;
        int color = piece_color(p);
        int pt = piece_type(p) - 1;
        int plane = color * 6 + pt;
        planes[plane * 64 + sq] = 1;
    }

    write_raw(out, planes.data(), planes.size());

    // Ghi move info dạng binary integer (8 bytes):
    //   byte[0] = from_sq  (0–63)
    //   byte[1] = to_sq    (0–63)
    //   byte[2] = promo    (0=none, 2=Knight, 3=Bishop, 4=Rook, 5=Queen)
    //   byte[3] = flags    (FLAG_CAPTURE | FLAG_EP | FLAG_CASTLE | FLAG_DOUBLE)
    //   byte[4..7] = reserved (0x00)
    // Lưu ý: byte[0] luôn <= 63, nên Train.py phân biệt được với
    // format ASCII cũ (byte[0] = file-char 'a'-'h', ASCII 97-104 > 63).
    std::uint8_t buf[8] = {
        m.from,
        m.to,
        m.promo,
        m.flags,
        0, 0, 0, 0
    };
    write_raw(out, buf, 8);
}

static bool read_next_game(std::istream& in, GameRecord& g) {
    g = GameRecord{};
    std::string line;
    bool sawAny = false;
    bool inMoves = false;

    while (std::getline(in, line)) {
        line = rstrip_cr(line);

        if (line.empty()) {
            if (inMoves) break;
            continue;
        }

        sawAny = true;

        if (!inMoves && line[0] == '[') {
            parse_tag_line(line, g);
        } else {
            inMoves = true;
            g.movetext.append(line);
            g.movetext.push_back('\n');
        }
    }

    return sawAny || !g.movetext.empty();
}

static bool process_game(
    FILE* out,
    const GameRecord& rec,
    std::uint64_t& totalSamples,
    std::uint32_t minElo,
    std::uint32_t minFullMoves,
    std::uint32_t& sampleCountOut
) {
    sampleCountOut = 0;

    if (rec.result != "1-0" && rec.result != "0-1") return false;
    if (rec.whiteElo < 0 || rec.blackElo < 0) return false;
    if (rec.whiteElo <= static_cast<int>(minElo) || rec.blackElo <= static_cast<int>(minElo)) return false;

    Board b;
    if (rec.hasFen && rec.setup) {
        if (!parse_fen(rec.fen, b)) return false;
    } else {
        init_startpos(b);
    }

    std::uint64_t gameStart = file_tell64(out);

    write_game_header_placeholder(out, rec.whiteElo, rec.blackElo, result_to_code(rec.result));
    std::uint64_t sampleCountPos = gameStart + 1;
    std::uint32_t sampleCount = 0;

    TokenReader tr(rec.movetext);
    std::string tok;
    while (tr.next(tok)) {
        if (g_stopRequested.load(std::memory_order_relaxed)) {
            truncate_to(out, gameStart);
            return false;
        }

        std::string raw = clean_pgn_token(tok);
        if (raw.empty()) continue;
        if (is_move_number_token(raw) || raw[0] == '$') continue;
        if (is_result_token(raw)) break;

        std::string norm = normalize_san_token(raw);
        if (norm.empty()) continue;

        Move mv;
        if (!find_move_from_san(b, raw, mv)) {
            truncate_to(out, gameStart);
            return false;
        }

        write_sample(out, b, mv);

        Undo u;
        make_move(b, mv, u);

        ++sampleCount;
    }

    if (sampleCount < minFullMoves * 2) {
        truncate_to(out, gameStart);
        return false;
    }

    patch_game_sample_count(out, sampleCountPos, sampleCount);

    sampleCountOut = sampleCount;
    totalSamples += sampleCount;
    return true;
}

static bool has_pgn_ext(const fs::path& p) {
    std::string name = p.filename().string();
    std::string lower = name;
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return ends_with(lower, ".pgn");
}

static std::vector<fs::path> collect_pgn_files(const fs::path& root) {
    std::vector<fs::path> files;
    for (const auto& entry : fs::recursive_directory_iterator(root)) {
        if (!entry.is_regular_file()) continue;
        if (has_pgn_ext(entry.path())) files.push_back(entry.path());
    }
    std::sort(files.begin(), files.end());
    return files;
}

static std::uint64_t now_ms() {
    using namespace std::chrono;
    return static_cast<std::uint64_t>(
        duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count()
    );
}

int main(int argc, char** argv) {
    std::ios::sync_with_stdio(false);
    std::cin.tie(nullptr);

    signal(SIGINT, onSignal);
    signal(SIGTERM, onSignal);

    if (argc < 3) {
        std::cerr << "Usage:\n  " << argv[0]
                  << " --input_dir <dir> --output_file <all_games_dataset.bin>"
                  << " [--min_elo 2000] [--min_full_moves 20] [--progress_every 100]\n";
        return 1;
    }

    fs::path inputDir;
    fs::path outputFile;
    std::uint32_t minElo = 2000;
    std::uint32_t minFullMoves = 20;
    std::uint32_t progressEvery = 100;

    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];

        auto nextString = [&](std::string& dst) {
            if (i + 1 >= argc) throw std::runtime_error("Missing value for " + a);
            dst = argv[++i];
        };

        if (a == "--input_dir") {
            std::string v;
            nextString(v);
            inputDir = v;
        } else if (a == "--output_file") {
            std::string v;
            nextString(v);
            outputFile = v;
        } else if (a == "--min_elo") {
            if (i + 1 >= argc) throw std::runtime_error("Missing value for --min_elo");
            minElo = static_cast<std::uint32_t>(std::stoul(argv[++i]));
        } else if (a == "--min_full_moves") {
            if (i + 1 >= argc) throw std::runtime_error("Missing value for --min_full_moves");
            minFullMoves = static_cast<std::uint32_t>(std::stoul(argv[++i]));
        } else if (a == "--progress_every") {
            if (i + 1 >= argc) throw std::runtime_error("Missing value for --progress_every");
            progressEvery = static_cast<std::uint32_t>(std::stoul(argv[++i]));
        }
    }

    if (inputDir.empty() || outputFile.empty()) {
        std::cerr << "Thiếu --input_dir hoặc --output_file\n";
        return 1;
    }

    if (!fs::exists(inputDir) || !fs::is_directory(inputDir)) {
        std::cerr << "input_dir không hợp lệ: " << inputDir << "\n";
        return 1;
    }

    std::vector<fs::path> files = collect_pgn_files(inputDir);
    if (files.empty()) {
        std::cerr << "Không tìm thấy file .pgn nào trong: " << inputDir << "\n";
        return 0;
    }

    fs::path tmpFile = outputFile;
    tmpFile += ".tmp";
    if (fs::exists(tmpFile)) fs::remove(tmpFile);

    FILE* out = std::fopen(tmpFile.string().c_str(), "wb+");
    if (!out) {
        std::cerr << "Không mở được file output tạm: " << tmpFile << "\n";
        return 1;
    }

    static std::vector<char> buffer(8 * 1024 * 1024);
    setvbuf(out, buffer.data(), _IOFBF, buffer.size());

    std::uint64_t grandTotalSamples = 0;
    std::uint32_t grandAcceptedGames = 0;
    std::uint64_t grandReadGames = 0;
    std::uint32_t processedFiles = 0;

    try {
        write_dataset_header(out, 0, 0);

        const std::size_t totalFiles = files.size();
        std::cout << "Found " << totalFiles << " PGN file(s).\n";

        for (std::size_t idx = 0; idx < files.size(); ++idx) {
            if (g_stopRequested.load(std::memory_order_relaxed)) {
                std::cout << "[STOP] Đã dừng theo yêu cầu. Chuyển sang bước hoàn tất dataset...\n";
                break;
            }

            const fs::path& p = files[idx];
            double percentBefore = (100.0 * static_cast<double>(idx)) / static_cast<double>(totalFiles);
            std::cout << "[" << (idx + 1) << "/" << totalFiles << " | " << percentBefore << "%] "
                      << p.string() << " Processing...\n";

            std::ifstream in(p);
            if (!in) {
                std::cerr << "Không mở được file: " << p << "\n";
                continue;
            }

            std::uint32_t fileReadGames = 0;
            std::uint32_t fileAcceptedGames = 0;
            std::uint64_t fileSamples = 0;

            GameRecord rec;
            auto lastLog = std::chrono::steady_clock::now();

            while (read_next_game(in, rec)) {
                ++fileReadGames;
                ++grandReadGames;

                std::uint32_t gameSamples = 0;
                bool accepted = process_game(
                    out,
                    rec,
                    grandTotalSamples,
                    minElo,
                    minFullMoves,
                    gameSamples
                );

                if (accepted) {
                    ++fileAcceptedGames;
                    ++grandAcceptedGames;
                    fileSamples += gameSamples;
                }

                auto now = std::chrono::steady_clock::now();
                bool logByCount = (progressEvery > 0 && (fileReadGames % progressEvery == 0));
                bool logByTime = (std::chrono::duration_cast<std::chrono::seconds>(now - lastLog).count() >= 2);

                if (logByCount || logByTime) {
                    std::cout << "[" << (idx + 1) << "/" << totalFiles << "] "
                              << p.filename().string()
                              << " | read_games=" << fileReadGames
                              << " | accepted_games=" << fileAcceptedGames
                              << " | file_samples=" << fileSamples
                              << " | global_samples=" << grandTotalSamples
                              << std::endl;
                    lastLog = now;
                }

                if (g_stopRequested.load(std::memory_order_relaxed)) {
                    break;
                }
            }

            ++processedFiles;
            double percentAfter = (100.0 * static_cast<double>(processedFiles)) / static_cast<double>(totalFiles);
            std::cout << "[" << processedFiles << "/" << totalFiles << " | " << percentAfter << "%] "
                      << p.filename().string()
                      << " done | accepted_games=" << fileAcceptedGames
                      << ", read_games=" << fileReadGames
                      << ", file_samples=" << fileSamples
                      << "\n";
        }

        std::fflush(out);
        patch_dataset_header(out, grandTotalSamples, grandAcceptedGames);
        std::fflush(out);
        std::fclose(out);
        out = nullptr;

        if (fs::exists(outputFile)) {
            fs::remove(outputFile);
        }
        fs::rename(tmpFile, outputFile);

        double finalPercent = (100.0 * static_cast<double>(processedFiles)) / static_cast<double>(files.size());
        std::cout << "Done. files_scanned=" << processedFiles << "/" << files.size()
                  << " (" << finalPercent << "%), total_games_read=" << grandReadGames
                  << ", accepted_games=" << grandAcceptedGames
                  << ", total_samples=" << grandTotalSamples
                  << ", output=" << outputFile << "\n";
    } catch (const std::exception& e) {
        std::cerr << "\n[ERROR] " << e.what() << "\n";
        if (out) std::fclose(out);
        if (fs::exists(tmpFile)) {
            try { fs::remove(tmpFile); } catch (...) {}
        }
        return 1;
    }

    return 0;
}
