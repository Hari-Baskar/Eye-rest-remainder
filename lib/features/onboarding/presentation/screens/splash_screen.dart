import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// SplashScreen
///
/// Screen 1 in the LifeMint design suite.
/// Renders scenic mountain/lake landscape artwork, LifeMint brand typography,
/// and an animated loading progress bar before navigating to WelcomeScreen.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            // LifeMint Branding
            Text(
              AppStrings.appName,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 22.0,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              AppStrings.appTagline,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSizes.p24),
            // Scenic Vector Artwork
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
                child: ClipRRect(
                  borderRadius: AppSizes.borderRadiusLarge,
                  child: CustomPaint(
                    painter: ScenicLandscapePainter(isDark: isDark),
                    child: Container(),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),
            // Bottom Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p48),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: AppSizes.borderRadiusPill,
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          minHeight: 4.0,
                          backgroundColor: isDark ? AppColors.darkSurfaceSecondary : AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSizes.p16),
                  Text(
                    AppStrings.splashSubtext,
                    style: AppTextStyles.small.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p24),
          ],
        ),
      ),
    );
  }
}

/// ScenicLandscapePainter
///
/// Draws layered vector illustration of sun, mountain peaks, pine trees, and serene lake.
class ScenicLandscapePainter extends CustomPainter {
  final bool isDark;

  ScenicLandscapePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky Background
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
            : [const Color(0xFFE0F2FE), const Color(0xFFFEF3C7)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.65), skyPaint);

    // Sunrise Sun
    final sunPaint = Paint()
      ..color = isDark ? const Color(0xFFFDE68A).withValues(alpha: 0.8) : const Color(0xFFFBBF24);
    canvas.drawCircle(Offset(w * 0.5, h * 0.38), 34, sunPaint);

    // Distant Mountain
    final distantMountain = Path()
      ..moveTo(0, h * 0.48)
      ..lineTo(w * 0.3, h * 0.28)
      ..lineTo(w * 0.6, h * 0.44)
      ..lineTo(w, h * 0.32)
      ..lineTo(w, h * 0.65)
      ..lineTo(0, h * 0.65)
      ..close();
    final distantPaint = Paint()
      ..color = isDark ? const Color(0xFF1E3A5F) : const Color(0xFF99F6E4);
    canvas.drawPath(distantMountain, distantPaint);

    // Midground Mountain
    final midMountain = Path()
      ..moveTo(0, h * 0.52)
      ..lineTo(w * 0.5, h * 0.34)
      ..lineTo(w, h * 0.50)
      ..lineTo(w, h * 0.65)
      ..lineTo(0, h * 0.65)
      ..close();
    final midPaint = Paint()
      ..color = isDark ? const Color(0xFF0F766E) : const Color(0xFF2DD4BF);
    canvas.drawPath(midMountain, midPaint);

    // Lake Water
    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF0C4A6E), const Color(0xFF082F49)]
            : [const Color(0xFF0E7490), const Color(0xFF155E75)],
      ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w, h * 0.35), waterPaint);

    // Pine Trees Foreground (Left & Right)
    _drawPineTree(canvas, Offset(w * 0.1, h * 0.62), 38, isDark);
    _drawPineTree(canvas, Offset(w * 0.18, h * 0.65), 28, isDark);
    _drawPineTree(canvas, Offset(w * 0.88, h * 0.60), 44, isDark);
    _drawPineTree(canvas, Offset(w * 0.80, h * 0.66), 30, isDark);
  }

  void _drawPineTree(Canvas canvas, Offset bottomCenter, double height, bool isDark) {
    final treePaint = Paint()
      ..color = isDark ? const Color(0xFF064E3B) : const Color(0xFF065F46);
    final path = Path()
      ..moveTo(bottomCenter.dx, bottomCenter.dy - height)
      ..lineTo(bottomCenter.dx - height * 0.35, bottomCenter.dy)
      ..lineTo(bottomCenter.dx + height * 0.35, bottomCenter.dy)
      ..close();
    canvas.drawPath(path, treePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
