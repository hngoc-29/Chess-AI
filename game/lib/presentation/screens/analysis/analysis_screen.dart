import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.analysis),
      ),
      body: const Center(
        child: Text('Analysis Screen - Coming soon'),
      ),
    );
  }
}
