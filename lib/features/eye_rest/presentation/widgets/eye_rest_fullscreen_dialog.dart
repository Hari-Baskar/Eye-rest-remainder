import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';

/// EyeRestFullScreenDialog
///
/// Full-Screen 20-Second Eye Rest Takeover experience.
/// Presents a calming, optometry-guided 20-20-20 countdown timer, relaxing breathing rhythm,
/// and instant break completion for both live triggered breaks and interactive user demos.
class EyeRestFullScreenDialog extends StatefulWidget {
  final bool isDemo;
  final VoidCallback? onComplete;

  const EyeRestFullScreenDialog({
    super.key,
    this.isDemo = false,
    this.onComplete,
  });

  static Future<void> show(
    BuildContext context, {
    bool isDemo = false,
    VoidCallback? onComplete,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, anim1, anim2) {
          return EyeRestFullScreenDialog(
            isDemo: isDemo,
            onComplete: onComplete,
          );
        },
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );
  }

  @override
  State<EyeRestFullScreenDialog> createState() => _EyeRestFullScreenDialogState();
}

class _EyeRestFullScreenDialogState extends State<EyeRestFullScreenDialog> {
  int _secondsRemaining = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        t.cancel();
        _onFinishBreak();
      }
    });
  }

  void _onFinishBreak() {
    widget.onComplete?.call();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (20 - _secondsRemaining) / 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.96),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Bar with Demo Badge & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.isDemo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(AppSizes.r8),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.40),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_rounded, size: 13, color: AppColors.primaryLight),
                          const SizedBox(width: 4),
                          Text(
                            'Demo Preview',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Calming Pulsing Icon
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.remove_red_eye_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),

              const SizedBox(height: AppSizes.p20),

              // Title & Subtitle
              Text(
                'Take a 20-Second Eye Break',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Look at something at least 20 feet (6 meters) away to completely relax your eye ciliary muscles.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.45,
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Circular Countdown Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'seconds left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Complete Break Button
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _onFinishBreak,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'I Took My Break',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p8),

              // Dismiss Text Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
            ],
          ),
        ),
      ),
    );
  }
}

