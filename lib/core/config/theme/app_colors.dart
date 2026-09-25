import 'package:flutter/material.dart';

/// Single source of truth for color in the app: flat, modern, blue-only,
/// professional B2B palette. No gradients anywhere - "elevated" surfaces
/// use a thin 1px border (see [border]) instead of a drop shadow.
///
/// Every widget in the app should reference one of these tokens instead of
/// a one-off hex value, so a future palette tweak only has to happen here.
class AppColors {
  AppColors._();

  // Brand navy - the deep blue already used across the app (product
  // titles, section headers, the old FAB, ...). Kept as-is: this is a
  // consistency cleanup, not a rebrand. Used for text/icons on light
  // surfaces and as the background of "solid" dark elements (AppBar
  // icons, primary buttons, the notification card).
  static const primary = Color(0xFF14304A);
  static const primaryDark = Color(0xFF0C2233);

  // Flat "action" blue - one shade brighter than the navy, used for
  // interactive accents (active tab indicator, links, focus ring) so
  // tappable things read clearly without introducing a second hue.
  static const accent = Color(0xFF2E63E7);
  static const accentLight = Color(0xFFEBF1FE); // pale tint: pills, chips, banners, FAB bg

  // Neutral surfaces - flat, no gradients, no heavy shadows.
  static const background = Colors.white;
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF5F7FA); // subtle secondary surface (shimmer, inputs)
  static const border = Color(0xFFE2E7F0);
  static const divider = Color(0xFFEDF1F6);

  // Text.
  static const textPrimary = Color(0xFF17233A);
  static const textSecondary = Color(0xFF667085);
  static const textOnPrimary = Colors.white;

  // Status - used sparingly, only where a color genuinely signals state.
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFCEBEB);
  static const success = Color(0xFF16803C);
  static const successBg = Color(0xFFE9F8EE);
}
