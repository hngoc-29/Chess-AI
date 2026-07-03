import 'package:flutter/material.dart';

import '../../../core/config/injection.dart';
import '../../../core/constants/strings.dart';
import '../../../domain/repositories/i_stats_repository.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.statistics),
      ),
      body: FutureBuilder(
        future: getIt<IStatsRepository>().getStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final stats = snapshot.data?.fold(
            (failure) => null,
            (stats) => stats,
          );
          
          final totalGames = stats?.totalGames ?? 0;
          final wins = stats?.wins ?? 0;
          final losses = stats?.losses ?? 0;
          final draws = stats?.draws ?? 0;
          final winRate = totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0.0';
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                title: 'Tổng số trận',
                value: '$totalGames',
                icon: Icons.gamepad,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'Thắng',
                value: '$wins',
                subtitle: 'Tỷ lệ thắng: $winRate%',
                icon: Icons.emoji_events,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'Thua',
                value: '$losses',
                icon: Icons.close,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'Hòa',
                value: '$draws',
                icon: Icons.remove,
                color: Colors.orange,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
