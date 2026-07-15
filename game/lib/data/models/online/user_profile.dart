import 'package:equatable/equatable.dart';

/// User profile data from the backend.
///
/// Two backend endpoints return a user object with different key casing:
/// GET /api/auth/me returns the raw DB row (snake_case: display_name,
/// avatar_url, ...), while PATCH /api/auth/me and the various sign-in
/// endpoints return a normalized camelCase shape. Rather than maintaining
/// two model classes, [fromJson] accepts a `camelCase` flag so either
/// response shape lands in the same model.
class OnlineUserProfile extends Equatable {
  final String id;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final int elo;
  final String authProvider;
  final Map<String, dynamic> settings;
  final int gamesPlayed;
  final int gamesWon;
  final int gamesDrawn;
  final int gamesLost;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OnlineUserProfile({
    required this.id,
    this.email,
    required this.displayName,
    this.avatarUrl,
    required this.elo,
    this.authProvider = 'email',
    this.settings = const {},
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesDrawn = 0,
    this.gamesLost = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory OnlineUserProfile.fromJson(Map<String, dynamic> json, {bool camelCase = false}) {
    Map<String, dynamic> parseSettings(dynamic raw) {
      if (raw is Map) return raw.cast<String, dynamic>();
      return const {};
    }

    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          return DateTime.parse(raw);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    if (camelCase) {
      return OnlineUserProfile(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        elo: json['elo'] as int? ?? 1200,
        authProvider: json['authProvider'] as String? ?? 'email',
        settings: parseSettings(json['settings']),
        // Register/login/guest/OAuth responses don't include stats - keep
        // whatever the caller already has rather than resetting to 0
        // (AuthBloc merges this against the previously-cached profile).
      );
    }

    return OnlineUserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      elo: json['elo'] as int? ?? 1200,
      authProvider: json['auth_provider'] as String? ?? 'email',
      settings: parseSettings(json['settings']),
      gamesPlayed: json['games_played'] as int? ?? 0,
      gamesWon: json['games_won'] as int? ?? 0,
      gamesDrawn: json['games_drawn'] as int? ?? 0,
      gamesLost: json['games_lost'] as int? ?? 0,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  /// Always writes the full snake_case shape, since this is what gets fed
  /// back into [fromJson] (camelCase: false) when reading the offline
  /// cache - see BackendAuthService.cachedProfile.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'elo': elo,
      'auth_provider': authProvider,
      'settings': settings,
      'games_played': gamesPlayed,
      'games_won': gamesWon,
      'games_drawn': gamesDrawn,
      'games_lost': gamesLost,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Returns a copy with fields from a fresher-but-partial update layered
  /// on top - used when a camelCase auth response (no stats) needs to
  /// merge into an existing full profile without losing games_played etc.
  OnlineUserProfile mergeFrom(OnlineUserProfile fresher) {
    return OnlineUserProfile(
      id: fresher.id,
      email: fresher.email ?? email,
      displayName: fresher.displayName,
      avatarUrl: fresher.avatarUrl ?? avatarUrl,
      elo: fresher.elo,
      authProvider: fresher.authProvider,
      settings: fresher.settings.isNotEmpty ? fresher.settings : settings,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      gamesDrawn: gamesDrawn,
      gamesLost: gamesLost,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  double get winRate {
    if (gamesPlayed == 0) return 0.0;
    return gamesWon / gamesPlayed;
  }

  bool get isGuest => authProvider == 'guest';

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        elo,
        authProvider,
        settings,
        gamesPlayed,
        gamesWon,
        gamesDrawn,
        gamesLost,
        createdAt,
        updatedAt,
      ];
}
