import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/strings.dart';
import '../../../core/constants/colors.dart';
import '../game/game_screen.dart';
import '../../app/routes.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _showAboutDialog(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryDark,
                            AppColors.backgroundDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: 28,
                        height: 22,
                        child: SvgPicture.asset('assets/images/branding/king_mark.svg'),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.settings, color: AppColors.textPrimaryDark),
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.settings);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.info_outline, color: AppColors.textPrimaryDark),
                        onPressed: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Hero card with gradient
                    _buildHeroCard(context),
                    const SizedBox(height: 32),
                    // Menu items
                    _buildMenuItem(
                      context,
                      title: 'Play vs AI',
                      subtitle: 'Play against the engine',
                      icon: Icons.smart_toy,
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GameScreen(vsAI: true),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuItem(
                      context,
                      title: 'Human vs Human',
                      subtitle: 'Play with a friend',
                      icon: Icons.people,
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GameScreen(vsAI: false),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuItem(
                      context,
                      title: 'Training',
                      subtitle: 'Load FEN and practice positions',
                      icon: Icons.school,
                      iconColor: AppColors.secondary,
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.training);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuItem(
                      context,
                      title: 'Statistics',
                      subtitle: 'View your games & performance',
                      icon: Icons.bar_chart,
                      iconColor: AppColors.secondary,
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.statistics);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuItem(
                      context,
                      title: 'Settings',
                      subtitle: 'Customize your experience',
                      icon: Icons.settings,
                      iconColor: AppColors.secondary,
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.settings);
                      },
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: "King's Gambit AI",
      applicationVersion: '1.0.0',
      applicationIcon: SizedBox(
        width: 48,
        height: 38,
        child: SvgPicture.asset('assets/images/branding/king_mark.svg'),
      ),
      children: [
        const Text(
          'A beautiful chess game with AI opponent powered by advanced algorithms.\n\n'
          'Features:\n'
          '• Play against AI with multiple difficulty levels\n'
          '• Beautiful themes and piece styles\n'
          '• Move hints and analysis\n'
          '• Game statistics tracking\n'
          '• Undo/Redo moves\n\n'
          'Developed with Flutter',
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.secondary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 40,
              height: 32,
              child: SvgPicture.asset('assets/images/branding/king_mark.svg'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'King\'s Gambit AI',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Challenge yourself!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: iconColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            icon: Icons.home,
            label: 'Home',
            isSelected: _selectedIndex == 0,
            onTap: () => setState(() => _selectedIndex = 0),
          ),
          _buildNavItem(
            context,
            icon: Icons.bar_chart,
            label: 'Statistics',
            isSelected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.of(context).pushNamed(AppRoutes.statistics);
            },
          ),
          _buildNavItem(
            context,
            icon: Icons.settings,
            label: 'Settings',
            isSelected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.of(context).pushNamed(AppRoutes.settings);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
