import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';

/// FeedbackScreen
///
/// Send Feedback screen matching expense_tracker's FeedbackScreen design.
/// Allows users to submit bugs, feature ideas, and wellness feedback.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType = 'General Feedback';
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  final List<String> _feedbackTypes = [
    'General Feedback',
    'Bug / Issue Report',
    'Feature Suggestion',
    'Sensor / Tracking Accuracy',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you! Your feedback has been received.'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.primaryLight
              : AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      _descriptionController.clear();
      _emailController.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send Feedback',
          style: AppTextStyles.subheading.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We would love to hear from you',
                  style: AppTextStyles.subheading.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Have a bug to report or an idea to improve your posture & eye rest habits? Let us know below.',
                  style: AppTextStyles.small.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSizes.p24),

                // Feedback Type Selector
                Text(
                  'Feedback Type',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(AppSizes.r8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      dropdownColor: AppColors.getSurface(context),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      items: _feedbackTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: AppTextStyles.body.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p20),

                // Description Input
                Text(
                  'Description',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your feedback';
                    }
                    if (val.trim().length < 6) {
                      return 'Please provide a little more detail';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts, suggestions, or issues...',
                    hintStyle: AppTextStyles.small.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.getSurface(context),
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                      borderSide: BorderSide(color: accentColor, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p20),

                // Email Input (Optional)
                Text(
                  'Contact Email (Optional)',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'name@example.com (if you\'d like a response)',
                    hintStyle: AppTextStyles.small.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.getSurface(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                      borderSide: BorderSide(color: accentColor, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r8),
                      ),
                    ),
                    onPressed: _submitFeedback,
                    child: Text(
                      'Submit Feedback',
                      style: AppTextStyles.subheading.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

