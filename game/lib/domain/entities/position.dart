import 'package:equatable/equatable.dart';

class Position extends Equatable {
  final int file;
  final int rank;

  const Position({
    required this.file,
    required this.rank,
  });

  factory Position.fromAlgebraic(String notation) {
    if (notation.length != 2) {
      throw ArgumentError('Invalid algebraic notation: $notation');
    }
    final file = notation[0].toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(notation[1]) - 1;

    if (file < 0 || file > 7 || rank < 0 || rank > 7) {
      throw ArgumentError('Invalid square: $notation');
    }

    return Position(file: file, rank: rank);
  }

  String toAlgebraic() {
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = (rank + 1).toString();
    return '$fileChar$rankChar';
  }

  bool get isValid => file >= 0 && file < 8 && rank >= 0 && rank < 8;

  Position offset(int fileOffset, int rankOffset) {
    return Position(
      file: file + fileOffset,
      rank: rank + rankOffset,
    );
  }

  int distanceTo(Position other) {
    return (file - other.file).abs() + (rank - other.rank).abs();
  }

  bool isAdjacentTo(Position other) {
    return distanceTo(other) == 1;
  }

  bool isDiagonalTo(Position other) {
    return (file - other.file).abs() == (rank - other.rank).abs();
  }

  bool isOrthogonalTo(Position other) {
    return file == other.file || rank == other.rank;
  }

  Map<String, dynamic> toJson() {
    return {
      'file': file,
      'rank': rank,
    };
  }

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      file: json['file'] as int,
      rank: json['rank'] as int,
    );
  }

  @override
  List<Object?> get props => [file, rank];

  @override
  String toString() => toAlgebraic();
}
