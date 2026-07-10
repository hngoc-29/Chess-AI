import 'package:equatable/equatable.dart';

/// Represents a single move in an online game
class MoveRecord extends Equatable {
  final int index;
  final String san; // Standard algebraic notation
  final String fen;
  final String byUserId;
  final int? clientTimestamp;
  final int serverTimestamp;
  final int whiteTimeLeftMs;
  final int blackTimeLeftMs;

  const MoveRecord({
    required this.index,
    required this.san,
    required this.fen,
    required this.byUserId,
    this.clientTimestamp,
    required this.serverTimestamp,
    required this.whiteTimeLeftMs,
    required this.blackTimeLeftMs,
  });

  factory MoveRecord.fromJson(Map<String, dynamic> json) {
    return MoveRecord(
      index: json['index'] as int,
      san: json['san'] as String,
      fen: json['fen'] as String,
      byUserId: json['byUserId'] as String,
      clientTimestamp: json['clientTimestamp'] as int?,
      serverTimestamp: json['serverTimestamp'] as int,
      whiteTimeLeftMs: json['whiteTimeLeftMs'] as int,
      blackTimeLeftMs: json['blackTimeLeftMs'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'san': san,
      'fen': fen,
      'byUserId': byUserId,
      'clientTimestamp': clientTimestamp,
      'serverTimestamp': serverTimestamp,
      'whiteTimeLeftMs': whiteTimeLeftMs,
      'blackTimeLeftMs': blackTimeLeftMs,
    };
  }

  @override
  List<Object?> get props => [
        index,
        san,
        fen,
        byUserId,
        clientTimestamp,
        serverTimestamp,
        whiteTimeLeftMs,
        blackTimeLeftMs,
      ];
}
