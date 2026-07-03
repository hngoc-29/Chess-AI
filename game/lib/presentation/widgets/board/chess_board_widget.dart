import 'package:flutter/material.dart';

import '../../../domain/entities/board.dart';
import '../../../domain/entities/move_info.dart';
import '../../../domain/entities/position.dart';
import 'piece_widget.dart';

class ChessBoardWidget extends StatefulWidget {
  final Board board;
  final bool flipped;
  final Function(Position from, Position to)? onMove;
  final Function(Position position)? onSquareTap;
  final Map<Position, MoveType>? legalMoves;
  final Position? selectedSquare;
  final String pieceStyle;

  const ChessBoardWidget({
    super.key,
    required this.board,
    this.flipped = false,
    this.onMove,
    this.onSquareTap,
    this.legalMoves,
    this.selectedSquare,
    this.pieceStyle = 'cburnett',
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
            final moveType = widget.legalMoves?[position];

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
                      color: _getSquareColor(isLight, isSelected, moveType),
                    ),
                    child: moveType != null
                        ? _buildMoveIndicator(squareSize, moveType)
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

  Color _getSquareColor(bool isLight, bool isSelected, MoveType? moveType) {
    if (isSelected) {
      // Soft yellow highlight for selected piece
      return const Color(0xFFFFDD88);
    }
    if (moveType != null) {
      // Color based on move type
      switch (moveType) {
        case MoveType.capture:
          // Red tint for capture moves
          return isLight
              ? const Color(0xFFFFD4D4)
              : const Color(0xFFCC8888);
        case MoveType.safe:
          // Green tint for safe moves
          return isLight
              ? const Color(0xFFD4FFD4)
              : const Color(0xFF88CC88);
        case MoveType.dangerous:
          // Orange tint for dangerous moves
          return isLight
              ? const Color(0xFFFFE4CC)
              : const Color(0xFFCC9966);
      }
    }
    // Standard chess board colors
    return isLight ? const Color(0xFFF0D9B5) : const Color(0xFFB58863);
  }

  Widget _buildMoveIndicator(double squareSize, MoveType moveType) {
    Color indicatorColor;
    double indicatorSize;

    switch (moveType) {
      case MoveType.capture:
        // Larger ring for captures
        indicatorColor = Colors.red.withOpacity(0.6);
        indicatorSize = squareSize * 0.8;
        return Center(
          child: Container(
            width: indicatorSize,
            height: indicatorSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: indicatorColor, width: 3),
            ),
          ),
        );
      case MoveType.safe:
        // Small green circle for safe moves
        indicatorColor = Colors.green.withOpacity(0.5);
        indicatorSize = squareSize * 0.3;
        return Center(
          child: Container(
            width: indicatorSize,
            height: indicatorSize,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      case MoveType.dangerous:
        // Orange triangle for dangerous moves
        indicatorColor = Colors.orange.withOpacity(0.6);
        indicatorSize = squareSize * 0.35;
        return Center(
          child: Icon(
            Icons.warning,
            color: indicatorColor,
            size: indicatorSize,
          ),
        );
    }
  }

  Widget _buildPieces(double squareSize) {
    final pieces = <Widget>[];

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final position = Position(file: file, rank: rank);
        final piece = widget.board.pieceAt(position);

        if (piece != null && position != _draggedFrom) {
          // Use SAME transformation as board squares
          final displayRank = widget.flipped ? rank : 7 - rank;
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
                      pieceStyle: widget.pieceStyle,
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
                      return PieceWidget(
                        piece: piece,
                        size: squareSize,
                        pieceStyle: widget.pieceStyle,
                      );
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
               widget.legalMoves?.containsKey(position) == true &&
               widget.onMove != null) {
      widget.onMove!(widget.selectedSquare!, position);
    }
  }
}
