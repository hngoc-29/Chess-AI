import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client_service.dart';
import '../../core/utils/logger.dart';

/// Queues account edits made while offline and replays them against the
/// backend once connectivity returns.
///
/// Scope: profile fields only (display name / avatar / settings) - see
/// AuthBloc.ProfileUpdateRequested. Elo, match history, and campaign
/// progress are server-computed and never queued for writing, only cached
/// for offline reading (BackendAuthService.cachedProfile). Deliberately
/// coalesces multiple offline edits into one pending update rather than
/// keeping a literal history: profile fields are simple overwrites, so
/// three offline display-name changes only need the last one sent.
class OfflineSyncService {
  final ApiClientService _apiService;
  static const _kPendingKey = 'offline_pending_profile_update';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;

  /// Called after the queue changes (enqueued, flushed, or failed) so the
  /// UI (via AuthBloc) can refresh its pendingSyncCount badge.
  void Function()? onQueueChanged;

  OfflineSyncService(this._apiService) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) flushPending();
    });
  }

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  Future<void> _refreshPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingCount = prefs.getString(_kPendingKey) != null ? 1 : 0;
  }

  /// Merges new fields into any already-pending update, then tries to
  /// send immediately - if that fails (offline or a transient error),
  /// the merged edit stays queued for the next connectivity change.
  Future<void> enqueueProfileUpdate({
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString(_kPendingKey);
    final merged = <String, dynamic>{
      if (existingRaw != null) ...json.decode(existingRaw) as Map<String, dynamic>,
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (settings != null) 'settings': settings,
    };
    await prefs.setString(_kPendingKey, json.encode(merged));
    await _refreshPendingCount();
    onQueueChanged?.call();

    await flushPending();
  }

  /// Attempts to send the pending update, if any. Safe to call whenever -
  /// a no-op if the queue is empty, and self-guards against overlapping
  /// calls (e.g. a connectivity event firing while a manual flush from
  /// enqueueProfileUpdate is already in flight).
  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingKey);
      if (raw == null) return;

      final pending = json.decode(raw) as Map<String, dynamic>;
      final result = await _apiService.updateProfile(
        displayName: pending['displayName'] as String?,
        avatarUrl: pending['avatarUrl'] as String?,
        settings: (pending['settings'] as Map?)?.cast<String, dynamic>(),
      );

      if (result.success) {
        await prefs.remove(_kPendingKey);
        AppLogger.info('Offline profile edit synced');
      } else if (!result.isNetworkError) {
        // The server actively rejected this (validation, banned, etc.) -
        // retrying the same payload would just fail again, so drop it
        // rather than retry forever. A network error, by contrast, is
        // left in place for the next connectivity change to retry.
        AppLogger.error('Offline profile edit rejected by server, dropping: ${result.error}');
        await prefs.remove(_kPendingKey);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Flush pending sync error', e, stackTrace);
    } finally {
      await _refreshPendingCount();
      onQueueChanged?.call();
      _flushing = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
