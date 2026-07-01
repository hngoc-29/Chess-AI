import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
      ),
      body: const Center(
        child: Text('Profile Screen - Coming soon'),
      ),
    );
  }
}
