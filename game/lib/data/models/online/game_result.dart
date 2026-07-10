import 'package:equatable/equatable.dart';

/// Game result types matching backend
enum GameResultType {
  checkmate,
  resign,
  timeout,
  stalemate,
  drawAgreement,
  threefoldRepetition,
  fiftyMoveRule,
  insufficientMaterial,
  abandoned;

  static GameResultType fromString(String value) {
    switch (value) {
      case 'checkmate':
        return GameResultType.checkmate;
      case 'resign':
        return GameResultType.resign;
      case 'timeout':
        return GameResultType.timeout;
      case 'stalemate':
        return GameResultType.stalemate;
      case 'draw_agreement':
        return GameResultType.drawAgreement;
      case 'threefold_repetition':
        return GameResultType.threefoldRepetition;
      case 'fifty_move_rule':
        return GameResultType.fiftyMoveRule;
      case 'insufficient_material':
        return GameResultType.insufficientMaterial;
      case 'abandoned':
        return GameResultType.abandoned;
      default:
        throw ArgumentError('Unknown result type: $value');
    }
  }

  String toBackendString() {
    switch (this) {
      case GameResultType.checkmate:
        return 'checkmate';
      case GameResultType.resign:
        return 'resign';
      case GameResultType.timeout:
        return 'timeout';
      case GameResultType.stalemate:
        return 'stalemate';
      case GameResultType.drawAgreement:
        return 'draw_agreement';
      case GameResultType.threefoldRepetition:
        return 'threefold_repetition';
      case GameResultType.fiftyMoveRule:
        return 'fifty_move_rule';
      case GameResultType.insufficientMaterial:
        return 'insufficient_material';
      case GameResultType.abandoned:
        return 'abandoned';
    }
  }
}

/// Game result with winner information
class GameResult extends Equatable {
  final GameResultType resultType;
  final String? winnerColor; // 'w', 'b', or null for draw

  const GameResult({
    required this.resultType,
    this.winnerColor,
  });

  bool get isDraw => winnerColor == null;

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      resultType: GameResultType.fromString(json['resultType'] as String),
      winnerColor: json['winnerColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resultType': resultType.toBackendString(),
      'winnerColor': winnerColor,
    };
  }

  @override
  List<Object?> get props => [resultType, winnerColor];
}
