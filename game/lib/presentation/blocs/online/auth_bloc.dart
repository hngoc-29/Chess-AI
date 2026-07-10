import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../services/online/supabase_auth_service.dart';
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

class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}

class FacebookSignInRequested extends AuthEvent {
  const FacebookSignInRequested();
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
  final SupabaseAuthService _authService;
  final SocketIOService _socketService;
  final ApiClientService _apiService;

  AuthBloc({
    required SupabaseAuthService authService,
    required SocketIOService socketService,
    required ApiClientService apiService,
  })  : _authService = authService,
        _socketService = socketService,
        _apiService = apiService,
        super(const AuthInitial()) {
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<FacebookSignInRequested>(_onFacebookSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ProfileLoadRequested>(_onProfileLoadRequested);
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authService.signInWithGoogle();

      if (result.success && result.user != null && result.accessToken != null) {
        // Set access token for API and Socket services
        _apiService.setAccessToken(result.accessToken!);
        
        // Connect to Socket.IO
        await _socketService.connect(result.accessToken!);

        // Load user profile
        final profileResult = await _apiService.getUserProfile(result.user!.id);
        
        emit(AuthAuthenticated(
          userId: result.user!.id,
          accessToken: result.accessToken!,
          profile: profileResult.data,
        ));

        AppLogger.info('User signed in with Google: ${result.user!.id}');
      } else {
        emit(AuthError(result.error ?? 'Google sign in failed'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Google sign in error', e, stackTrace);
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onFacebookSignInRequested(
    FacebookSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await _authService.signInWithFacebook();

      if (result.success && result.user != null && result.accessToken != null) {
        // Set access token for API and Socket services
        _apiService.setAccessToken(result.accessToken!);
        
        // Connect to Socket.IO
        await _socketService.connect(result.accessToken!);

        // Load user profile
        final profileResult = await _apiService.getUserProfile(result.user!.id);
        
        emit(AuthAuthenticated(
          userId: result.user!.id,
          accessToken: result.accessToken!,
          profile: profileResult.data,
        ));

        AppLogger.info('User signed in with Facebook: ${result.user!.id}');
      } else {
        emit(AuthError(result.error ?? 'Facebook sign in failed'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Facebook sign in error', e, stackTrace);
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Disconnect socket
      _socketService.disconnect();
      
      // Sign out from Supabase
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
    if (_authService.isSignedIn && _authService.currentAccessToken != null) {
      final userId = _authService.currentUserId!;
      final accessToken = _authService.currentAccessToken!;

      // Set access token for services
      _apiService.setAccessToken(accessToken);
      
      // Connect to Socket.IO if not connected
      if (!_socketService.isConnected) {
        await _socketService.connect(accessToken);
      }

      // Load user profile
      final profileResult = await _apiService.getUserProfile(userId);
      
      emit(AuthAuthenticated(
        userId: userId,
        accessToken: accessToken,
        profile: profileResult.data,
      ));
    } else {
      emit(const AuthUnauthenticated());
    }
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
