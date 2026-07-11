import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/backend_config.dart';
import '../../core/utils/logger.dart';

/// Minimal identity returned directly by /api/auth/register and
/// /api/auth/login. Full stats (games played/won/etc.) come separately
/// from ApiClientService.getUserProfile() once a token exists.
class BackendUser {
  final String id;
  final String email;
  final String displayName;
  final int elo;

  const BackendUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.elo,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      elo: json['elo'] as int,
    );
  }
}

/// Result wrapper for auth operations.
class AuthResult {
  final bool success;
  final String? error;
  final BackendUser? user;
  final String? accessToken;
  final String? refreshToken;

  const AuthResult({
    required this.success,
    this.error,
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthResult.success(BackendUser user, String accessToken, String refreshToken) {
    return AuthResult(
      success: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(success: false, error: error);
  }
}

/// Email/password authentication against this app's own backend
/// (`POST /api/auth/*`), persisted locally via SharedPreferences so a
/// session survives an app restart.
///
/// Replaces the previous SupabaseAuthService. The backend migrated off
/// Supabase to self-issued JWTs (see the backend repo's
/// TURSO_MIGRATION.md) - a Supabase-issued token is signed with a key
/// the backend no longer has configured at all, so every authenticated
/// request or socket connection using one was being rejected outright.
/// The backend also has no OAuth provider wired up, only email+password,
/// so Google/Facebook sign-in has no server-side equivalent right now.
class BackendAuthService {
  final http.Client _client = http.Client();

  BackendUser? _currentUser;
  String? _currentAccessToken;
  String? _currentRefreshToken;

  static const _kAccessTokenKey = 'auth_access_token';
  static const _kRefreshTokenKey = 'auth_refresh_token';
  static const _kUserIdKey = 'auth_user_id';
  static const _kUserEmailKey = 'auth_user_email';
  static const _kUserDisplayNameKey = 'auth_user_display_name';
  static const _kUserEloKey = 'auth_user_elo';

  /// Restores a previously persisted session, if any. Call once at
  /// startup, before dispatching CheckAuthStatus.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_kAccessTokenKey);
      final refreshToken = prefs.getString(_kRefreshTokenKey);
      final userId = prefs.getString(_kUserIdKey);
      final email = prefs.getString(_kUserEmailKey);
      final displayName = prefs.getString(_kUserDisplayNameKey);
      final elo = prefs.getInt(_kUserEloKey);

      if (accessToken != null &&
          refreshToken != null &&
          userId != null &&
          email != null &&
          displayName != null &&
          elo != null) {
        _currentAccessToken = accessToken;
        _currentRefreshToken = refreshToken;
        _currentUser = BackendUser(id: userId, email: email, displayName: displayName, elo: elo);
        AppLogger.info('Restored session for $userId');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to restore session', e, stackTrace);
    }
  }

  Future<void> _persistSession(BackendUser user, String accessToken, String refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessTokenKey, accessToken);
      await prefs.setString(_kRefreshTokenKey, refreshToken);
      await prefs.setString(_kUserIdKey, user.id);
      await prefs.setString(_kUserEmailKey, user.email);
      await prefs.setString(_kUserDisplayNameKey, user.displayName);
      await prefs.setInt(_kUserEloKey, user.elo);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to persist session', e, stackTrace);
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kAccessTokenKey),
        prefs.remove(_kRefreshTokenKey),
        prefs.remove(_kUserIdKey),
        prefs.remove(_kUserEmailKey),
        prefs.remove(_kUserDisplayNameKey),
        prefs.remove(_kUserEloKey),
      ]);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear session', e, stackTrace);
    }
  }

  String? _errorMessageFrom(String responseBody, String fallback) {
    try {
      final decoded = json.decode(responseBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Register a new account.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.authEndpoint}/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'displayName': displayName,
        }),
      );

      if (response.statusCode == 201) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final user = BackendUser.fromJson(body['user'] as Map<String, dynamic>);
        final accessToken = body['accessToken'] as String;
        final refreshToken = body['refreshToken'] as String;

        _currentUser = user;
        _currentAccessToken = accessToken;
        _currentRefreshToken = refreshToken;
        await _persistSession(user, accessToken, refreshToken);

        AppLogger.info('User registered: ${user.id}');
        return AuthResult.success(user, accessToken, refreshToken);
      }

      return AuthResult.failure(_errorMessageFrom(response.body, 'Sign up failed') ?? 'Sign up failed');
    } catch (e, stackTrace) {
      AppLogger.error('Sign up error', e, stackTrace);
      return AuthResult.failure('Could not reach the server. Check your connection and try again.');
    }
  }

  /// Sign in with an existing account.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.authEndpoint}/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final user = BackendUser.fromJson(body['user'] as Map<String, dynamic>);
        final accessToken = body['accessToken'] as String;
        final refreshToken = body['refreshToken'] as String;

        _currentUser = user;
        _currentAccessToken = accessToken;
        _currentRefreshToken = refreshToken;
        await _persistSession(user, accessToken, refreshToken);

        AppLogger.info('User signed in: ${user.id}');
        return AuthResult.success(user, accessToken, refreshToken);
      }

      return AuthResult.failure(_errorMessageFrom(response.body, 'Sign in failed') ?? 'Sign in failed');
    } catch (e, stackTrace) {
      AppLogger.error('Sign in error', e, stackTrace);
      return AuthResult.failure('Could not reach the server. Check your connection and try again.');
    }
  }

  /// Exchange the stored refresh token for a new access token. Returns
  /// false (and clears the session) if there's no refresh token, or the
  /// server rejects it as expired/invalid/for a deleted user.
  Future<bool> refreshSession() async {
    final refreshToken = _currentRefreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.authEndpoint}/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        _currentAccessToken = body['accessToken'] as String;
        _currentRefreshToken = body['refreshToken'] as String;
        if (_currentUser != null) {
          await _persistSession(_currentUser!, _currentAccessToken!, _currentRefreshToken!);
        }
        AppLogger.info('Session refreshed');
        return true;
      }

      AppLogger.info('Refresh token rejected (${response.statusCode}), clearing session');
      await signOut();
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Session refresh error', e, stackTrace);
      return false;
    }
  }

  /// Sign out. JWTs are stateless (no server-side session to revoke), so
  /// this only clears local state.
  Future<void> signOut() async {
    _currentUser = null;
    _currentAccessToken = null;
    _currentRefreshToken = null;
    await _clearSession();
    AppLogger.info('User signed out');
  }

  bool get isSignedIn => _currentUser != null && _currentAccessToken != null;
  BackendUser? get currentUser => _currentUser;
  String? get currentAccessToken => _currentAccessToken;
  String? get currentUserId => _currentUser?.id;

  void dispose() {
    _client.close();
  }
}
