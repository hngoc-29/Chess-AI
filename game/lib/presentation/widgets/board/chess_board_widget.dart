import 'package:flutter/material.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import 'piece_widget.dart';

class ChessBoardWidget extends StatefulWidget {
  final Board board;
  final bool flipped;
  final Function(Position from, Position to)? onMove;
  final Function(Position position)? onSquareTap;
  final Set<Position>? legalMoves;
  final Position? selectedSquare;

  const ChessBoardWidget({
    super.key,
    required this.board,
    this.flipped = false,
    this.onMove,
    this.onSquareTap,
    this.legalMoves,
    this.selectedSquare,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  Position? _draggedFrom;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return Stack(
            children: [
              _buildBoard(squareSize),
              _buildPieces(squareSize),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoard(double squareSize) {
    return Column(
      children: List.generate(8, (rank) {
        final displayRank = widget.flipped ? rank : 7 - rank;
        return Row(
          children: List.generate(8, (file) {
            final displayFile = widget.flipped ? 7 - file : file;
            final position = Position(file: displayFile, rank: displayRank);
            final isLight = (rank + file) % 2 == 0;
            final isSelected = widget.selectedSquare == position;
            final isLegalMove = widget.legalMoves?.contains(position) ?? false;

            return DragTarget<Position>(
              onWillAccept: (from) => from != null && from != position,
              onAccept: (from) {
                if (widget.onMove != null) {
                  widget.onMove!(from, position);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () => _onSquareTap(position),
                  child: Container(
                    width: squareSize,
                    height: squareSize,
                    decoration: BoxDecoration(
                      color: _getSquareColor(isLight, isSelected, isLegalMove),
                      border: isLegalMove
                          ? Border.all(color: Colors.green, width: 2)
                          : null,
                    ),
                    child: isLegalMove
                        ? Center(
                            child: Container(
                              width: squareSize * 0.3,
                              height: squareSize * 0.3,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            );
          }),
        );
      }),
    );
  }

  Color _getSquareColor(bool isLight, bool isSelected, bool isLegalMove) {
    if (isSelected) {
      return Colors.yellow.withOpacity(0.6);
    }
    if (isLegalMove) {
      return isLight
          ? const Color(0xFFF0D9B5).withOpacity(0.8)
          : const Color(0xFFB58863).withOpacity(0.8);
    }
    return isLight ? const Color(0xFFF0D9B5) : const Color(0xFFB58863);
  }

  Widget _buildPieces(double squareSize) {
    final pieces = <Widget>[];

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final position = Position(file: file, rank: rank);
        final piece = widget.board.pieceAt(position);

        if (piece != null && position != _draggedFrom) {
          final displayRank = widget.flipped ? 7 - rank : rank;
          final displayFile = widget.flipped ? 7 - file : file;

          pieces.add(
            Positioned(
              left: displayFile * squareSize,
              top: displayRank * squareSize,
              width: squareSize,
              height: squareSize,
              child: GestureDetector(
                onTap: () => _onSquareTap(position),
                child: Draggable<Position>(
                  data: position,
                  feedback: Material(
                    color: Colors.transparent,
                    child: PieceWidget(
                      piece: piece,
                      size: squareSize,
                      isDragging: true,
                    ),
                  ),
                  childWhenDragging: const SizedBox.shrink(),
                  onDragStarted: () {
                    setState(() {
                      _draggedFrom = position;
                    });
                    // Select the piece when drag starts
                    if (widget.onSquareTap != null) {
                      widget.onSquareTap!(position);
                    }
                  },
                  onDragEnd: (details) {
                    setState(() {
                      _draggedFrom = null;
                    });
                  },
                  child: DragTarget<Position>(
                    onWillAccept: (from) => from != null && from != position,
                    onAccept: (from) {
                      if (widget.onMove != null) {
                        widget.onMove!(from, position);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return PieceWidget(piece: piece, size: squareSize);
                    },
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Stack(children: pieces);
  }

  void _onSquareTap(Position position) {
    if (widget.onSquareTap != null) {
      widget.onSquareTap!(position);
    } else if (widget.selectedSquare != null &&
               widget.legalMoves?.contains(position) == true &&
               widget.onMove != null) {
      widget.onMove!(widget.selectedSquare!, position);
    }
  }
}
