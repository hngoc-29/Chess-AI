import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// Maps legal moves (in UCI notation) to their index in Maia/lc0's 1858
/// element policy output vector, and provides the matching softmax helper.
///
/// lc0 uses 4 different index tables depending on (a) which side is to
/// move and (b) whether that side still has any castling rights at all -
/// this is a real, non-obvious quirk of lc0's move-index scheme (verified
/// against the lczero-tools reference implementation), not something we
/// invented. `uci_to_idx.json` (bundled asset) contains all 4 tables,
/// extracted directly from that reference implementation rather than
/// hand-transcribed, to avoid transcription errors in ~7400 table entries.
class MaiaMoveIndex {
  static MaiaMoveIndex? _instance;
  final List<Map<String, int>> _variants;

  MaiaMoveIndex._(this._variants);

  static Future<MaiaMoveIndex> load() async {
    final cached = _instance;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/onnx/uci_to_idx.json');
    final decoded = json.decode(raw) as List<dynamic>;
    final variants = decoded
        .map((variant) => (variant as Map<String, dynamic>)
            .map((uci, idx) => MapEntry(uci, idx as int)))
        .toList();

    final instance = MaiaMoveIndex._(variants);
    _instance = instance;
    return instance;
  }

  /// Index of the variant table to use: 0=white/no-castle, 1=white/castle,
  /// 2=black/no-castle, 3=black/castle.
  int _variantIndex({
    required bool whiteToMove,
    required bool usHasAnyCastlingRights,
  }) {
    return (usHasAnyCastlingRights ? 1 : 0) + (whiteToMove ? 0 : 2);
  }

  /// Looks up policy-vector indices for a list of legal moves in UCI
  /// notation (e.g. "e2e4", "e7e8q"). Knight promotions ("e7e8n") are
  /// looked up without the trailing 'n', matching lc0's convention of
  /// sharing that index with the plain/queen-promotion move.
  List<int> indicesFor(
    List<String> legalUci, {
    required bool whiteToMove,
    required bool usHasAnyCastlingRights,
  }) {
    final table = _variants[_variantIndex(
      whiteToMove: whiteToMove,
      usHasAnyCastlingRights: usHasAnyCastlingRights,
    )];
    return legalUci.map((uci) {
      final key = uci.endsWith('n') ? uci.substring(0, uci.length - 1) : uci;
      final idx = table[key];
      if (idx == null) {
        throw StateError('No Maia policy index found for move "$uci"');
      }
      return idx;
    }).toList();
  }

  /// Standard softmax, numerically stabilized by subtracting the max.
  static List<double> softmax(List<double> logits) {
    if (logits.isEmpty) return const [];
    final maxVal = logits.reduce(math.max);
    final exps = logits.map((v) => math.exp(v - maxVal)).toList();
    final sum = exps.fold<double>(0.0, (a, b) => a + b);
    return exps.map((v) => v / sum).toList();
  }
}
