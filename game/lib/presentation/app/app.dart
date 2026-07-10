import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/injection.dart';
import '../blocs/online/auth_bloc.dart';
import '../blocs/online/matchmaking_bloc.dart';
import '../blocs/online/online_game_bloc.dart';
import '../screens/splash/splash_screen.dart';
import '../themes/app_theme.dart';
import 'routes.dart';

class KingsGambitAIApp extends StatelessWidget {
  const KingsGambitAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => getIt<AuthBloc>()..add(const CheckAuthStatus()),
        ),
        BlocProvider<MatchmakingBloc>(
          create: (context) => getIt<MatchmakingBloc>(),
        ),
        BlocProvider<OnlineGameBloc>(
          create: (context) => getIt<OnlineGameBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'King\'s Gambit AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Always use dark theme
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const SplashScreen(),
      ),
    );
  }
}
