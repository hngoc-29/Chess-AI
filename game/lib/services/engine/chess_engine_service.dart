// Export the appropriate implementation based on platform
// On web: uses chess_engine_service_web.dart (stub without dart:ffi)
// On native platforms: uses chess_engine_service_native.dart (with dart:ffi)
export 'chess_engine_service_native.dart'
  if (dart.library.html) 'chess_engine_service_web.dart';

// Re-export the interface
export 'chess_engine_service_interface.dart';
