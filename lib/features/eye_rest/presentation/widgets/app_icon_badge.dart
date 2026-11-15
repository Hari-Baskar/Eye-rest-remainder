import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/system_screen_time_service.dart';

/// AppIconBadge
///
/// Fetches and renders the real high-res Android application icon directly from
/// the OS PackageManager. If loading or unavailable, falls back to a categorized,
/// branded material icon.
class AppIconBadge extends StatefulWidget {
  final String packageName;
  final String appName;
  final double size;

  const AppIconBadge({
    super.key,
    required this.packageName,
    required this.appName,
    this.size = 15,
  });

  @override
  State<AppIconBadge> createState() => _AppIconBadgeState();
}

class _AppIconBadgeState extends State<AppIconBadge> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  @override
  void didUpdateWidget(AppIconBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _loadIcon();
    }
  }

  String get _effectivePackage {
    final lower = widget.appName.toLowerCase();
    final lowerPkg = widget.packageName.toLowerCase();

    // Check Gemini FIRST (so that even if package is com.google.android.googlequicksearchbox,
    // we query com.google.android.apps.bard to fetch the authentic Gemini icon!)
    if (lower.contains('gemini') ||
        lower.contains('bard') ||
        lowerPkg.contains('gemini') ||
        lowerPkg.contains('bard')) {
      return 'com.google.android.apps.bard';
    }

    if (widget.packageName.isNotEmpty) return widget.packageName;

    if (lower.contains('lifemint') || lower.contains('reset')) {
      return 'com.reset';
    }
    if (lower.contains('wellbeing') || lower.contains('digital wellbeing')) {
      return 'com.google.android.apps.wellbeing';
    }
    if (lower.contains('instagram')) return 'com.instagram.android';
    if (lower.contains('w4b') ||
        lower.contains('w\$b') ||
        (lower.contains('whatsapp') && lower.contains('business'))) {
      return 'com.whatsapp.w4b';
    }
    if (lower.contains('whatsapp')) return 'com.whatsapp';
    if (lower.contains('message') || lower.contains('messaging')) {
      return 'com.google.android.apps.messaging';
    }
    if (lower.contains('youtube') && lower.contains('music')) {
      return 'com.google.android.apps.youtube.music';
    }
    if (lower.contains('youtube')) return 'com.google.android.youtube';
    if (lower.contains('spotify')) return 'com.spotify.music';
    if (lower.contains('chrome')) return 'com.android.chrome';
    if (lower.contains('gmail')) return 'com.google.android.gm';
    if (lower.contains('telegram')) return 'org.telegram.messenger';
    if (lower.contains('netflix')) return 'com.netflix.mediaclient';
    return '';
  }

  void _loadIcon() async {
    final pkg = _effectivePackage;
    if (pkg.isEmpty ||
        pkg.contains('launcher') ||
        pkg.contains('systemui') ||
        pkg == 'android') {
      return;
    }
    final icon = await SystemScreenTimeService.getAppIcon(pkg);
    if (mounted && icon != null) {
      setState(() => _bytes = icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.22),
        child: Image.memory(
          _bytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        ),
      );
    }

    final lowerName = widget.appName.toLowerCase();
    final lowerPkg = widget.packageName.toLowerCase();

    final isGemini =
        lowerName.contains('gemini') ||
        lowerName.contains('bard') ||
        lowerPkg.contains('bard') ||
        lowerPkg.contains('gemini');

    if (isGemini) {
      return _buildGeminiIcon(widget.size);
    }

    final isWellbeing =
        lowerName.contains('wellbeing') || lowerPkg.contains('wellbeing');

    if (isWellbeing) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF00897B),
          borderRadius: BorderRadius.circular(widget.size * 0.22),
        ),
        child: Center(
          child: Icon(
            Icons.pie_chart_rounded,
            size: widget.size * 0.62,
            color: Colors.white,
          ),
        ),
      );
    }

    IconData fallbackIcon = Icons.apps_rounded;
    Color fallbackColor = AppColors.googleSlateLight;

    if (lowerName.contains('lifemint') ||
        lowerName.contains('reset') ||
        lowerPkg.contains('reset')) {
      fallbackIcon = Icons.spa_rounded;
      fallbackColor = AppColors.primary;
    } else if (lowerName.contains('home') ||
        lowerPkg.contains('launcher') ||
        lowerPkg.contains('systemui')) {
      fallbackIcon = Icons.home_rounded;
      fallbackColor = AppColors.googleGreenLight;
    } else if (lowerName.contains('youtube') || lowerPkg.contains('youtube')) {
      fallbackIcon = Icons.play_circle_fill_rounded;
      fallbackColor = AppColors.brandYouTube;
    } else if (lowerName.contains('whatsapp') ||
        lowerPkg.contains('whatsapp') ||
        lowerName.contains('w4b') ||
        lowerName.contains('w\$b') ||
        lowerPkg.contains('w4b')) {
      fallbackIcon = Icons.chat_bubble_rounded;
      fallbackColor = AppColors.brandWhatsApp;
    } else if (lowerName.contains('instagram') ||
        lowerPkg.contains('instagram')) {
      fallbackIcon = Icons.camera_alt_rounded;
      fallbackColor = AppColors.brandInstagram;
    } else if (lowerName.contains('message') ||
        lowerPkg.contains('messaging') ||
        lowerPkg.contains('message') ||
        lowerPkg.contains('mms') ||
        lowerPkg.contains('sms')) {
      fallbackIcon = Icons.message_rounded;
      fallbackColor = AppColors.googleBlueLight;
    } else if (lowerName.contains('chrome') ||
        lowerName.contains('browser') ||
        lowerPkg.contains('chrome') ||
        lowerName.contains('web')) {
      fallbackIcon = Icons.public_rounded;
      fallbackColor = AppColors.googleBlueLight;
    } else if (lowerName.contains('spotify') ||
        lowerName.contains('music') ||
        lowerPkg.contains('spotify')) {
      fallbackIcon = Icons.headphones_rounded;
      fallbackColor = AppColors.brandSpotify;
    } else if (lowerName.contains('gmail') ||
        lowerName.contains('mail') ||
        lowerPkg.contains('gmail') ||
        lowerPkg.contains('.gm')) {
      fallbackIcon = Icons.mail_rounded;
      fallbackColor = AppColors.brandGmail;
    } else if (lowerName.contains('telegram') ||
        lowerPkg.contains('telegram')) {
      fallbackIcon = Icons.send_rounded;
      fallbackColor = AppColors.brandTelegram;
    } else if (lowerName.contains('netflix') || lowerPkg.contains('netflix')) {
      fallbackIcon = Icons.movie_rounded;
      fallbackColor = AppColors.brandNetflix;
    } else if (lowerName.contains('facebook') ||
        lowerPkg.contains('facebook')) {
      fallbackIcon = Icons.facebook_rounded;
      fallbackColor = AppColors.brandFacebook;
    } else if (lowerName.contains('camera') || lowerPkg.contains('camera')) {
      fallbackIcon = Icons.photo_camera_rounded;
      fallbackColor = AppColors.googleBlueLight;
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(widget.size * 0.22),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: widget.size * 0.75,
          color: fallbackColor,
        ),
      ),
    );
  }

  /// Authentic Google Gemini Icon with 4-Pointed Curved Sparkle & Gradient
  Widget _buildGeminiIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: CustomPaint(
        size: Size(size * 0.68, size * 0.68),
        painter: _GeminiStarPainter(),
      ),
    );
  }
}

/// Draws the official Google Gemini 4-pointed curved star with authentic gradient
class _GeminiStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // 4-pointed Gemini star with smooth inward curves
    path.moveTo(w * 0.5, 0);
    path.cubicTo(w * 0.5, h * 0.35, w * 0.65, h * 0.5, w, h * 0.5);
    path.cubicTo(w * 0.65, h * 0.5, w * 0.5, h * 0.65, w * 0.5, h);
    path.cubicTo(w * 0.5, h * 0.65, w * 0.35, h * 0.5, 0, h * 0.5);
    path.cubicTo(w * 0.35, h * 0.5, w * 0.5, h * 0.35, w * 0.5, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.brandGeminiBlue,
          AppColors.brandGeminiPurple,
          AppColors.brandGeminiPink,
          AppColors.brandGeminiCyan,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
