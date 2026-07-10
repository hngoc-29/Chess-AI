import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

class OnlineChessBoard extends StatefulWidget {
  final String fen;
  final String playerColor;
  final bool isMyTurn;
  final Function(String from, String to, String? promotion) onMoveMade;

  const OnlineChessBoard({
    super.key,
    required this.fen,
    required this.playerColor,
    required this.isMyTurn,
    required this.onMoveMade,
  });

  @override
  State<OnlineChessBoard> createState() => _OnlineChessBoardState();
}

class _OnlineChessBoardState extends State<OnlineChessBoard> {
  late chess_lib.Chess _chess;
  String? _selectedSquare;
  List<String> _legalMoves = [];

  @override
  void initState() {
    super.initState();
    _initChess();
  }

  @override
  void didUpdateWidget(OnlineChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fen != widget.fen) {
      _initChess();
      _selectedSquare = null;
      _legalMoves = [];
    }
  }

  void _initChess() {
    _chess = chess_lib.Chess.fromFEN(widget.fen);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.maxWidth;
          final squareSize = boardSize / 8;

          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                _buildBoard(squareSize),
                if (_selectedSquare != null) _buildLegalMoveIndicators(squareSize),
                _buildPieces(squareSize),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoard(double squareSize) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final row = widget.playerColor == 'w' ? index ~/ 8 : 7 - (index ~/ 8);
        final col = widget.playerColor == 'w' ? index % 8 : 7 - (index % 8);
        final square = _getSquareName(row, col);
        final isLight = (row + col) % 2 == 0;
        final isSelected = square == _selectedSquare;
        final isLegalMove = _legalMoves.contains(square);

        return GestureDetector(
          onTap: widget.isMyTurn ? () => _onSquareTapped(square) : null,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.yellow.withOpacity(0.6)
                  : isLegalMove
                      ? Colors.green.withOpacity(0.4)
                      : isLight
                          ? const Color(0xFFEEEED2)
                          : const Color(0xFF769656),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegalMoveIndicators(double squareSize) {
    return Stack(
      children: _legalMoves.map((square) {
        final position = _getSquarePosition(square);
        final hasPiece = _chess.get(square) != null;

        return Positioned(
          left: position.$1 * squareSize,
          top: position.$2 * squareSize,
          width: squareSize,
          height: squareSize,
          child: Center(
            child: Container(
              width: hasPiece ? squareSize * 0.9 : squareSize * 0.3,
              height: hasPiece ? squareSize * 0.9 : squareSize * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasPiece
                    ? Colors.red.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2),
                border: hasPiece
                    ? Border.all(color: Colors.red.withOpacity(0.6), width: 3)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieces(double squareSize) {
    final pieces = <Widget>[];
    
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final square = _getSquareName(row, col);
        final piece = _chess.get(square);
        
        if (piece != null) {
          final position = _getSquarePosition(square);
          pieces.add(
            Positioned(
              left: position.$1 * squareSize,
              top: position.$2 * squareSize,
              width: squareSize,
              height: squareSize,
              child: _buildPiece(piece, squareSize),
            ),
          );
        }
      }
    }
    
    return Stack(children: pieces);
  }

  Widget _buildPiece(chess_lib.Piece piece, double squareSize) {
    final pieceChar = _getPieceUnicode(piece);
    
    return Center(
      child: Text(
        pieceChar,
        style: TextStyle(
          fontSize: squareSize * 0.7,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  String _getPieceUnicode(chess_lib.Piece piece) {
    const whitePieces = {
      chess_lib.PieceType.KING: '♔',
      chess_lib.PieceType.QUEEN: '♕',
      chess_lib.PieceType.ROOK: '♖',
      chess_lib.PieceType.BISHOP: '♗',
      chess_lib.PieceType.KNIGHT: '♘',
      chess_lib.PieceType.PAWN: '♙',
    };
    
    const blackPieces = {
      chess_lib.PieceType.KING: '♚',
      chess_lib.PieceType.QUEEN: '♛',
      chess_lib.PieceType.ROOK: '♜',
      chess_lib.PieceType.BISHOP: '♝',
      chess_lib.PieceType.KNIGHT: '♞',
      chess_lib.PieceType.PAWN: '♟',
    };
    
    final pieces = piece.color == chess_lib.Color.WHITE ? whitePieces : blackPieces;
    return pieces[piece.type] ?? '';
  }

  void _onSquareTapped(String square) {
    if (_selectedSquare == null) {
      // Select piece if it belongs to the player
      final piece = _chess.get(square);
      if (piece != null && 
          ((widget.playerColor == 'w' && piece.color == chess_lib.Color.WHITE) ||
           (widget.playerColor == 'b' && piece.color == chess_lib.Color.BLACK))) {
        setState(() {
          _selectedSquare = square;
          _legalMoves = _getLegalMovesForSquare(square);
        });
      }
    } else {
      // Try to make a move
      if (_legalMoves.contains(square)) {
        _makeMove(_selectedSquare!, square);
      } else {
        // Deselect or select another piece
        final piece = _chess.get(square);
        if (piece != null && 
            ((widget.playerColor == 'w' && piece.color == chess_lib.Color.WHITE) ||
             (widget.playerColor == 'b' && piece.color == chess_lib.Color.BLACK))) {
          setState(() {
            _selectedSquare = square;
            _legalMoves = _getLegalMovesForSquare(square);
          });
        } else {
          setState(() {
            _selectedSquare = null;
            _legalMoves = [];
          });
        }
      }
    }
  }

  List<String> _getLegalMovesForSquare(String square) {
    final moves = _chess.moves({'square': square, 'verbose': true});
    return moves.map((move) => move['to'] as String).toList();
  }

  void _makeMove(String from, String to) {
    // Check if it's a pawn promotion
    final piece = _chess.get(from);
    final isPromotion = piece?.type == chess_lib.PieceType.PAWN &&
        ((piece.color == chess_lib.Color.WHITE && to[1] == '8') ||
         (piece.color == chess_lib.Color.BLACK && to[1] == '1'));

    if (isPromotion) {
      _showPromotionDialog(from, to);
    } else {
      widget.onMoveMade(from, to, null);
      setState(() {
        _selectedSquare = null;
        _legalMoves = [];
      });
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote Pawn'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPromotionOption(ctx, from, to, 'q', '♕'),
            _buildPromotionOption(ctx, from, to, 'r', '♖'),
            _buildPromotionOption(ctx, from, to, 'b', '♗'),
            _buildPromotionOption(ctx, from, to, 'n', '♘'),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionOption(BuildContext ctx, String from, String to, String piece, String unicode) {
    return GestureDetector(
      onTap: () {
        Navigator.of(ctx).pop();
        widget.onMoveMade(from, to, piece);
        setState(() {
          _selectedSquare = null;
          _legalMoves = [];
        });
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(unicode, style: const TextStyle(fontSize: 36)),
        ),
      ),
    );
  }

  String _getSquareName(int row, int col) {
    final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    return '${files[col]}${8 - row}';
  }

  (double, double) _getSquarePosition(String square) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    
    final col = widget.playerColor == 'w' ? file.toDouble() : (7 - file).toDouble();
    final row = widget.playerColor == 'w' ? (7 - rank).toDouble() : rank.toDouble();
    
    return (col, row);
  }
}
