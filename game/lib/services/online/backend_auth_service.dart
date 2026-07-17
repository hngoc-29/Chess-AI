import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../core/config/backend_config.dart';
import '../../core/utils/logger.dart';
import '../../data/models/online/user_profile.dart';

/// Identity + token pair as returned directly by any sign-in endpoint
/// (register/login/guest/oauth). Deliberately minimal - no stats fields,
/// since none of those endpoints return them. Full stats come from
/// ApiClientService.getUserProfile() once a token exists; see
/// OnlineUserProfile for the model that carries those.
class BackendUser {
  final String id;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final int elo;
  final String authProvider;
  final Map<String, dynamic> settings;
  /// True only for a guest that has never talked to the backend at all -
  /// see BackendAuthService.signInAsGuest. A guest that has since linked
  /// Google/Facebook is a normal server-backed account (authProvider
  /// becomes 'google'/'facebook') and this is false.
  final bool isLocalOnly;

  const BackendUser({
    required this.id,
    this.email,
    required this.displayName,
    this.avatarUrl,
    required this.elo,
    this.authProvider = 'email',
    this.settings = const {},
    this.isLocalOnly = false,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      elo: json['elo'] as int,
      authProvider: json['authProvider'] as String? ?? 'email',
      settings: (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      isLocalOnly: json['isLocalOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'elo': elo,
        'authProvider': authProvider,
        'settings': settings,
        'isLocalOnly': isLocalOnly,
      };

  bool get isGuest => authProvider == 'guest';
}

/// The account already exists server-side under the Google/Facebook
/// identity a local-only guest just tried to link. Surfaced so the UI can
/// ask "keep this device's data, or switch to that account?" instead of
/// the link silently failing or silently picking a side.
class OAuthConflict {
  final String provider; // 'google' | 'facebook'
  final String existingDisplayName;
  final int existingElo;
  final String? existingAvatarUrl;
  /// The verified provider token, kept only to resend once the player
  /// picks - never persisted, lives just long enough for that round trip.
  final String rawToken;

  const OAuthConflict({
    required this.provider,
    required this.existingDisplayName,
    required this.existingElo,
    this.existingAvatarUrl,
    required this.rawToken,
  });
}

/// Result wrapper for auth operations.
class AuthResult {
  final bool success;
  final String? error;
  final String? errorCode;
  final BackendUser? user;
  final String? accessToken;
  final String? refreshToken;
  /// Only set when errorCode == 'LINKED_ELSEWHERE' - see OAuthConflict.
  final OAuthConflict? conflict;

  const AuthResult({
    required this.success,
    this.error,
    this.errorCode,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.conflict,
  });

  factory AuthResult.success(BackendUser user, String accessToken, String refreshToken) {
    return AuthResult(
      success: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  factory AuthResult.failure(String error, {String? errorCode}) {
    return AuthResult(success: false, error: error, errorCode: errorCode);
  }

  factory AuthResult.conflict(OAuthConflict conflict) {
    return AuthResult(success: false, errorCode: 'LINKED_ELSEWHERE', conflict: conflict);
  }
}

/// Auth against this app's own backend (`POST /api/auth/*`): Google,
/// Facebook, guest, and email/password (kept as a fallback, not shown as
/// the primary entry point - see OnlineAuthScreen). Session (tokens + a
/// full cached profile snapshot) is persisted via SharedPreferences so
/// both survive an app restart AND stay readable with zero network, which
/// is what makes opening the app offline show real data instead of a
/// blank/loading profile screen.
class BackendAuthService {
  final http.Client _client = http.Client();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    // Web client ID, not Android/iOS - see BackendConfig.googleServerClientId.
    // Without this, the ID token's audience won't match what the backend
    // checks against and verification will fail even for a real, valid
    // sign-in.
    serverClientId: BackendConfig.googleServerClientId.isNotEmpty ? BackendConfig.googleServerClientId : null,
  );

  BackendUser? _currentUser;
  String? _currentAccessToken;
  String? _currentRefreshToken;

  static const _kAccessTokenKey = 'auth_access_token';
  static const _kRefreshTokenKey = 'auth_refresh_token';
  static const _kUserJsonKey = 'auth_user_json'; // BackendUser, as JSON
  static const _kFullProfileJsonKey = 'auth_full_profile_json'; // OnlineUserProfile, as JSON - the offline-read cache

  /// Restores a previously persisted session, if any. Call once at
  /// startup, before dispatching CheckAuthStatus. Pure local read - no
  /// network - so this always succeeds offline as long as the device has
  /// signed in at least once before.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_kAccessTokenKey);
      final refreshToken = prefs.getString(_kRefreshTokenKey);
      final userJson = prefs.getString(_kUserJsonKey);

      if (userJson == null) return;
      final user = BackendUser.fromJson(json.decode(userJson) as Map<String, dynamic>);

      if (user.isLocalOnly) {
        // No tokens to restore for a local-only guest by definition.
        _currentUser = user;
        AppLogger.info('Restored local guest session for ${user.id}');
        return;
      }

      if (accessToken != null && refreshToken != null) {
        _currentAccessToken = accessToken;
        _currentRefreshToken = refreshToken;
        _currentUser = user;
        AppLogger.info('Restored session for ${user.id}');
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
      await prefs.setString(
        _kUserJsonKey,
        json.encode({
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
          'avatarUrl': user.avatarUrl,
          'elo': user.elo,
          'authProvider': user.authProvider,
          'settings': user.settings,
        }),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to persist session', e, stackTrace);
    }
  }

  /// Caches the FULL profile (with stats) for offline reading. Call this
  /// after every successful ApiClientService.getUserProfile()/
  /// updateProfile() so the most recent known-good snapshot is always on
  /// disk - see [cachedProfile].
  Future<void> cacheFullProfile(OnlineUserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFullProfileJsonKey, json.encode(profile.toJson()));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to cache full profile', e, stackTrace);
    }
  }

  /// The last full profile successfully fetched from the server, read
  /// from disk with no network involved. Null only if the device has
  /// never successfully fetched a profile at all (e.g. signed in once,
  /// fully offline ever since - practically doesn't happen, since sign-in
  /// itself requires network except for restoreSession()).
  Future<OnlineUserProfile?> get cachedProfile async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFullProfileJsonKey);
      if (raw == null) return null;
      return OnlineUserProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to read cached profile', e, stackTrace);
      return null;
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kAccessTokenKey),
        prefs.remove(_kRefreshTokenKey),
        prefs.remove(_kUserJsonKey),
        prefs.remove(_kFullProfileJsonKey),
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

