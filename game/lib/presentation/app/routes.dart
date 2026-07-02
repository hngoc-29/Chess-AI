import 'package:flutter/material.dart';

import '../screens/analysis/analysis_screen.dart';
import '../screens/debug_logs_screen.dart';
import '../screens/game/game_screen.dart';
import '../screens/main_menu/main_menu_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/replay/replay_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/statistics/statistics_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String mainMenu = '/main-menu';
  static const String game = '/game';
  static const String settings = '/settings';
  static const String statistics = '/statistics';
  static const String profile = '/profile';
  static const String replay = '/replay';
  static const String analysis = '/analysis';
  static const String debugLogs = '/debug-logs';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case mainMenu:
        return MaterialPageRoute(builder: (_) => const MainMenuScreen());
      case game:
        return MaterialPageRoute(builder: (_) => const GameScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case statistics:
        return MaterialPageRoute(builder: (_) => const StatisticsScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case replay:
        return MaterialPageRoute(builder: (_) => const ReplayScreen());
      case analysis:
        return MaterialPageRoute(builder: (_) => const AnalysisScreen());
      case debugLogs:
        return MaterialPageRoute(builder: (_) => const DebugLogsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }
}
