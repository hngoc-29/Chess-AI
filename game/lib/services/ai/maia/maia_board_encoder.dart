import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import 'maia_position_snapshot.dart';

/// Piece order used within each 6-plane color group, matching lc0's
/// convention (verified against the real lczero-tools reference
/// implementation and cross-checked with a converted Maia ONNX model -
/// see game/docs/maia_integration.md).
const List<PieceType> kMaiaPieceOrder = [
  PieceType.pawn,
  PieceType.knight,
  PieceType.bishop,
  PieceType.rook,
  PieceType.queen,
  PieceType.king,
];

/// Encodes board + short history into the exact 112x8x8 input tensor that
/// Maia/lc0 "classical" networks expect (`INPUT_CLASSICAL_112_PLANE` per
/// `lc0 describenet`).
///
/// Layout (verified empirically against the lczero-tools Python reference
/// implementation - see game/docs/maia_integration.md for how):
///  - 8 history steps x 13 planes = 104 planes:
///      - 6 "us" piece planes (pawn,knight,bishop,rook,queen,king)
///      - 6 "them" piece planes (same order)
///      - 1 repetition plane (all-1 or all-0)
///    Steps are most-recent-first; if fewer than 8 positions are available
///    the remaining planes are left zero (this is the normal case early in
///    a game, and is exactly what lc0 itself does).
///  - 8 constant planes (each a full 8x8 of a single value):
///      us-can-castle-queenside, us-can-castle-kingside,
///      them-can-castle-queenside, them-can-castle-kingside,
///      side-to-move (0=white, 1=black), rule50 count (raw halfmove
///      clock value, NOT normalized), all-zero, all-one.
///
/// "us"/"them" and the board orientation are always relative to whoever is
/// to move in the *current* position (history[0]), matching lc0's
/// convention of always presenting the board from the mover's viewpoint.
///
/// IMPORTANT, easy to get backwards: when black is to move, only the RANK
/// axis flips (row = 7 - rank); the FILE axis is left unchanged. This is
/// NOT a full 180-degree rotation, verified empirically against the
/// reference implementation with several known single-piece positions.
///
/// Known simplification: en passant is not represented at all (lc0's
/// classical input format genuinely has no plane for it - this isn't an
/// omission on our part). Repetition is detected only within the supplied
/// history window (up to 8 plies back) rather than across the whole game,
/// since that requires no persistent transposition table; this covers the
/// vast majority of practically-relevant repeats (e.g. shuffling a piece
/// back and forth) at a fraction of the bookkeeping.
class MaiaBoardEncoder {
  static const int planeCount = 112;
  static const int boardSize = 8;
  static const int totalFloats = planeCount * boardSize * boardSize;

  /// [history] must be ordered MOST RECENT FIRST: history[0] is the
  /// current position to move from, history[1] is one ply earlier, etc.
  /// Only the first 8 entries are used.
  static List<double> encode(List<MaiaPositionSnapshot> history) {
    if (history.isEmpty) {
      throw ArgumentError('history must contain at least the current position');
    }
    final planes = List<double>.filled(totalFloats, 0.0);
    final current = history.first;
    final whiteToMove = current.currentTurn == PieceColor.white;

    final keys = history.map(_positionKey).toList(growable: false);
    final stepCount = history.length < 8 ? history.length : 8;

    for (int step = 0; step < stepCount; step++) {
      final state = history[step];
      final planeBase = step * 13;

      for (int rank = 0; rank < boardSize; rank++) {
        final int row = whiteToMove ? rank : (7 - rank);
        for (int file = 0; file < boardSize; file++) {
          final piece = state.board.pieceAt(Position(file: file, rank: rank));
          if (piece == null) continue;

          final pieceOrderIdx = kMaiaPieceOrder.indexOf(piece.type);
          final isUs = piece.color == current.currentTurn;
          final plane = planeBase + (isUs ? 0 : 6) + pieceOrderIdx;
          planes[plane * 64 + row * 8 + file] = 1.0;
        }
      }

      final repeatedEarlier = keys.sublist(step + 1).contains(keys[step]);
      if (repeatedEarlier) {
        _fillPlane(planes, planeBase + 12, 1.0);
      }
    }

    final usOoo = whiteToMove ? current.whiteCanCastleQueenside : current.blackCanCastleQueenside;
    final usOo = whiteToMove ? current.whiteCanCastleKingside : current.blackCanCastleKingside;
    final themOoo = whiteToMove ? current.blackCanCastleQueenside : current.whiteCanCastleQueenside;
    final themOo = whiteToMove ? current.blackCanCastleKingside : current.whiteCanCastleKingside;

    _fillPlane(planes, 104, usOoo ? 1.0 : 0.0);
    _fillPlane(planes, 105, usOo ? 1.0 : 0.0);
    _fillPlane(planes, 106, themOoo ? 1.0 : 0.0);
    _fillPlane(planes, 107, themOo ? 1.0 : 0.0);
    _fillPlane(planes, 108, whiteToMove ? 0.0 : 1.0);
    _fillPlane(planes, 109, current.halfMoveClock.toDouble());
    _fillPlane(planes, 110, 0.0);
    _fillPlane(planes, 111, 1.0);

    return planes;
  }

  static void _fillPlane(List<double> planes, int planeIndex, double value) {
    final base = planeIndex * 64;
    for (int i = 0; i < 64; i++) {
      planes[base + i] = value;
    }
  }

  /// Board identity for repetition purposes: piece placement + side to
  /// move + castling rights + en passant square. Deliberately excludes
  /// halfmove/fullmove counters, matching standard chess repetition rules.
  static String _positionKey(MaiaPositionSnapshot s) {
    final buffer = StringBuffer();
    for (int rank = 7; rank >= 0; rank--) {
      for (int file = 0; file < 8; file++) {
        final piece = s.board.pieceAt(Position(file: file, rank: rank));
        buffer.write(piece == null ? '.' : piece.toFenChar());
      }
    }
    buffer
      ..write(s.currentTurn == PieceColor.white ? 'w' : 'b')
      ..write(s.whiteCanCastleKingside ? 'K' : '')
      ..write(s.whiteCanCastleQueenside ? 'Q' : '')
      ..write(s.blackCanCastleKingside ? 'k' : '')
      ..write(s.blackCanCastleQueenside ? 'q' : '')
      ..write(s.enPassantSquare ?? '-');
    return buffer.toString();
  }
}
