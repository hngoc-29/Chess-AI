import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/utils/logger.dart';
import '../../models/online/user_profile.dart';

/// Result wrapper for auth operations
class AuthResult {
  final bool success;
  final String? error;
  final User? user;
  final String? accessToken;

  const AuthResult({
    required this.success,
    this.error,
    this.user,
    this.accessToken,
  });

  factory AuthResult.success(User user, String accessToken) {
    return AuthResult(
      success: true,
      user: user,
      accessToken: accessToken,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(success: false, error: error);
  }
}

/// Supabase authentication service
class SupabaseAuthService {
  late final SupabaseClient _supabase;
  User? _currentUser;
  String? _currentAccessToken;

  SupabaseAuthService() {
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    try {
      await Supabase.initialize(
        url: BackendConfig.supabaseUrl,
        anonKey: BackendConfig.supabaseAnonKey,
      );
      _supabase = Supabase.instance.client;

      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((data) {
        _currentUser = data.session?.user;
        _currentAccessToken = data.session?.accessToken;
        AppLogger.info('Auth state changed: ${_currentUser?.id}');
      });

      AppLogger.info('Supabase initialized');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Supabase', e, stackTrace);
    }
  }

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      if (response.user == null) {
        return AuthResult.failure('Sign up failed');
      }

      _currentUser = response.user;
      _currentAccessToken = response.session?.accessToken;

      AppLogger.info('User signed up: ${response.user!.id}');
      return AuthResult.success(
        response.user!,
        response.session!.accessToken,
      );
    } on AuthException catch (e) {
      AppLogger.error('Sign up error', e, StackTrace.current);
      return AuthResult.failure(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected sign up error', e, stackTrace);
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return AuthResult.failure('Sign in failed');
      }

      _currentUser = response.user;
      _currentAccessToken = response.session?.accessToken;

      AppLogger.info('User signed in: ${response.user!.id}');
      return AuthResult.success(
        response.user!,
        response.session!.accessToken,
      );
    } on AuthException catch (e) {
      AppLogger.error('Sign in error', e, StackTrace.current);
      return AuthResult.failure(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected sign in error', e, stackTrace);
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _currentAccessToken = null;
      AppLogger.info('User signed out');
    } catch (e, stackTrace) {
      AppLogger.error('Sign out error', e, stackTrace);
    }
  }

  /// Sign in with Google OAuth
  Future<AuthResult> signInWithGoogle() async {
    try {
      AppLogger.info('Initiating Google OAuth sign in...');
      
      final result = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.kingsgambit.chess://login-callback',
      );
      
      if (!result) {
        return AuthResult.failure('Google sign in cancelled');
      }

      // Wait for auth state to update
      await Future.delayed(const Duration(seconds: 1));
      
      if (_currentUser != null && _currentAccessToken != null) {
        AppLogger.info('Google OAuth sign in successful: ${_currentUser!.id}');
        return AuthResult.success(_currentUser!, _currentAccessToken!);
      } else {
        return AuthResult.failure('Failed to complete Google sign in');
      }
    } on AuthException catch (e) {
      AppLogger.error('Google OAuth sign in error', e, StackTrace.current);
      return AuthResult.failure(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected Google OAuth error', e, stackTrace);
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign in with Facebook OAuth
  Future<AuthResult> signInWithFacebook() async {
    try {
      AppLogger.info('Initiating Facebook OAuth sign in...');
      
      final result = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'com.kingsgambit.chess://login-callback',
      );
      
      if (!result) {
        return AuthResult.failure('Facebook sign in cancelled');
      }

      // Wait for auth state to update
      await Future.delayed(const Duration(seconds: 1));
      
      if (_currentUser != null && _currentAccessToken != null) {
        AppLogger.info('Facebook OAuth sign in successful: ${_currentUser!.id}');
        return AuthResult.success(_currentUser!, _currentAccessToken!);
      } else {
        return AuthResult.failure('Failed to complete Facebook sign in');
      }
    } on AuthException catch (e) {
      AppLogger.error('Facebook OAuth sign in error', e, StackTrace.current);
      return AuthResult.failure(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected Facebook OAuth error', e, stackTrace);
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null && _currentAccessToken != null;

  /// Get current user
  User? get currentUser => _currentUser;

  /// Get current access token
  String? get currentAccessToken => _currentAccessToken;

  /// Get current user ID
  String? get currentUserId => _currentUser?.id;

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      AppLogger.info('Password reset email sent to: $email');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Password reset error', e, stackTrace);
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.auth.updateUser(UserAttributes(data: updates));
      AppLogger.info('User profile updated');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Profile update error', e, stackTrace);
      return false;
    }
  }

  /// Refresh session
  Future<bool> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      if (response.session != null) {
        _currentAccessToken = response.session!.accessToken;
        AppLogger.info('Session refreshed');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Session refresh error', e, stackTrace);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    // Supabase client cleanup is handled by the SDK
  }
}
