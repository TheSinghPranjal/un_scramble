import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models.dart';
import 'art_decor.dart';
import 'confetti.dart';

/// Win / out-of-lives / timeout dialog. Always reveals the target word.
Future<void> showResultDialog(
  BuildContext context, {
  required UnscrambleGameState state,
  required VoidCallback onNext,
  required VoidCallback onRetry,
  required VoidCallback onHome,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => PopScope(
      canPop: false,
      child: Stack(
        children: [
          if (state.status == GameStatus.won && !reduceMotion)
            const Positioned.fill(child: ConfettiBurst()),
          Center(
            child: _ResultCard(
              state: state,
              onNext: onNext,
              onRetry: onRetry,
              onHome: onHome,
            ),
          ),
        ],
      ),
    ),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
}

const _cardBackgroundAsset = 'assets/images/game_background.png';

/// Fixed palette: the card always sits on the light cloud art, so it does not
/// follow the app's dark theme.
abstract final class _Palette {
  static const ink = Color(0xFF1E1250);
  static const muted = Color(0xFF4B4466);
  static const accent = Color(0xFF4A2BC2);
  static const buttonTop = Color(0xFF6C47FF);
  static const buttonBottom = Color(0xFF4F2BD9);
  static const tileTop = Color(0xFF7B5CFA);
  static const tileBottom = Color(0xFF5433D6);
  static const tileLip = Color(0xFF3A1F9E);
  static const outline = Color(0xFF8B74E8);
  static const disabledFill = Color(0xFFEDEBF2);
  static const disabledBorder = Color(0xFFD9D6E0);
  static const disabledText = Color(0xFF9A96A6);
  static const starLight = Color(0xFFFFE36E);
  static const starDark = Color(0xFFFFB400);
  static const sparkle = Color(0xFF9A7BFF);
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.state,
    required this.onNext,
    required this.onRetry,
    required this.onHome,
  });

  final UnscrambleGameState state;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final won = state.status == GameStatus.won;

    final (
      _HeroKind hero,
      String title,
      String subtitle,
    ) = switch (state.status) {
      GameStatus.won => (_HeroKind.trophy, 'Brilliant!', 'You unscrambled it:'),
      GameStatus.lostTimeout => (
        _HeroKind.stopwatch,
        "Time's up!",
        'The word was:',
      ),
      _ => (_HeroKind.brokenHeart, 'Out of lives', 'The word was:'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A1670).withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  const Positioned.fill(child: _CardBackground()),
                  ..._decorStars(),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _HeroBadge(kind: hero)),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fredoka(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            color: _Palette.ink,
                          ),
                        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.3),
                        const SizedBox(height: 8),
                        _Subtitle(text: subtitle),
                        const SizedBox(height: 14),
                        _RevealedWord(word: state.targetWord),
                        const SizedBox(height: 24),
                        if (won) ...[
                          _WinStats(state: state),
                          const SizedBox(height: 20),
                          _PrimaryButton(
                            icon: Icons.arrow_forward_rounded,
                            label: 'Next word',
                            onPressed: onNext,
                          ),
                        ] else ...[
                          _PrimaryButton(
                            icon: Icons.replay_rounded,
                            label: 'Retry',
                            onPressed: onRetry,
                          ),
                          const SizedBox(height: 14),
                          _OutlineButton(
                            icon: Icons.skip_next_rounded,
                            label: 'Next word',
                            onPressed: onNext,
                          ),
                          const SizedBox(height: 14),
                          // TODO(monetization): rewarded ad → restore 1 life and resume.
                          const _ComingSoonButton(
                            icon: Icons.smart_display_rounded,
                            label: 'Extra life (Ad)',
                            caption: 'Coming soon',
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: onHome,
                          style: TextButton.styleFrom(
                            foregroundColor: _Palette.accent,
                            minimumSize: const Size.fromHeight(48),
                            textStyle: GoogleFonts.fredoka(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text('Home'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating stars scattered around the card edges, as in the mockup.
  static List<Widget> _decorStars() => [
    const Positioned(
      left: 26,
      top: 104,
      child: ArtStar(size: 46, turns: -0.04),
    ),
    const Positioned(
      right: 30,
      top: 128,
      child: ArtStar(size: 34, turns: 0.05),
    ),
    const Positioned(left: 12, top: 290, child: ArtStar(size: 42, turns: 0.03)),
    const Positioned(
      right: 26,
      bottom: 22,
      child: ArtStar(size: 36, turns: -0.06),
    ),
  ];
}

class _CardBackground extends StatelessWidget {
  const _CardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_cardBackgroundAsset, fit: BoxFit.cover),
        // Soft white glow behind the content keeps the text readable over
        // the clouds.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0.1),
              radius: 0.9,
              colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const sparkle = Icon(
      Icons.auto_awesome_rounded,
      size: 14,
      color: _Palette.sparkle,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        sparkle,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: _Palette.muted,
            ),
          ),
        ),
        const SizedBox(width: 6),
        sparkle,
      ],
    );
  }
}

