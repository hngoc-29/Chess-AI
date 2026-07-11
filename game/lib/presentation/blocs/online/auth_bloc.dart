import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../services/online/backend_auth_service.dart';
import '../../../services/online/socket_io_service.dart';
import '../../../services/online/api_client_service.dart';
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

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

class ProfileLoadRequested extends AuthEvent {
  const ProfileLoadRequested();
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
  final String accessToken;
  final OnlineUserProfile? profile;

  const AuthAuthenticated({
    required this.userId,
    required this.accessToken,
    this.profile,
  });

  @override
  List<Object?> get props => [userId, accessToken, profile];
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

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final BackendAuthService _authService;
  final SocketIOService _socketService;
  final ApiClientService _apiService;

  AuthBloc({
    required BackendAuthService authService,
    required SocketIOService socketService,
    required ApiClientService apiService,
  })  : _authService = authService,
        _socketService = socketService,
        _apiService = apiService,
        super(const AuthInitial()) {
    on<SignInRequested>(_onSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ProfileLoadRequested>(_onProfileLoadRequested);
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );
      await _handleAuthResult(result, emit);
    } catch (e, stackTrace) {
      AppLogger.error('Sign in error', e, stackTrace);
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
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

  /// Shared success path for sign-in and sign-up: wire the new access
  /// token into the REST client + socket connection, then load the full
  /// profile (stats aren't in the register/login response - see
  /// ApiClientService.getUserProfile).
  Future<void> _handleAuthResult(AuthResult result, Emitter<AuthState> emit) async {
    if (result.success && result.user != null && result.accessToken != null) {
      _apiService.setAccessToken(result.accessToken!);
      await _socketService.connect(result.accessToken!);

      final profileResult = await _apiService.getUserProfile(result.user!.id);

      emit(AuthAuthenticated(
        userId: result.user!.id,
        accessToken: result.accessToken!,
        profile: profileResult.data,
      ));

      AppLogger.info('User authenticated: ${result.user!.id}');
    } else {
      emit(AuthError(result.error ?? 'Authentication failed'));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
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

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    // Load any session persisted from a previous run first - isSignedIn
    // only reflects in-memory state otherwise, which is always empty
    // right after a fresh app launch.
    await _authService.restoreSession();

    if (!_authService.isSignedIn || _authService.currentAccessToken == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    final userId = _authService.currentUserId!;
    var accessToken = _authService.currentAccessToken!;
    _apiService.setAccessToken(accessToken);

    // getUserProfile is a plain HTTP call with a real status code, so
    // unlike the socket connection (which fails asynchronously via an
    // event rather than a thrown error - see SocketIOService.connect) it
    // reliably tells us whether the stored access token is still valid.
    var profileResult = await _apiService.getUserProfile(userId);

    if (!profileResult.success) {
      final refreshed = await _authService.refreshSession();
      if (!refreshed) {
        emit(const AuthUnauthenticated());
        return;
      }
      accessToken = _authService.currentAccessToken!;
      _apiService.setAccessToken(accessToken);
      profileResult = await _apiService.getUserProfile(userId);
    }

    if (!_socketService.isConnected) {
      await _socketService.connect(accessToken);
    }

    emit(AuthAuthenticated(
      userId: userId,
      accessToken: accessToken,
      profile: profileResult.data,
    ));
  }

  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentState = state as AuthAuthenticated;

      try {
        final profileResult = await _apiService.getUserProfile(currentState.userId);

        if (profileResult.success && profileResult.data != null) {
          emit(AuthAuthenticated(
            userId: currentState.userId,
            accessToken: currentState.accessToken,
            profile: profileResult.data,
          ));
        }
      } catch (e, stackTrace) {
        AppLogger.error('Profile load error', e, stackTrace);
      }
    }
  }

  @override
  Future<void> close() {
    _socketService.disconnect();
    return super.close();
  }
}
