import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {},
            tooltip: AppStrings.undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () {},
            tooltip: AppStrings.redo,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () {},
            tooltip: AppStrings.flipBoard,
          ),
        ],
      ),
      body: const Center(
        child: Text('Game Screen - Board will be rendered here'),
      ),
    );
  }
}
