import '../../../domain/entities/board.dart';
import '../../../domain/entities/game_state.dart';
import '../../../domain/entities/piece.dart';

/// The minimal set of fields needed to encode one position for Maia's
/// input planes. Deliberately decoupled from [GameState] (which also
/// carries move history, players, timestamps, etc. that the encoder has
/// no use for) so the encoder doesn't depend on unrelated domain fields.
class MaiaPositionSnapshot {
  final Board board;
  final PieceColor currentTurn;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final String? enPassantSquare;
  final int halfMoveClock;

  const MaiaPositionSnapshot({
    required this.board,
    required this.currentTurn,
    required this.whiteCanCastleKingside,
    required this.whiteCanCastleQueenside,
    required this.blackCanCastleKingside,
    required this.blackCanCastleQueenside,
    this.enPassantSquare,
    this.halfMoveClock = 0,
  });

  factory MaiaPositionSnapshot.fromGameState(GameState state) {
    return MaiaPositionSnapshot(
      board: state.board,
      currentTurn: state.currentTurn,
      whiteCanCastleKingside: state.whiteCanCastleKingside,
      whiteCanCastleQueenside: state.whiteCanCastleQueenside,
      blackCanCastleKingside: state.blackCanCastleKingside,
      blackCanCastleQueenside: state.blackCanCastleQueenside,
      enPassantSquare: state.enPassantSquare,
      halfMoveClock: state.halfMoveClock,
    );
  }
}
