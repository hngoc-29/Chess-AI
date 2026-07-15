import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/strings.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/online/user_profile.dart';
import '../../blocs/online/auth_bloc.dart';
import '../../app/routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is! AuthAuthenticated) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () => _confirmSignOut(context),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onlineAuth, (route) => false);
          }
        },
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = state.profile;
          return RefreshIndicator(
            onRefresh: () async => context.read<AuthBloc>().add(const ProfileLoadRequested()),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.isStale)
                  _InfoBanner(
                    icon: Icons.cloud_off,
                    text: 'Offline - showing your last saved data',
                    color: AppColors.warning,
                  ),
                if (state.pendingSyncCount > 0)
                  _InfoBanner(
                    icon: Icons.sync,
                    text: '${state.pendingSyncCount} change waiting to sync',
                    color: AppColors.info,
                  ),
                const SizedBox(height: 12),
                Center(
                  child: _Avatar(
                    avatarUrl: profile?.avatarUrl,
                    displayName: profile?.displayName ?? '?',
                    radius: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile?.displayName ?? '...',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditNameDialog(context, profile?.displayName ?? ''),
                      ),
                    ],
                  ),
                ),
                if (profile != null)
                  Center(
                    child: Text(
                      _providerLabel(profile.authProvider),
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ),
                const SizedBox(height: 24),
                if (state.isLocalOnlyGuest) _LinkAccountCard(),
                if (state.isLocalOnlyGuest) const SizedBox(height: 24),
                if (profile != null) _StatsGrid(profile: profile),
              ],
            ),
          );
        },
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Signed in with Google';
      case 'facebook':
        return 'Signed in with Facebook';
      case 'guest':
        return 'Playing as guest';
      default:
        return 'Signed in with email';
    }
  }

  void _showEditNameDialog(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != current) {
                context.read<AuthBloc>().add(ProfileUpdateRequested(displayName: newName));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(const SignOutRequested());
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;

  const _Avatar({required this.avatarUrl, required this.displayName, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.cardDark,
        backgroundImage: NetworkImage(avatarUrl!),
        // No visible fallback child needed - NetworkImage failures just
        // leave the background color showing, which is an acceptable
        // degrade rather than a broken-image icon.
      );
    }
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

class _LinkAccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Playing as guest', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your progress only lives on this device. Sign in to keep it safe and play online.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.read<AuthBloc>().add(const GoogleSignInRequested()),
                  child: const Text('Google'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.read<AuthBloc>().add(const FacebookSignInRequested()),
                  child: const Text('Facebook'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final OnlineUserProfile profile;

  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final winRatePct = (profile.winRate * 100).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Elo', value: '${profile.elo}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Games', value: '${profile.gamesPlayed}')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Win rate', value: '$winRatePct%')),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(label: 'W / D / L', value: '${profile.gamesWon}/${profile.gamesDrawn}/${profile.gamesLost}'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }
}
