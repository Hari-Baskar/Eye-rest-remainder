import 'package:flutter/material.dart';

/// AppColors
///
/// Complete color design tokens for the Reset application.
/// 
/// Central design token repository for the LifeMint application.
/// Defines curated light and dark mode colors, wellness pillar colors,
/// progress ring colors, and semantic UI accents.
abstract class AppColors {
  // Brand Primary (LifeMint)
  static const Color primary = Color(0xFF0F5132); // Deep forest mint
  static const Color primaryLight = Color(0xFF10B981); // Vibrant mint green
  static const Color primaryDark = Color(0xFF064E3B);
  static const Color mintAccent = Color(0xFFD1FAE5); // Soft mint chip
  static const Color mintDarkBg = Color(0xFF062D1F);

  // Pillar 1: Water (Cyan / Sky Blue)
  static const Color waterPrimary = Color(0xFF0EA5E9);
  static const Color waterLight = Color(0xFF38BDF8);
  static const Color waterSecondary = Color(0xFF38BDF8);
  static const Color waterBackground = Color(0xFFE0F2FE);
  static const Color waterDarkBg = Color(0xFF082F49);

  // Pillar 2: Sunlight (Golden Amber / Warm Orange)
  static const Color sunlightPrimary = Color(0xFFF59E0B);
  static const Color sunlightLight = Color(0xFFFBBF24);
  static const Color sunlightSecondary = Color(0xFFFBBF24);
  static const Color sunlightBackground = Color(0xFFFEF3C7);
  static const Color sunlightDarkBg = Color(0xFF451A03);

  // Pillar 3: Eye Rest (Restful Forest Mint - Optometry Eye Wellness)
  static const Color eyePrimary = Color(0xFF0F5132); // Deep forest mint
  static const Color eyeLight = Color(0xFF10B981); // Soothing vibrant mint
  static const Color eyeSecondary = Color(0xFF10B981);
  static const Color eyeBackground = Color(0xFFD1FAE5); // Soft calming mint tint
  static const Color eyeDarkBg = Color(0xFF062D1F); // Deep forest tint

  // Pillar 4: Movement / Steps (Emerald Green)
  static const Color movementPrimary = Color(0xFF10B981);
  static const Color movementLight = Color(0xFF34D399);
  static const Color movementSecondary = Color(0xFF34D399);
  static const Color movementBackground = Color(0xFFD1FAE5);
  static const Color movementDarkBg = Color(0xFF064E3B);
  static const Color inactive = Color(0xFF94A3B8);

  // Neutral Backgrounds - Light Mode
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  
  // Neutral Backgrounds - Dark Mode (matching expense_tracker design)
  static const Color darkBackground = Color(0xFF1E1E1E); // Reduced black / warm neutral dark charcoal
  static const Color darkCardSurface = Color(0xFF2E2E2E); // 10% lighter surface grey for cards
  static const Color darkCardBackground = Color(0xFF2E2E2E); // Semantic alias for dark card surface
  static const Color darkSurface = Color(0xFF2E2E2E);
  static const Color darkSurfaceSecondary = Color(0xFF343434); // Deep nested surface
  static const Color darkBorder = Color(0xFF3C3C3C); // Raised elements & borders

  // Typography Colors - Light Mode
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Typography Colors - Dark Mode (matching expense_tracker design)
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // High contrast white
  static const Color darkTextSecondary = Color(0xFFA8A8A8); // Instagram's muted grey text
  static const Color darkTextTertiary = Color(0xFF757575); // Subtle caption grey

  // Semantic & Alerts
  static const Color success = Color(0xFF10B981);
  static const Color alert = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color inCallMuted = Color(0xFF64748B);
  static const Color strainRed = Color(0xFFF87171);
  static const Color strainRedLight = Color(0xFFFCA5A5);
  static const Color strainRedDark = Color(0xFFDC2626);

  // Rhythm & Storyboard Palette (Google Fit & Material 3 Inspired)
  static const Color googleGreenLight = Color(0xFF1E8E3E);
  static const Color googleGreenDark = Color(0xFF81C995);
  static const Color googleSlateLight = Color(0xFF5F6368);
  static const Color googleSlateDark = Color(0xFF9AA0A6);
  static const Color googleBlueLight = Color(0xFF1A73E8);
  static const Color googleBlueDark = Color(0xFF8AB4F8);
  static const Color marathonAmberLight = Color(0xFFF59E0B);
  static const Color marathonAmberDark = Color(0xFFFBBF24);
  static const Color trackBgLight = Color(0xFFE8EAED);
  static const Color trackBgDark = Color(0xFF3C4043);

