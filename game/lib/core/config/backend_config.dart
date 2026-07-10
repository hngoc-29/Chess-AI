/// Backend API configuration
class BackendConfig {
  // Backend URL - change this to your deployed backend URL
  static const String backendUrl = 'http://localhost:8080';
  
  // Supabase configuration - replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://xxxxx.supabase.co';
  static const String supabaseAnonKey = 'your_supabase_anon_key';
  
  // API endpoints
  static const String apiBase = '$backendUrl/api';
  static const String authEndpoint = '$apiBase/auth';
  static const String matchesEndpoint = '$apiBase/matches';
  static const String campaignEndpoint = '$apiBase/campaign';
  static const String healthEndpoint = '$backendUrl/health';
  
  // Socket.IO configuration
  static const String socketUrl = backendUrl;
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 5;
  
  // Game configuration
  static const Duration matchmakingTimeout = Duration(seconds: 60);
  static const Duration reconnectGracePeriod = Duration(seconds: 30);
  
  // Rate limiting (client-side hints)
  static const int maxMovesPerSecond = 10;
  static const int maxChatMessagesPerWindow = 3;
  static const Duration chatRateLimitWindow = Duration(seconds: 2);
}
