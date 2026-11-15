import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTextStyles
///
/// Clean, unified 4-tier typography system for the LifeMint application using Poppins.
abstract class AppTextStyles {
  /// 1. Heading - ONLY AppBars and Primary Screen Titles
  static TextStyle heading = GoogleFonts.poppins(
    fontSize: 17.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// 2. Subheading - Card headers, section titles, modal titles (toned down to w500)
  static TextStyle subheading = GoogleFonts.poppins(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  /// 3. Body - Standard reading content, common text, list items
  static TextStyle body = GoogleFonts.poppins(
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// 4. Small - Captions, unit labels, secondary badges, timestamps (toned down to w300 light)
  static TextStyle small = GoogleFonts.poppins(
    fontSize: 11.0,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.1,
  );
}
