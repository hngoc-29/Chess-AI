import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/durations.dart';
import '../../app/routes.dart';
import '../../blocs/online/auth_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _navigateToMainMenu();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToMainMenu() async {
    await Future.delayed(AppDurations.splash);
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }

    // AuthBloc's CheckAuthStatus was dispatched the moment the app started
    // (see KingsGambitAIApp), running in parallel with this screen's own
    // delay/animation above - by now it has very likely already resolved.
    // If it somehow hasn't (slow network on the profile fetch), wait for
    // it rather than guessing, so a returning player is never dropped
    // onto the auth screen just because this raced ahead of it.
    final authBloc = context.read<AuthBloc>();
    var state = authBloc.state;
    if (state is AuthInitial || state is AuthLoading) {
      state = await authBloc.stream.firstWhere((s) => s is! AuthInitial && s is! AuthLoading);
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      state is AuthAuthenticated ? AppRoutes.mainMenu : AppRoutes.onlineAuth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(scale: _scale.value, child: child),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 108,
                height: 84,
                child: SvgPicture.asset('assets/images/branding/king_mark.svg'),
              ),
              const SizedBox(height: 24),
              Text(
                "King's Gambit AI",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
