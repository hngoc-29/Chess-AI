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
  final Set<Position> endangeredSquares;
  final Set<Position> movablePiecesInCheck;
  final Position? selectedSquare;
  final Position? hintFrom;
  final Position? hintTo;
  final String pieceStyle;
  final Color lightSquareColor;
  final Color darkSquareColor;

  const ChessBoardWidget({
    super.key,
    required this.board,
    this.flipped = false,
    this.onMove,
    this.onSquareTap,
    this.legalMoves,
    this.endangeredSquares = const {},
    this.movablePiecesInCheck = const {},
    this.selectedSquare,
    this.hintFrom,
    this.hintTo,
    this.pieceStyle = 'cburnett',
    this.lightSquareColor = const Color(0xFFF0D9B5),
    this.darkSquareColor = const Color(0xFFB58863),
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
            final isEndangered = widget.endangeredSquares.contains(position);
            final isMovableInCheck = widget.movablePiecesInCheck.contains(position);
            final isHintSquare = widget.hintFrom == position || widget.hintTo == position;

            return DragTarget<Position>(
              onWillAccept: (from) => from != null && from != position,
              onAcceptWithDetails: (details) {
                if (widget.onMove != null) {
                  widget.onMove!(details.data, position);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onSquareTap(position),
                  child: Container(
                    width: squareSize,
                    height: squareSize,
                    decoration: BoxDecoration(
                      color: _getSquareColor(isLight, isSelected, moveType, isEndangered, isMovableInCheck),
                      border: isHintSquare
                          ? Border.all(color: const Color(0xFF29B6F6), width: 3)
                          : null,
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

  Color _getSquareColor(bool isLight, bool isSelected, MoveType? moveType, bool isEndangered, bool isMovableInCheck) {
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
          // Red underfoot for dangerous destination
          return isLight
              ? const Color(0xFFFFB3B3)
              : const Color(0xFFB85C5C);
      }
    }
    if (isMovableInCheck) {
      // The king is in check: highlight pieces that can actually respond
      // (this takes priority over the plain "under attack" tint below,
      // since "can this piece help" is the more useful signal right now).
      return isLight ? const Color(0xFFD4FFD4) : const Color(0xFF88CC88);
    }
    if (isEndangered) {
      // Red underfoot for pieces currently under attack
      return isLight ? const Color(0xFFFFC0C0) : const Color(0xFFC45F5F);
    }
    // Board-style square colors (Settings > Board Style)
    return isLight ? widget.lightSquareColor : widget.darkSquareColor;
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
                    onAcceptWithDetails: (details) {
                      if (widget.onMove != null) {
                        widget.onMove!(details.data, position);
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
