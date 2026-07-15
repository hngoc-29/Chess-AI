import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/online/auth_bloc.dart';
import '../../../services/online/backend_auth_service.dart';
import '../../../core/constants/colors.dart';
import '../../app/routes.dart';

/// The app's entry-point auth gate: Google / Facebook / Guest, no email
/// form up front (email is a "use email instead" fallback link - see
/// _showEmailForm below). Reached right after splash when there's no
/// existing session (see SplashScreen), not only when entering online
/// mode specifically - a guest identity works for offline play too.
class OnlineAuthScreen extends StatefulWidget {
  const OnlineAuthScreen({super.key});

  @override
  State<OnlineAuthScreen> createState() => _OnlineAuthScreenState();
}

class _OnlineAuthScreenState extends State<OnlineAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _showEmailForm = false;

  @override
  void initState() {
    super.initState();
    // AuthBloc lives above this screen and CheckAuthStatus already ran at
    // app startup, so a returning user may reach this screen already
    // authenticated. BlocConsumer's listener only fires on *changes*, not
    // on the state that was already active before this widget mounted -
    // without this check, an already-signed-in user would be stuck here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthBloc>().state is AuthAuthenticated) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.mainMenu);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp) {
      context.read<AuthBloc>().add(SignUpRequested(
            email: email,
            password: password,
            displayName: _displayNameController.text.trim(),
          ));
    } else {
      context.read<AuthBloc>().add(SignInRequested(email: email, password: password));
    }
  }

  Future<void> _showConflictDialog(BuildContext context, OAuthConflict conflict) async {
    final keepLocal = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF232342),
        title: Text(
          'Account already exists',
          style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This ${conflict.provider == 'google' ? 'Google' : 'Facebook'} account is already linked '
          'to "${conflict.existingDisplayName}" (Elo ${conflict.existingElo}).\n\n'
          'Keep this device\'s data, or switch to that account?',
          style: GoogleFonts.roboto(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Use "${conflict.existingDisplayName}"', style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Keep this device\'s data'),
          ),
        ],
      ),
    );

    if (keepLocal != null && context.mounted) {
      context.read<AuthBloc>().add(OAuthConflictResolved(conflict: conflict, keepLocal: keepLocal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.mainMenu);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          } else if (state is AuthOAuthConflict) {
            _showConflictDialog(context, state.conflict);
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
                    const Icon(Icons.sports_esports, size: 72, color: Colors.amber),
                    const SizedBox(height: 16),
                    Text(
                      'King\'s Gambit',
                      style: GoogleFonts.cinzel(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to play',
                      style: GoogleFonts.roboto(fontSize: 16, color: Colors.white70, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 40),
                    if (!_showEmailForm) ...[
                      _ProviderButton(
                        label: 'Continue with Google',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F1F1F),
                        leading: _GoogleGlyph(),
                        isLoading: isLoading,
                        onPressed: () => context.read<AuthBloc>().add(const GoogleSignInRequested()),
                      ),
                      const SizedBox(height: 12),
                      _ProviderButton(
                        label: 'Continue with Facebook',
                        backgroundColor: const Color(0xFF1877F2),
                        foregroundColor: Colors.white,
                        leading: const Icon(Icons.facebook, color: Colors.white, size: 22),
                        isLoading: isLoading,
                        onPressed: () => context.read<AuthBloc>().add(const FacebookSignInRequested()),
                      ),
                      const SizedBox(height: 12),
                      _ProviderButton(
                        label: 'Continue as Guest',
                        backgroundColor: Colors.white.withOpacity(0.08),
                        foregroundColor: Colors.white,
                        leading: const Icon(Icons.person_outline, color: Colors.white, size: 22),
                        isLoading: isLoading,
                        onPressed: () => context.read<AuthBloc>().add(const GuestSignInRequested()),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: isLoading ? null : () => setState(() => _showEmailForm = true),
                        child: Text('Use email instead',
                            style: GoogleFonts.roboto(color: Colors.white54, fontSize: 13)),
                      ),
                    ] else ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_isSignUp) ...[
                              _AuthTextField(
                                controller: _displayNameController,
                                label: 'Display name',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (!_isSignUp) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter a display name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            _AuthTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Enter your email';
                                if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.white54,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter your password';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submitEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                      )
                                    : Text(
                                        _isSignUp ? 'Create account' : 'Sign in',
                                        style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: isLoading ? null : () => setState(() => _isSignUp = !_isSignUp),
                              child: Text(
                                _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Create one",
                                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : () => setState(() => _showEmailForm = false),
                              child: Text('\u2190 Back',
                                  style: GoogleFonts.roboto(color: Colors.white38, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
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
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget leading;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ProviderButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.leading,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A plain "G" glyph rather than Google's actual multi-color logo asset,
/// which this project doesn't have a license to bundle. Swap in the real
/// branded asset if/when available - Google's brand guidelines require it
/// for a production "Sign in with Google" button.
class _GoogleGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4285F4)),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?) validator;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.2),
        ),
      ),
    );
  }
}
