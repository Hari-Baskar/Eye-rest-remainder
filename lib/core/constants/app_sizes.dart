import 'package:flutter/material.dart';

/// AppSizes
///
/// Centralized dimensions, paddings, border radiuses, icon sizes, and component heights
/// used throughout the application to maintain uniform UI rhythm and avoid hardcoding.
abstract class AppSizes {
  // Spacing & Padding
  static const double p4 = 4.0;
  static const double p6 = 6.0;
  static const double p8 = 8.0;
  static const double p10 = 10.0;
  static const double p12 = 12.0;
  static const double p14 = 14.0;
  static const double p16 = 16.0;
  static const double p18 = 18.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p28 = 28.0;
  static const double p32 = 32.0;
  static const double p40 = 40.0;
  static const double p48 = 48.0;
  static const double p64 = 64.0;

  // Insets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: p20, vertical: p16);
  static const EdgeInsets cardPadding = EdgeInsets.all(p20);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(p14);
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(horizontal: p10, vertical: p4);

  // Border Radiuses
  static const double r8 = 8.0;
  static const double r10 = 10.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r18 = 18.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r30 = 30.0;

  static final BorderRadius borderRadiusSmall = BorderRadius.circular(r8);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(r8);
  static final BorderRadius borderRadiusCard = BorderRadius.circular(r8);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(r10);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(r30);

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconExtraLarge = 32.0;

  // Component Dimensions
  static const double buttonHeight = 52.0;
  static const double compactButtonHeight = 38.0;
  static const double indicatorHeight = 10.0;
  static const double statusDotSize = 10.0;
  static const double cardBorderWidth = 1.2;
}