  /// Shared success path for every sign-in method - Google/Facebook/guest/
  /// email all end up here once the backend has issued a token pair.
  Future<AuthResult> _completeSignIn(http.Response response, {required int expectedStatus, required String action}) async {
    if (response.statusCode == expectedStatus) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      final user = BackendUser.fromJson(body['user'] as Map<String, dynamic>);
      final accessToken = body['accessToken'] as String;
      final refreshToken = body['refreshToken'] as String;

      _currentUser = user;
      _currentAccessToken = accessToken;
      _currentRefreshToken = refreshToken;
      await _persistSession(user, accessToken, refreshToken);

      AppLogger.info('$action succeeded: ${user.id} (${user.authProvider})');
      return AuthResult.success(user, accessToken, refreshToken);
    }

    Map<String, dynamic>? errorBody;
    try {
      errorBody = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    final code = (errorBody?['error'] as Map?)?['code'] as String?;

    return AuthResult.failure(_errorMessageFrom(response.body, '$action failed') ?? '$action failed', errorCode: code);
  }

  /// Continue as a guest. Deliberately does NOT talk to the backend at
  /// all - purely a local identity (SharedPreferences only), so it works
  /// with zero network and never creates a throwaway row in `users`.
  /// Online multiplayer (ranked/custom rooms) isn't available in this
  /// state, since that needs a real server-side account - see
  /// `hasServerSession`. [linkGoogle]/[linkFacebook] are what turn this
  /// into a real account, at which point this local data is either merged
  /// into a fresh account or offered as a choice against an existing one.
  Future<AuthResult> signInAsGuest() async {
    final localId = 'local_guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final user = BackendUser(
      id: localId,
      displayName: 'Guest ${localId.substring(localId.length - 5)}',
      elo: 1200,
      authProvider: 'guest',
      isLocalOnly: true,
    );

