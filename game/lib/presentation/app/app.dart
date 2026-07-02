import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../themes/app_theme.dart';
import 'routes.dart';

class ChessAIApp extends StatelessWidget {
  const ChessAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const SplashScreen(),
    );
  }
}
