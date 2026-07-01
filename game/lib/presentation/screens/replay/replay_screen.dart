import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';

class ReplayScreen extends StatelessWidget {
  const ReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.replay),
      ),
      body: const Center(
        child: Text('Replay Screen - Coming soon'),
      ),
    );
  }
}
