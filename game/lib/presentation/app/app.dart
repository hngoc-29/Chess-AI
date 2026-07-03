import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../themes/app_theme.dart';
import 'routes.dart';

class KingsGambitAIApp extends StatelessWidget {
  const KingsGambitAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'King\'s Gambit AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Always use dark theme
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const SplashScreen(),
    );
  }
}
