import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chess_ai/core/utils/logger.dart';

class CacheService {
  final Map<String, dynamic> _cache = {};

  Future<void> preloadAssets() async {
    try {
      AppLogger.info('Preloading assets...');
      AppLogger.info('Assets preloaded');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to preload assets', e, stackTrace);
    }
  }

  Future<void> preloadPieceImages(BuildContext context) async {
    final pieces = ['K', 'Q', 'R', 'B', 'N', 'P'];
    final colors = ['w', 'b'];

    for (final color in colors) {
      for (final piece in pieces) {
        final path = 'assets/images/pieces/cburnett/$color$piece.svg';
        try {
          await rootBundle.load(path);
        } catch (e) {
          AppLogger.warning('Failed to preload piece: $path', e);
        }
      }
    }
  }

  T? get<T>(String key) {
    return _cache[key] as T?;
  }

  void set<T>(String key, T value) {
    _cache[key] = value;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}
