import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../services/online/backend_auth_service.dart';
import '../../../services/online/socket_io_service.dart';
import '../../../services/online/api_client_service.dart';
import '../../../services/online/offline_sync_service.dart';
import '../../../data/models/online/user_profile.dart';
import '../../../core/utils/logger.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  const SignUpRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}

class FacebookSignInRequested extends AuthEvent {
  const FacebookSignInRequested();
}

class GuestSignInRequested extends AuthEvent {
  const GuestSignInRequested();
}

/// Sent after the player answers the "keep this device's data or the
/// existing account's?" prompt shown for AuthOAuthConflict.
class OAuthConflictResolved extends AuthEvent {
  final OAuthConflict conflict;
  final bool keepLocal;

  const OAuthConflictResolved({required this.conflict, required this.keepLocal});

  @override
  List<Object?> get props => [conflict, keepLocal];
}

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

class ProfileLoadRequested extends AuthEvent {
  const ProfileLoadRequested();
}

/// Profile edit - goes through OfflineSyncService, so this succeeds
/// immediately (optimistic) even with no connectivity; see
/// OfflineSyncService for when it actually reaches the backend.
class ProfileUpdateRequested extends AuthEvent {
  final String? displayName;
  final String? avatarUrl;
  final Map<String, dynamic>? settings;

  const ProfileUpdateRequested({this.displayName, this.avatarUrl, this.settings});

  @override
  List<Object?> get props => [displayName, avatarUrl, settings];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String? accessToken; // null for a local-only guest
  final OnlineUserProfile? profile;
  final bool isLocalOnlyGuest;
  /// True when [profile] came from the offline cache rather than a fresh
  /// server response - e.g. the device is offline right now. The UI can
  /// use this to show a small "offline" indicator instead of presenting
  /// possibly-stale data as if it were live.
  final bool isStale;
  final int pendingSyncCount;

  const AuthAuthenticated({
    required this.userId,
    this.accessToken,
    this.profile,
    this.isLocalOnlyGuest = false,
    this.isStale = false,
    this.pendingSyncCount = 0,
  });

