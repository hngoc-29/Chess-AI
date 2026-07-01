import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../app/routes.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 64),
                _MenuButton(
                  title: AppStrings.playVsAI,
                  icon: Icons.computer,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.game);
                  },
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  title: AppStrings.playVsHuman,
                  icon: Icons.people,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.game);
                  },
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  title: AppStrings.settings,
                  icon: Icons.settings,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.settings);
                  },
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  title: AppStrings.statistics,
                  icon: Icons.bar_chart,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.statistics);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