enum _HeroKind { stopwatch, brokenHeart, trophy }

/// Glossy illustration at the top of the card with yellow burst rays.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.kind});

  final _HeroKind kind;

  @override
  Widget build(BuildContext context) {
    final art = switch (kind) {
      _HeroKind.stopwatch => const CustomPaint(
        size: Size.square(120),
        painter: _StopwatchPainter(),
      ),
      _HeroKind.brokenHeart => const _GlossyOrb(
        icon: Icons.heart_broken_rounded,
        top: Color(0xFFFF7A86),
        bottom: Color(0xFFC8243E),
      ),
      _HeroKind.trophy => const _GlossyOrb(
        icon: Icons.emoji_events_rounded,
        top: Color(0xFFFFD45C),
        bottom: Color(0xFFE08A00),
      ),
    };

    return ExcludeSemantics(
      child: SizedBox(
        width: 240,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: CustomPaint(painter: _RaysPainter())),
            art
                .animate()
                .scaleXY(begin: 0.4, duration: 600.ms, curve: Curves.elasticOut)
                .then()
                .shake(hz: 3, rotation: 0.04, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}

class _GlossyOrb extends StatelessWidget {
  const _GlossyOrb({
    required this.icon,
    required this.top,
    required this.bottom,
  });

  final IconData icon;
  final Color top;
  final Color bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.0,
          colors: [top, bottom],
        ),
        boxShadow: [
          BoxShadow(
            color: bottom.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 56, color: Colors.white),
    );
  }
}

