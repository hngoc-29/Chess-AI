import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/backend_config.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/online/user_profile.dart';

/// Result wrapper for API operations
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  const ApiResult.success(this.data)
      : success = true,
        error = null;

  const ApiResult.failure(this.error)
      : success = false,
        data = null;
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

  /// Get user profile
  Future<ApiResult<OnlineUserProfile>> getUserProfile(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('${BackendConfig.authEndpoint}/profile/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final profile = OnlineUserProfile.fromJson(data);
        return ApiResult.success(profile);
      } else {
        return ApiResult.failure('Failed to get profile: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Get profile error', e, stackTrace);
      return ApiResult.failure('Get profile error: $e');
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
