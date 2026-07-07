import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which themed animation to show on a given onboarding page.
enum OnboardingIllustrationType { welcome, thinking, analysis }

/// A small, fully self-contained animated illustration for the onboarding
/// flow. Built entirely from the app's own chess piece art plus a bit of
/// custom animation code - no Lottie files, no external/network images,
/// so there's nothing that can silently fail to render.
class OnboardingIllustration extends StatefulWidget {
  final OnboardingIllustrationType type;

  const OnboardingIllustration({super.key, required this.type});

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _pieceBase = 'assets/images/pieces/cburnett';

  @override
  void initState() {
    super.initState();
    final duration = switch (widget.type) {
      OnboardingIllustrationType.welcome => const Duration(milliseconds: 2200),
      OnboardingIllustrationType.thinking => const Duration(milliseconds: 1300),
      OnboardingIllustrationType.analysis => const Duration(milliseconds: 2000),
    };
    _controller = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: widget.type != OnboardingIllustrationType.thinking);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return switch (widget.type) {
          OnboardingIllustrationType.welcome => _buildWelcome(context, t),
          OnboardingIllustrationType.thinking => _buildThinking(context, t),
          OnboardingIllustrationType.analysis => _buildAnalysis(context, t),
        };
      },
    );
  }

  // A king with a soft breathing glow behind it - a calm, confident "hello".
  Widget _buildWelcome(BuildContext context, double t) {
    final primary = Theme.of(context).colorScheme.primary;
    final glowScale = 1.0 + t * 0.35;
    final glowOpacity = 0.10 + (1.0 - t) * 0.35;

    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: glowScale,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: glowOpacity),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.96 + t * 0.04,
              child: SizedBox(
                width: 140,
                height: 140,
                child: SvgPicture.asset('$_pieceBase/wK.svg'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A knight gently rocking side to side "considering" its options, with a
  // row of sequential pulsing dots underneath (a classic "thinking" tell).
  Widget _buildThinking(BuildContext context, double t) {
    final primary = Theme.of(context).colorScheme.primary;
    final angle = math.sin(t * 2 * math.pi) * 0.09;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: 130,
              height: 130,
              child: SvgPicture.asset('$_pieceBase/wN.svg'),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (t - i * 0.18) % 1.0;
              final bump = math.sin(phase * math.pi).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Transform.translate(
                  offset: Offset(0, -10 * bump),
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.35 + 0.65 * bump),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // A queen with a highlighted scan-line sweeping over it, evoking the
  // engine "reading" the board during analysis.
  Widget _buildAnalysis(BuildContext context, double t) {
    final primary = Theme.of(context).colorScheme.primary;
    const boardSize = 150.0;

    return Center(
      child: SizedBox(
        width: boardSize,
        height: boardSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: SvgPicture.asset('$_pieceBase/wQ.svg'),
              ),
              Positioned(
                top: boardSize * t - 2,
                child: Container(
                  width: boardSize,
                  height: 3,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
