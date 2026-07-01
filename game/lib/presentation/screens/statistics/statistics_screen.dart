import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.statistics),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
            title: 'Total Games',
            value: '0',
            icon: Icons.gamepad,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _StatCard(
            title: 'Wins',
            value: '0',
            icon: Icons.emoji_events,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _StatCard(
            title: 'Losses',
            value: '0',
            icon: Icons.close,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          _StatCard(
            title: 'Draws',
            value: '0',
            icon: Icons.remove,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