  AuthAuthenticated copyWith({
    OnlineUserProfile? profile,
    bool? isStale,
    int? pendingSyncCount,
  }) {
    return AuthAuthenticated(
      userId: userId,
      accessToken: accessToken,
      profile: profile ?? this.profile,
      isLocalOnlyGuest: isLocalOnlyGuest,
      isStale: isStale ?? this.isStale,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }

  @override
  List<Object?> get props => [userId, accessToken, profile, isLocalOnlyGuest, isStale, pendingSyncCount];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

/// A Google/Facebook link found an existing account under that identity.
/// The UI should ask the player to choose, then dispatch
/// OAuthConflictResolved - this state just carries what's needed to ask.
class AuthOAuthConflict extends AuthState {
  final OAuthConflict conflict;

  const AuthOAuthConflict(this.conflict);

  @override
  List<Object?> get props => [conflict];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final BackendAuthService _authService;
  final SocketIOService _socketService;
  final ApiClientService _apiService;
  final OfflineSyncService _syncService;

  AuthBloc({
    required BackendAuthService authService,
    required SocketIOService socketService,
    required ApiClientService apiService,
    required OfflineSyncService syncService,
  })  : _authService = authService,
        _socketService = socketService,
        _apiService = apiService,
        _syncService = syncService,
        super(const AuthInitial()) {
    on<SignInRequested>(_onSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<FacebookSignInRequested>(_onFacebookSignInRequested);
    on<GuestSignInRequested>(_onGuestSignInRequested);
    on<OAuthConflictResolved>(_onOAuthConflictResolved);
    on<SignOutRequested>(_onSignOutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<ProfileUpdateRequested>(_onProfileUpdateRequested);

    // Whenever the pending-edits queue drains (device came back online),
    // refresh so the UI's pendingSyncCount badge clears and shows the
    // server's confirmed state rather than the optimistic local one.
    _syncService.onQueueChanged = () {
      if (state is AuthAuthenticated) add(const ProfileLoadRequested());
    };
  }

  Future<void> _onSignInRequested(SignInRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final result = await _authService.signInWithEmail(email: event.email, password: event.password);
      await _handleAuthResult(result, emit);
    } catch (e, stackTrace) {
      AppLogger.error('Sign in error', e, stackTrace);
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onSignUpRequested(SignUpRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final result = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      await _handleAuthResult(result, emit);
    } catch (e, stackTrace) {
      AppLogger.error('Sign up error', e, stackTrace);
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onGoogleSignInRequested(GoogleSignInRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _authService.signInWithGoogle();
    await _handleOAuthResult(result, emit);
  }

  Future<void> _onFacebookSignInRequested(FacebookSignInRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _authService.signInWithFacebook();
    await _handleOAuthResult(result, emit);
  }

  Future<void> _onGuestSignInRequested(GuestSignInRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _authService.signInAsGuest();
    if (result.success && result.user != null) {
      emit(AuthAuthenticated(userId: result.user!.id, isLocalOnlyGuest: true));
      AppLogger.info('Guest session active: ${result.user!.id}');
    } else {
      emit(AuthError(result.error ?? 'Could not start a guest session'));
    }
  }

  Future<void> _onOAuthConflictResolved(OAuthConflictResolved event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _authService.resolveOAuthConflict(event.conflict, keepLocal: event.keepLocal);
    await _handleOAuthResult(result, emit);
  }

  /// Shared by Google/Facebook sign-in and conflict resolution: either a
  /// normal success, or a conflict that needs the player's input.
  Future<void> _handleOAuthResult(AuthResult result, Emitter<AuthState> emit) async {
    if (result.errorCode == 'LINKED_ELSEWHERE' && result.conflict != null) {
      emit(AuthOAuthConflict(result.conflict!));
      return;
    }
    if (result.errorCode == 'CANCELLED') {
      // Player closed the provider picker - quietly return to whatever
      // they were looking at, no error banner needed.
      emit(state is AuthAuthenticated ? state : const AuthUnauthenticated());
      return;
    }
    await _handleAuthResult(result, emit);
  }

  /// Shared success path for every sign-in method that talks to the
  /// backend: wire the new access token into the REST client + socket
  /// connection, then load the full profile (stats aren't in the
  /// register/login response - see ApiClientService.getUserProfile).
  Future<void> _handleAuthResult(AuthResult result, Emitter<AuthState> emit) async {
    if (result.success && result.user != null && result.accessToken != null) {
      _apiService.setAccessToken(result.accessToken!);
      await _socketService.connect(result.accessToken!);

      final profileResult = await _apiService.getUserProfile(result.user!.id);
      if (profileResult.success && profileResult.data != null) {
        await _authService.cacheFullProfile(profileResult.data!);
      }

      emit(AuthAuthenticated(
        userId: result.user!.id,
        accessToken: result.accessToken,
        profile: profileResult.data,
      ));

      AppLogger.info('User authenticated: ${result.user!.id}');
    } else if (result.errorCode != 'CANCELLED') {
      emit(AuthError(result.error ?? 'Authentication failed'));
    }
  }

  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
    try {
      _socketService.disconnect();
      await _authService.signOut();
      emit(const AuthUnauthenticated());
      AppLogger.info('User signed out');
    } catch (e, stackTrace) {
      AppLogger.error('Sign out error', e, stackTrace);
      emit(AuthError('Sign out failed: $e'));
    }
  }

  /// Restores whatever session exists (local guest or real account) and,
  /// for a real account, tries to confirm it's still valid server-side -
  /// but a network failure here falls back to the cached profile rather
  /// than logging the player out. Only an explicit 401 (the server
  /// itself rejecting the token) does that. Without this distinction,
  /// opening the app with no signal would incorrectly boot an already
  /// signed-in player back to the auth screen every time.
  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    await _authService.restoreSession();

    if (!_authService.isSignedIn) {
      emit(const AuthUnauthenticated());
      return;
    }

    final userId = _authService.currentUserId!;

    if (_authService.currentUser?.isLocalOnly == true) {
      final cached = await _authService.cachedProfile;
      emit(AuthAuthenticated(userId: userId, profile: cached, isLocalOnlyGuest: true));
      return;
    }

    var accessToken = _authService.currentAccessToken!;
    _apiService.setAccessToken(accessToken);

    var profileResult = await _apiService.getUserProfile(userId);

    if (!profileResult.success && profileResult.isNetworkError) {
      // Offline, not logged out - use the last good snapshot from disk.
      final cached = await _authService.cachedProfile;
      if (!_socketService.isConnected) {
        // Best-effort; if there's really no network this will just fail
        // silently and retry next time something triggers a reconnect.
        unawaited(_socketService.connect(accessToken));
      }
      emit(AuthAuthenticated(
        userId: userId,
        accessToken: accessToken,
        profile: cached,
        isStale: true,
        pendingSyncCount: _syncService.pendingCount,
      ));
      return;
    }

    if (!profileResult.success) {
      // A real response, just not a 200 - most likely 401. Only now is it
      // safe to try a refresh, and only a genuine rejection (not another
      // network error) should sign the player out.
      final refreshed = await _authService.refreshSession();
      if (!refreshed) {
        if (_authService.isSignedIn) {
          // refreshSession() itself hit a network error and deliberately
          // left the session intact - fall back to cache, same as above.
          final cached = await _authService.cachedProfile;
          emit(AuthAuthenticated(
            userId: userId,
            accessToken: accessToken,
            profile: cached,
            isStale: true,
            pendingSyncCount: _syncService.pendingCount,
          ));
        } else {
          emit(const AuthUnauthenticated());
        }
        return;
      }
      accessToken = _authService.currentAccessToken!;
      _apiService.setAccessToken(accessToken);
      profileResult = await _apiService.getUserProfile(userId);
    }

    if (profileResult.success && profileResult.data != null) {
      await _authService.cacheFullProfile(profileResult.data!);
    }

    if (!_socketService.isConnected) {
      await _socketService.connect(accessToken);
    }

    emit(AuthAuthenticated(
      userId: userId,
      accessToken: accessToken,
      profile: profileResult.data ?? await _authService.cachedProfile,
      isStale: !profileResult.success,
      pendingSyncCount: _syncService.pendingCount,
    ));
  }

  Future<void> _onProfileLoadRequested(ProfileLoadRequested event, Emitter<AuthState> emit) async {
    if (state is! AuthAuthenticated) return;
    final currentState = state as AuthAuthenticated;
    if (currentState.isLocalOnlyGuest) return; // nothing server-side to load

    try {
      final profileResult = await _apiService.getUserProfile(currentState.userId);
      if (profileResult.success && profileResult.data != null) {
        await _authService.cacheFullProfile(profileResult.data!);
        emit(currentState.copyWith(
          profile: profileResult.data,
          isStale: false,
          pendingSyncCount: _syncService.pendingCount,
        ));
      } else if (profileResult.isNetworkError) {
        emit(currentState.copyWith(isStale: true, pendingSyncCount: _syncService.pendingCount));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Profile load error', e, stackTrace);
    }
  }

  /// Optimistic: applies the edit to the cached profile + UI immediately,
  /// then hands off to OfflineSyncService, which sends it now if online or
  /// queues it for whenever connectivity returns. The player never has to
  /// know or care which of those happened.
  Future<void> _onProfileUpdateRequested(ProfileUpdateRequested event, Emitter<AuthState> emit) async {
    if (state is! AuthAuthenticated) return;
    final currentState = state as AuthAuthenticated;
    final current = currentState.profile;

    if (current != null) {
      final optimistic = OnlineUserProfile(
        id: current.id,
        email: current.email,
        displayName: event.displayName ?? current.displayName,
        avatarUrl: event.avatarUrl ?? current.avatarUrl,
        elo: current.elo,
        authProvider: current.authProvider,
        settings: event.settings ?? current.settings,
        gamesPlayed: current.gamesPlayed,
        gamesWon: current.gamesWon,
        gamesDrawn: current.gamesDrawn,
        gamesLost: current.gamesLost,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      );
      await _authService.cacheFullProfile(optimistic);
      emit(currentState.copyWith(profile: optimistic));
    }

    if (currentState.isLocalOnlyGuest) {
      // Nothing to sync yet - this IS local storage. Once the guest
      // links Google/Facebook, the linked-in local data already reflects
      // this edit (see BackendAuthService._oauthLoginWithLocalMerge).
      return;
    }

    await _syncService.enqueueProfileUpdate(
      displayName: event.displayName,
      avatarUrl: event.avatarUrl,
      settings: event.settings,
    );
    emit((state as AuthAuthenticated).copyWith(pendingSyncCount: _syncService.pendingCount));
  }

  @override
  Future<void> close() {
    _socketService.disconnect();
    return super.close();
  }
}
