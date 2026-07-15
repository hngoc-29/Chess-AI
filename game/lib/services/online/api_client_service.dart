import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/backend_config.dart';
import '../../core/utils/logger.dart';
import '../../data/models/online/user_profile.dart';

/// Result wrapper for API operations.
///
/// [statusCode] is null specifically when the request never got a response
/// at all (no connectivity, DNS failure, timeout) - as opposed to the
/// server responding with a real error status. Callers that decide whether
/// to log a user out (e.g. AuthBloc) need this distinction: a 401 means
/// "you are genuinely not authenticated", but a null statusCode just means
/// "we couldn't ask the server right now" and should fall back to cached
/// data instead of signing the user out.
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResult.success(this.data)
      : success = true,
        error = null,
        statusCode = 200;

  const ApiResult.failure(this.error, {this.statusCode})
      : success = false,
        data = null;

  bool get isNetworkError => !success && statusCode == null;
}

/// HTTP API client service for REST endpoints
class ApiClientService {
  final http.Client _client = http.Client();
  String? _accessToken;

  /// Set access token for authenticated requests
  void setAccessToken(String token) {
    _accessToken = token;
  }

  /// Get common headers
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// Health check
  Future<ApiResult<Map<String, dynamic>>> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse(BackendConfig.healthEndpoint),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResult.success(data);
      } else {
        return ApiResult.failure('Health check failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Health check error', e, stackTrace);
      return ApiResult.failure('Health check error: $e');
    }
  }

  /// Get the current user's own profile.
  ///
  /// [userId] is accepted for source compatibility with existing call
  /// sites (all of which already pass the caller's own id right after
  /// auth) but is otherwise unused: the backend has no
  /// `/api/auth/profile/:id` route, only `GET /api/auth/me`, which
  /// identifies the user from the bearer token rather than a URL param.
  Future<ApiResult<OnlineUserProfile>> getUserProfile(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('${BackendConfig.authEndpoint}/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final profile = OnlineUserProfile.fromJson(data['user'] as Map<String, dynamic>);
        return ApiResult.success(profile);
      } else {
        return ApiResult.failure('Failed to get profile: ${response.statusCode}', statusCode: response.statusCode);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Get profile error', e, stackTrace);
      // No statusCode - request never reached the server (no connectivity,
      // timeout, DNS failure, ...). Deliberately distinct from a 401/403.
      return ApiResult.failure('Get profile error: $e');
    }
  }

  /// Update the signed-in user's own profile (display name / avatar /
  /// settings). This is the endpoint OfflineSyncService replays once
  /// connectivity returns for edits made while offline.
  Future<ApiResult<OnlineUserProfile>> updateProfile({
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['displayName'] = displayName;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (settings != null) body['settings'] = settings;

      final response = await _client.patch(
        Uri.parse('${BackendConfig.authEndpoint}/me'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final profile = OnlineUserProfile.fromJson(data['user'] as Map<String, dynamic>, camelCase: true);
        return ApiResult.success(profile);
      }
      return ApiResult.failure('Failed to update profile: ${response.statusCode}', statusCode: response.statusCode);
    } catch (e, stackTrace) {
      AppLogger.error('Update profile error', e, stackTrace);
      return ApiResult.failure('Update profile error: $e');
    }
  }

  /// Get match history
  Future<ApiResult<List<Map<String, dynamic>>>> getMatchHistory({
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse(BackendConfig.matchesEndpoint).replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final matches = data.map((e) => e as Map<String, dynamic>).toList();
        return ApiResult.success(matches);
      } else {
        return ApiResult.failure('Failed to get matches: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Get match history error', e, stackTrace);
      return ApiResult.failure('Get match history error: $e');
    }
  }

  /// Get single match by ID
  Future<ApiResult<Map<String, dynamic>>> getMatch(String matchId) async {
    try {
      final response = await _client.get(
        Uri.parse('${BackendConfig.matchesEndpoint}/$matchId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResult.success(data);
      } else {
        return ApiResult.failure('Failed to get match: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Get match error', e, stackTrace);
      return ApiResult.failure('Get match error: $e');
    }
  }

  /// Submit campaign level
  Future<ApiResult<Map<String, dynamic>>> submitCampaign({
    required String levelId,
    required List<Map<String, String>> moves,
    required int durationMs,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.campaignEndpoint}/submit'),
        headers: _headers,
        body: json.encode({
          'levelId': levelId,
          'moves': moves,
          'durationMs': durationMs,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ApiResult.success(data);
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        return ApiResult.failure(errorData['error'] as String? ?? 'Submit failed');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Submit campaign error', e, stackTrace);
      return ApiResult.failure('Submit campaign error: $e');
    }
  }

  /// Get campaign progress
  Future<ApiResult<List<Map<String, dynamic>>>> getCampaignProgress() async {
    try {
      final response = await _client.get(
        Uri.parse('${BackendConfig.campaignEndpoint}/progress'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final progress = data.map((e) => e as Map<String, dynamic>).toList();
        return ApiResult.success(progress);
      } else {
        return ApiResult.failure('Failed to get progress: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Get campaign progress error', e, stackTrace);
      return ApiResult.failure('Get campaign progress error: $e');
    }
  }

  /// Get leaderboard
  Future<ApiResult<List<Map<String, dynamic>>>> getLeaderboard({
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('${BackendConfig.authEndpoint}/leaderboard').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final leaderboard = data.map((e) => e as Map<String, dynamic>).toList();
        return ApiResult.success(leaderboard);
      } else {
        return ApiResult.failure('Failed to get leaderboard: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Get leaderboard error', e, stackTrace);
      return ApiResult.failure('Get leaderboard error: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
