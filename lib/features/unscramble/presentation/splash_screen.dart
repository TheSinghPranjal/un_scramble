import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/art_palette.dart';
import 'home_screen.dart';

/// Official Lazy Bear Club mark. Branding only — not the launcher icon.
const lazyBearClubIconAsset = 'assets/branding/lazy_bear_club.png';

/// How long the splash stays on screen before the home screen fades in.
const splashDuration = Duration(milliseconds: 1900);

/// Short branded splash shown over the stock native launch.
///
/// The name sits in the app's display face, with the studio byline — "by",
/// then "The Lazy Bear Club" and its icon — underneath. Colours follow
/// [GameColors] so the byline stays readable in light and dark themes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = splashDuration,
    this.next = const HomeScreen(),
  });

  final Duration duration;

  /// Screen opened when [duration] elapses. Defaults to the home screen.
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(widget.duration, _openNext);
    });
  }

  void _openNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => widget.next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GameColors.of(context);
    final dark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.backgroundBottom,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: const SafeArea(child: _SplashBody()),
        ),
      ),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = constraints.maxHeight < 520 ? 16.0 : 28.0;
        final minHeight = math.max(
          0.0,
          constraints.maxHeight - verticalPadding * 2,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: const Center(child: _SplashContent()),
          ),
        );
      },
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final tablet = shortest >= 600;
    final titleSize = tablet ? 72.0 : 48.0;
    final iconSize = tablet ? 92.0 : 76.0;

    final titleColor = dark ? const Color(0xFFF4EFFF) : ArtPalette.purpleDeep;
    final studioColor = dark ? const Color(0xFFF7F4FF) : ArtPalette.ink;
    final byColor = dark ? const Color(0xFFE7E0F6) : ArtPalette.muted;

    final titleStyle = (theme.textTheme.displaySmall ?? const TextStyle())
        .copyWith(
          color: titleColor,
          fontSize: titleSize,
          fontWeight: FontWeight.w700,
          height: 1.02,
          letterSpacing: -0.6,
        );
    final byStyle = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: byColor,
      fontSize: tablet ? 18 : 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      height: 1.2,
    );
    final studioStyle = (theme.textTheme.titleLarge ?? const TextStyle())
        .copyWith(
          color: studioColor,
          fontSize: tablet ? 28 : 22,
          fontWeight: FontWeight.w700,
          height: 1.15,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Unscramble',
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
            ),
          ),
          SizedBox(height: tablet ? 44 : 32),
          _StudioByline(
            iconSize: iconSize,
            byStyle: byStyle,
            studioStyle: studioStyle,
            dark: dark,
          ),
        ],
      ),
    );
  }
}

class _StudioByline extends StatelessWidget {
  const _StudioByline({
    required this.iconSize,
    required this.byStyle,
    required this.studioStyle,
    required this.dark,
  });

  final double iconSize;
  final TextStyle byStyle;
  final TextStyle studioStyle;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final radius = iconSize * 0.23;
    return Semantics(
      container: true,
      label: 'by The Lazy Bear Club',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.4 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Image.asset(
                  lazyBearClubIconAsset,
                  width: iconSize,
                  height: iconSize,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            SizedBox(height: iconSize < 84 ? 12 : 16),
            Text('by', textAlign: TextAlign.center, style: byStyle),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'The Lazy Bear Club',
                textAlign: TextAlign.center,
                style: studioStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