/// Three short yellow strokes on each side of the hero art.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..shader = const LinearGradient(
        colors: [_Palette.starLight, _Palette.starDark],
      ).createShader(Offset.zero & size);
    final c = Offset(size.width / 2, size.height / 2 + 4);
    // Angles measured from the positive x axis, mirrored for the left side.
    const angles = [-0.75, -0.25, 0.25];
    const inner = 74.0;
    const outer = 94.0;
    for (final side in [1.0, -1.0]) {
      for (final a in angles) {
        final dir = Offset(math.cos(a) * side, math.sin(a));
        canvas.drawLine(c + dir * inner, c + dir * outer, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Red 3D-ish stopwatch with a white "off" slash through it.
class _StopwatchPainter extends CustomPainter {
  const _StopwatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.scale(s);
    final center = const Offset(60, 68);
    const radius = 44.0;

    // Crown stem + cap.
    final crown = Paint()..color = const Color(0xFFE2394F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 12, 12, 16),
        const Radius.circular(3),
      ),
      crown,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 4, 32, 12),
        const Radius.circular(6),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B7A), Color(0xFFD02A42)],
        ).createShader(const Rect.fromLTWH(44, 4, 32, 12)),
    );

    // Side button, tilted to the upper right.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6, -radius - 10, 12, 14),
        const Radius.circular(3),
      ),
      crown,
    );
    canvas.restore();

    // Drop shadow + body.
    canvas.drawCircle(
      center + const Offset(0, 6),
      radius,
      Paint()
        ..color = const Color(0xFF8E1328).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final bodyRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.0,
          colors: [Color(0xFFFF7A86), Color(0xFFC8243E)],
        ).createShader(bodyRect),
    );

    // Recessed face.
    final faceRect = Rect.fromCircle(center: center, radius: radius - 9);
    canvas.drawCircle(
      center,
      radius - 9,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.3, 0.4),
          radius: 1.0,
          colors: [Color(0xFFF0566A), Color(0xFFD13047)],
        ).createShader(faceRect),
    );

    // Tick dots.
    final tick = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 12; i += 3) {
      final a = i / 12 * 2 * math.pi;
      canvas.drawCircle(
        center + Offset(math.sin(a), -math.cos(a)) * (radius - 15),
        2.2,
        tick,
      );
    }

    // Hand.
    canvas.drawLine(
      center,
      center + const Offset(0, -20),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);

    // Gloss highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(-18, -24),
        width: 22,
        height: 12,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // "Off" slash with a soft shadow.
    const from = Offset(24, 26);
    const to = Offset(98, 108);
    canvas.drawLine(
      from + const Offset(2, 4),
      to + const Offset(2, 4),
      Paint()
        ..color = const Color(0xFF8E1328).withValues(alpha: 0.35)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0xFFFFE3E7)],
        ).createShader(Rect.fromPoints(from, to))
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RevealedWord extends StatelessWidget {
  const _RevealedWord({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final size = math.min(
          48.0,
          ((constraints.maxWidth - gap * (word.length - 1)) / word.length)
              .floorToDouble(),
        );
        return Semantics(
          label: 'The word was $word',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < word.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  _WordTile(char: word[i], size: size)
                      .animate(delay: (80 * i).ms)
                      .fadeIn(duration: 200.ms)
                      .slideY(begin: 0.5, curve: Curves.easeOutBack),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bright glossy purple tile used only in the result card.
class _WordTile extends StatelessWidget {
  const _WordTile({required this.char, required this.size});

  final String char;
  final double size;

  @override
  Widget build(BuildContext context) {
    final height = size * 1.1;
    return Container(
      width: size,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Palette.tileTop, _Palette.tileBottom],
        ),
        boxShadow: [
          const BoxShadow(color: _Palette.tileLip, offset: Offset(0, 4)),
          BoxShadow(
            color: _Palette.tileLip.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Text(
        char,
        style: GoogleFonts.fredoka(
          fontSize: height * 0.48,
          fontWeight: FontWeight.w700,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Palette.buttonTop, _Palette.buttonBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: _Palette.buttonBottom.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.fredoka(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 30),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _Palette.accent,
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: _Palette.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: GoogleFonts.fredoka(
          fontSize: 21,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ComingSoonButton extends StatelessWidget {
  const _ComingSoonButton({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$label, $caption',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _Palette.disabledFill.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _Palette.disabledBorder, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: _Palette.disabledText),
            const SizedBox(width: 14),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _Palette.disabledText,
                  ),
                ),
                Text(
                  caption,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: _Palette.disabledText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WinStats extends StatelessWidget {
  const _WinStats({required this.state});

  final UnscrambleGameState state;

  @override
  Widget build(BuildContext context) {
    final seconds = state.secondsRemaining;
    return Row(
      children: [
        _Stat(
          icon: Icons.timer_rounded,
          label: 'Time left',
          value:
              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
        ),
        _Stat(
          icon: Icons.favorite_rounded,
          label: 'Lives left',
          value: '${state.livesRemaining}/$kMaxLives',
        ),
        _Stat(
          icon: Icons.star_rounded,
          label: 'Points',
          value: '+${state.lastRoundScore}',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _Palette.accent),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _Palette.ink,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 12, color: _Palette.muted),
          ),
        ],
      ),
    );
  }
}
