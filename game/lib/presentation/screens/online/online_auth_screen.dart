import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/online/auth_bloc.dart';
import '../../../core/constants/colors.dart';

class OnlineAuthScreen extends StatelessWidget {
  const OnlineAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushReplacementNamed('/online-matchmaking');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Icon(
                      Icons.sports_esports,
                      size: 80,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'King\'s Gambit',
                      style: GoogleFonts.cinzel(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Online Multiplayer',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Sign in with Google button
                    _buildOAuthButton(
                      context,
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      color: Colors.white,
                      textColor: Colors.black87,
                      isLoading: isLoading,
                      onPressed: () {
                        context.read<AuthBloc>().add(const GoogleSignInRequested());
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sign in with Facebook button
                    _buildOAuthButton(
                      context,
                      label: 'Continue with Facebook',
                      icon: Icons.facebook,
                      color: const Color(0xFF1877F2),
                      textColor: Colors.white,
                      isLoading: isLoading,
                      onPressed: () {
                        context.read<AuthBloc>().add(const FacebookSignInRequested());
                      },
                    ),
                    const SizedBox(height: 48),

                    // Terms text
                    Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOAuthButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon, size: 28, color: textColor),
        label: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          disabledBackgroundColor: color.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}