  // High-Contrast Dark & Neutral Surfaces
  static const Color pitchDarkBackground = Color(0xFF121212); // AMOLED / Pure Dark
  static const Color darkCapsuleBoard = Color(0xFF0F141C); // Storyboard board container dark
  static const Color darkCapsuleGlass = Color(0xFF070B11); // Storyboard glass chip dark
  static const Color lightCapsuleGlass = Color(0xFFE9EEF4); // Storyboard glass chip light
  static const Color lightCapsuleBorder = Color(0xFFCBD5E1); // Storyboard glass chip border light
  static const Color lightCapsuleFuture = Color(0xFFF1F5F9); // Storyboard future glass chip light
  static const Color lightCapsuleFutureBorder = Color(0xFFE2E8F0); // Storyboard future border light
  static const Color lightNodeBorder = Color(0xFFE0E0E0); // Timeline step border light
  static const Color textCharcoal = Color(0xFF1F1F1F); // Clean high-contrast text
  static const Color textSlateNavy = Color(0xFF1E293B); // Slate-navy text for app chip labels

  // Gentle Eye Reminder Banner Theme
  static const Color gentleBannerBgDark = Color(0xFF1E2822);
  static const Color gentleBannerBgLight = Color(0xFFF0FDF4);
  static const Color gentleBannerBorderDark = Color(0xFF2D4A3A);
  static const Color gentleBannerBorderLight = Color(0xFFBBF7D0);
  static const Color gentleBannerMintDark = Color(0xFF6EE7B7);
  static const Color gentleBannerMintLight = Color(0xFF10B981);
  static const Color gentleBannerTextDark = Color(0xFFF1F5F9);
  static const Color gentleBannerTextLight = Color(0xFF0F172A);
  static const Color gentleBannerSubtitleDark = Color(0xFF94A3B8);
  static const Color gentleBannerSubtitleLight = Color(0xFF475569);

  // Third-Party Brand Icons Fallback Palette
  static const Color brandYouTube = Color(0xFFFF0000);
  static const Color brandWhatsApp = Color(0xFF25D366);
  static const Color brandInstagram = Color(0xFFE4405F);
  static const Color brandSpotify = Color(0xFF1DB954);
  static const Color brandGmail = Color(0xFFEA4335);
  static const Color brandTelegram = Color(0xFF229ED9);
  static const Color brandNetflix = Color(0xFFE50914);
  static const Color brandFacebook = Color(0xFF1877F2);
  static const Color brandGeminiBlue = Color(0xFF1B68F8);
  static const Color brandGeminiPurple = Color(0xFF7A47F2);
  static const Color brandGeminiPink = Color(0xFFE84281);
  static const Color brandGeminiCyan = Color(0xFF5582FF);

  // Dynamic Theme Helpers for Rhythm Colors
  static Color getRhythmGreen(bool isDark) =>
      isDark ? googleGreenDark : googleGreenLight;
  static Color getRhythmSlate(bool isDark) =>
      isDark ? googleSlateDark : googleSlateLight;
  static Color getRhythmBlue(bool isDark) =>
      isDark ? googleBlueDark : googleBlueLight;
  static Color getRhythmAmber(bool isDark) =>
      isDark ? marathonAmberDark : marathonAmberLight;

  // Scenic Vector Colors (Splash Screen)
  static const Color mountainDark = Color(0xFF064E3B);
  static const Color mountainMid = Color(0xFF0F766E);
  static const Color mountainLight = Color(0xFF2DD4BF);
  static const Color sunriseGlow = Color(0xFFFEF08A);
  static const Color lakeWater = Color(0xFF0E7490);

  // Adaptive Helpers (matching expense_tracker design language)
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getBackground(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color getSurface(BuildContext context) =>
      isDark(context) ? darkCardSurface : cardSurface;

  static Color getSurfaceContainerLowest(BuildContext context) =>
      isDark(context) ? darkSurfaceSecondary : const Color(0xFFF5F5F5);

  static Color getText(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color getTextMuted(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color getDivider(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.08);

  static Color getBorder(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.08);

  static BoxBorder? getCardBorder(BuildContext context) =>
      isDark(context)
          ? null
          : Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.0);

  static Color getCardSurface(BuildContext context) =>
      isDark(context) ? darkCardSurface : cardSurface;
}
