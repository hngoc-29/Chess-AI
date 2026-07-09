import 'package:flutter/material.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/fen_utils.dart';
import '../../../domain/entities/board.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/settings.dart';
import '../../../services/ai/chess_ai_engine.dart';

/// A standalone position analyzer: paste any FEN and get a material count,
/// an evaluation score, and a suggested move - without needing to start an
/// actual game. Complements the in-game "Phân tích" panel, which analyzes
/// whatever position you're currently playing.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _fenController = TextEditingController(
    text: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  );
  late final ChessAIEngine _aiEngine = getIt<ChessAIEngine>();

  FenParseResult? _parsed;
  String? _error;
  double? _score;
  String? _bestMoveText;
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _fenController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _error = null;
      _score = null;
      _bestMoveText = null;
      _isAnalyzing = true;
    });

    try {
      final parsed = fenToBoard(_fenController.text.trim());
      final score = _aiEngine.evaluatePosition(parsed.board, PieceColor.white);

      final bestMove = await _aiEngine.getBestMove(
        board: parsed.board,
        color: parsed.currentTurn,
        difficulty: AIDifficulty.hard,
        whiteCanCastleKingside: parsed.whiteCanCastleK,
        whiteCanCastleQueenside: parsed.whiteCanCastleQ,
        blackCanCastleKingside: parsed.blackCanCastleK,
        blackCanCastleQueenside: parsed.blackCanCastleQ,
        enPassantSquare: parsed.enPassant,
        halfMoveClock: parsed.halfMoveClock,
        fullMoveNumber: parsed.fullMoveNumber,
        history: const [],
      );

      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _score = score;
        _bestMoveText = '${bestMove.from.toAlgebraic()} → ${bestMove.to.toAlgebraic()}';
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'FEN không hợp lệ hoặc không phân tích được: $e';
        _isAnalyzing = false;
      });
    }
  }

  Map<PieceType, int> _materialFor(Board board, PieceColor color) {
    const values = {
      PieceType.pawn: 1, PieceType.knight: 3, PieceType.bishop: 3,
      PieceType.rook: 5, PieceType.queen: 9, PieceType.king: 0,
    };
    final counts = <PieceType, int>{};
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = board.pieceAt(Position(file: file, rank: rank));
        if (piece != null && piece.color == color) {
          counts[piece.type] = (counts[piece.type] ?? 0) + (values[piece.type] ?? 0);
        }
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.analysis)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Dán một chuỗi FEN bất kỳ để phân tích vị trí đó:'),
            const SizedBox(height: 8),
            TextField(
              controller: _fenController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'FEN string',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isAnalyzing ? null : _analyze,
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Phân tích'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            if (_score != null && _parsed != null) ...[
              Text(
                _score!.abs() < 0.15
                    ? 'Đánh giá: Cân bằng'
                    : 'Đánh giá: ${_score! > 0 ? "Trắng" : "Đen"} hơn ${_score!.abs().toStringAsFixed(1)} điểm',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Quân Trắng: ${_materialFor(_parsed!.board, PieceColor.white).values.fold(0, (a, b) => a + b)} điểm'),
              Text('Quân Đen: ${_materialFor(_parsed!.board, PieceColor.black).values.fold(0, (a, b) => a + b)} điểm'),
              const SizedBox(height: 12),
              if (_bestMoveText != null)
                Text('Nước đi tốt nhất: $_bestMoveText', style: const TextStyle(fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }
}
