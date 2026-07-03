import '../../domain/entities/board.dart';
import '../../domain/entities/piece.dart';
import '../../domain/entities/position.dart';

class FenParseResult {
  final Board board;
  final PieceColor currentTurn;
  final String? enPassant;
  final bool whiteCanCastleK;
  final bool whiteCanCastleQ;
  final bool blackCanCastleK;
  final bool blackCanCastleQ;
  final int halfMoveClock;
  final int fullMoveNumber;

  FenParseResult({
    required this.board,
    required this.currentTurn,
    this.enPassant,
    this.whiteCanCastleK = true,
    this.whiteCanCastleQ = true,
    this.blackCanCastleK = true,
    this.blackCanCastleQ = true,
    this.halfMoveClock = 0,
    this.fullMoveNumber = 1,
  });
}

String boardToFen(Board board, PieceColor currentTurn,
    {bool whiteCanCastleK = true,
    bool whiteCanCastleQ = true,
    bool blackCanCastleK = true,
    bool blackCanCastleQ = true,
    String? enPassant,
    int halfMove = 0,
    int fullMove = 1}) {
  final ranks = <String>[];
  // FEN starts from rank 8 (index 7) down to rank 1 (index 0)
  for (int r = 7; r >= 0; r--) {
    int empty = 0;
    final buffer = StringBuffer();
    for (int f = 0; f < 8; f++) {
      final piece = board.squares[r][f];
      if (piece == null) {
        empty++;
      } else {
        if (empty > 0) {
          buffer.write(empty);
          empty = 0;
        }
        buffer.write(piece.toFenChar());
      }
    }
    if (empty > 0) buffer.write(empty);
    ranks.add(buffer.toString());
  }

  final boardPart = ranks.join('/');
  final turnPart = currentTurn == PieceColor.white ? 'w' : 'b';

  final castlingBuffer = StringBuffer();
  if (whiteCanCastleK) castlingBuffer.write('K');
  if (whiteCanCastleQ) castlingBuffer.write('Q');
  if (blackCanCastleK) castlingBuffer.write('k');
  if (blackCanCastleQ) castlingBuffer.write('q');
  final castlingPart = castlingBuffer.isEmpty ? '-' : castlingBuffer.toString();

  final enPassantPart = enPassant ?? '-';

  return '$boardPart $turnPart $castlingPart $enPassantPart $halfMove $fullMove';
}

FenParseResult fenToBoard(String fen) {
  // Basic FEN parser that supports standard fields. Does not validate fully.
  final parts = fen.split(RegExp(r'\s+'));
  if (parts.length < 4) {
    throw FormatException('Invalid FEN: not enough parts');
  }

  final boardPart = parts[0];
  final turnPart = parts[1];
  final castlingPart = parts[2];
  final enPassantPart = parts[3];
  final halfMove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
  final fullMove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;

  final ranks = boardPart.split('/');
  if (ranks.length != 8) throw FormatException('Invalid FEN: expected 8 ranks');

  final squares = List.generate(8, (_) => List<Piece?>.filled(8, null));

  for (int r = 0; r < 8; r++) {
    final rankStr = ranks[r];
    int file = 0;
    for (int i = 0; i < rankStr.length; i++) {
      final ch = rankStr[i];
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        file += int.parse(ch);
      } else {
        final piece = Piece.fromFenChar(ch);
        // FEN rank 0 is rank 8; we need to map to our board indices: r=0 is top (rank8) -> index 7
        final rankIndex = 7 - r;
        if (file >= 8) throw FormatException('Invalid FEN rank too many files');
        squares[rankIndex][file] = piece;
        file++;
      }
    }
    if (file != 8) throw FormatException('Invalid FEN rank file count');
  }

  final board = Board(squares);
  final currentTurn = turnPart == 'w' ? PieceColor.white : PieceColor.black;

  final whiteCanCastleK = castlingPart.contains('K');
  final whiteCanCastleQ = castlingPart.contains('Q');
  final blackCanCastleK = castlingPart.contains('k');
  final blackCanCastleQ = castlingPart.contains('q');

  final enPassant = enPassantPart == '-' ? null : enPassantPart;

  return FenParseResult(
    board: board,
    currentTurn: currentTurn,
    enPassant: enPassant,
    whiteCanCastleK: whiteCanCastleK,
    whiteCanCastleQ: whiteCanCastleQ,
    blackCanCastleK: blackCanCastleK,
    blackCanCastleQ: blackCanCastleQ,
    halfMoveClock: halfMove,
    fullMoveNumber: fullMove,
  );
}