    _currentUser = user;
    _currentAccessToken = null;
    _currentRefreshToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserJsonKey, json.encode(user.toJson()));
      // Local guest is never issued a token, so there's nothing under
      // _kAccessTokenKey/_kRefreshTokenKey to write - restoreSession()
      // already treats "user saved but no token" as a valid local-only
      // session, see below.
    } catch (e, stackTrace) {
      AppLogger.error('Failed to persist local guest session', e, stackTrace);
    }

    AppLogger.info('Local guest session created: $localId');
    return AuthResult(success: true, user: user);
  }

  /// Google Sign-In: opens the native account picker, then exchanges the
  /// resulting ID token with our backend, which verifies it server-side
  /// (see backend/src/auth/oauthVerify.ts) before issuing our own JWT -
  /// the Google token itself is never used again after this call. If the
  /// current session is a local-only guest, this doubles as a link
  /// attempt (see _oauthLoginWithLocalMerge) rather than abandoning that
  /// guest's local data.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User closed the picker - not an error, just no-op back to the
        // auth screen rather than showing a scary error message.
        return AuthResult.failure('', errorCode: 'CANCELLED');
      }
      final idToken = (await account.authentication).idToken;
      if (idToken == null) {
        return AuthResult.failure('Google sign-in did not return an ID token.');
      }
      return _oauthLoginWithLocalMerge('google', idToken);
    } catch (e, stackTrace) {
      AppLogger.error('Google sign-in error', e, stackTrace);
      return AuthResult.failure('Google sign-in failed: $e');
    }
  }

  /// Facebook Login: same pattern as Google - the access token only ever
  /// travels to our backend, which verifies it against Facebook's own
  /// debug_token endpoint before trusting it.
  Future<AuthResult> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      if (result.status == LoginStatus.cancelled) {
        return AuthResult.failure('', errorCode: 'CANCELLED');
      }
      if (result.status != LoginStatus.success || result.accessToken == null) {
        return AuthResult.failure(result.message ?? 'Facebook sign-in failed.');
      }
      return _oauthLoginWithLocalMerge('facebook', result.accessToken!.tokenString);
    } catch (e, stackTrace) {
      AppLogger.error('Facebook sign-in error', e, stackTrace);
      return AuthResult.failure('Facebook sign-in failed: $e');
    }
  }

  /// Finishes a link that returned a conflict, once the player has chosen.
  /// `keepLocal: true` overwrites the existing server account's profile
  /// with this device's local guest data; `false` discards the local
  /// guest data and signs into the existing account as-is.
  Future<AuthResult> resolveOAuthConflict(OAuthConflict conflict, {required bool keepLocal}) async {
    return _oauthLoginWithLocalMerge(
      conflict.provider,
      conflict.rawToken,
      resolution: keepLocal ? 'keep_local' : 'keep_existing',
    );
  }

  Future<AuthResult> _oauthLoginWithLocalMerge(String provider, String token, {String? resolution}) async {
    final localUser = _currentUser;
    final tokenField = provider == 'google' ? 'idToken' : 'accessToken';
    final endpoint = provider == 'google' ? 'oauth/google' : 'oauth/facebook';

    final body = <String, dynamic>{tokenField: token};
    // Only a local-only guest has data worth offering to merge - a
    // regular signed-in account calling this would just be a plain
    // provider switch, not something to seed/overwrite with.
    if (localUser != null && localUser.isLocalOnly) {
      body['localProfile'] = {'displayName': localUser.displayName, 'settings': localUser.settings};
    }
    if (resolution != null) body['resolution'] = resolution;

    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.authEndpoint}/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 409) {
        final errorBody = json.decode(response.body) as Map<String, dynamic>;
        final error = errorBody['error'] as Map<String, dynamic>;
        if (error['code'] == 'LINKED_ELSEWHERE') {
          final existing = error['existingAccount'] as Map<String, dynamic>;
          return AuthResult.conflict(OAuthConflict(
            provider: provider,
            existingDisplayName: existing['displayName'] as String,
            existingElo: existing['elo'] as int,
            existingAvatarUrl: existing['avatarUrl'] as String?,
            rawToken: token,
          ));
        }
      }

      return _completeSignIn(
        response,
        expectedStatus: response.statusCode == 201 ? 201 : 200,
        action: provider == 'google' ? 'Google sign-in' : 'Facebook sign-in',
      );
    } catch (e, stackTrace) {
      AppLogger.error('$provider OAuth error', e, stackTrace);
      return AuthResult.failure('Sign-in failed: $e');
    }
  }

  /// Email/password - kept as a fallback path (see OnlineAuthScreen's
  /// "use email instead" link), not the primary entry point anymore.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.authEndpoint}/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password, 'displayName': displayName}),
      );
      return _completeSignIn(response, expectedStatus: 201, action: 'Sign up');
    } catch (e, stackTrace) {
      AppLogger.error('Sign up error', e, stackTrace);
      return AuthResult.failure('Could not reach the server. Check your connection and try again.');
    }
  }

  Future<AuthResult> signInWithEmail({required String email, required String password}) async {
    try {
      final response = await _client.post(
        Uri.parse('${BackendConfig.authEndpoint}/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
      return _completeSignIn(response, expectedStatus: 200, action: 'Sign in');
    } catch (e, stackTrace) {
      AppLogger.error('Sign in error', e, stackTrace);
      return AuthResult.failure('Could not reach the server. Check your connection and try again.');
    }
  }

  /// Exchange the stored refresh token for a new access token. Returns
  /// false if there's no refresh token, or the server explicitly rejects
  /// it (expired/invalid/for a deleted user) - a network-level failure
  /// (no connectivity) also returns false but does NOT clear the session,
  /// since "couldn't reach the server" is not the same thing as "your
  /// token is invalid". Callers (AuthBloc) still need to check
  /// `isSignedIn` afterward to tell the two apart.
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

      if (response.statusCode == 401) {
        AppLogger.info('Refresh token rejected (401), clearing session');
        await signOut();
      }
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Session refresh error (treated as offline, session kept)', e, stackTrace);
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
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    AppLogger.info('User signed out');
  }

  bool get isSignedIn => _currentUser != null && (_currentUser!.isLocalOnly || _currentAccessToken != null);
  /// False for a local-only guest (see [signInAsGuest]) - features that
  /// need a real server identity (online multiplayer, campaign
  /// submission) should check this and prompt to link Google/Facebook
  /// rather than trying to use a token that doesn't exist.
  bool get hasServerSession => _currentUser != null && !_currentUser!.isLocalOnly && _currentAccessToken != null;
  BackendUser? get currentUser => _currentUser;
  String? get currentAccessToken => _currentAccessToken;
  String? get currentUserId => _currentUser?.id;

  void dispose() {
    _client.close();
  }
}
