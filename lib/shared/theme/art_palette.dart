import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Colours for content drawn over the painted cloud artwork. The artwork is
/// light in both modes, so these don't change with the system theme.
abstract final class ArtPalette {
  static const ink = Color(0xFF1C1446);
  static const muted = Color(0xFF6B6485);
  static const purple = Color(0xFF5B3FE6);
  static const purpleLight = Color(0xFF8B6DFF);
  static const purpleDeep = Color(0xFF3F27B8);
  static const lavender = Color(0xFFEFEAFF);
  static const lavenderDeep = Color(0xFFDCD3FB);
  static const tileLip = Color(0xFFC9BFF5);
  static const slotDash = Color(0xFF6F66A0);
  static const pink = Color(0xFFFFE8EE);
  static const heart = Color(0xFFF0305A);
  static const gold = Color(0xFFF5A623);
  static const goldLight = Color(0xFFFFD84D);
  static const divider = Color(0xFFE9E4F5);

  /// Screens over the artwork always use the light theme to stay readable.
  static final ThemeData theme = AppTheme.light();
}
