import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import '../database/app_database.dart';

/// UserNameHelper
///
/// Manages user display name generation (Google Pay style random fun nicknames like "Swift Otter", "Calm Koala"),
/// persistence in SQLite & SharedPreferences, background service synchronization,
/// and the interactive Edit Name modal bottom sheet.
class UserNameHelper {
  static const List<String> _adjectives = [
    'Mighty',
    'Swift',
    'Calm',
    'Brave',
    'Curious',
    'Zen',
    'Golden',
    'Gentle',
    'Happy',
    'Quiet',
    'Clever',
    'Cosmic',
    'Wise',
    'Radiant',
    'Sunny',
    'Lucky',
    'Noble',
    'Silver',
    'Bright',
    'Warm',
    'Chilled',
    'Active',
    'Mindful',
    'Peaceful',
    'Breezy',
    'Stellar',
    'Lively',
    'Serene',
    'Joyful',
    'Daring',
  ];

  static const List<String> _nouns = [
    'Otter',
    'Falcon',
    'Koala',
    'Tiger',
    'Fox',
    'Panda',
    'Eagle',
    'Deer',
    'Dolphin',
    'Wolf',
    'Beaver',
    'Owl',
    'Turtle',
    'Bear',
    'Badger',
    'Hedgehog',
    'Lion',
    'Hawk',
    'Lynx',
    'Sparrow',
    'Robin',
    'Penguin',
    'Cheetah',
    'Rabbit',
    'Gazelle',
    'Leopard',
    'Bluebird',
    'Puma',
    'Seal',
    'Finch',
  ];

  /// Generates a playful random nickname like Google Pay (e.g., "Swift Otter", "Calm Koala")
  static String generateRandomName() {
    final rand = Random();
    final adj = _adjectives[rand.nextInt(_adjectives.length)];
    final noun = _nouns[rand.nextInt(_nouns.length)];
    return '$adj $noun';
  }

  /// Generates a list of distinct suggestion nicknames
  static List<String> generateSuggestions(int count) {
    final Set<String> names = {};
    while (names.length < count) {
      names.add(generateRandomName());
    }
    return names.toList();
  }

  /// Retrieves the saved user name, or generates and persists a new random one if not set
  static String getName() {
    try {
      final saved = AppDatabase.instance.getSetting('user_name');
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}

    // No name exists yet: generate a fun Google Pay-style nickname and persist it
    final randomName = generateRandomName();
    saveName(randomName);
    return randomName;
  }

  /// Saves the user name to SQLite, SharedPreferences, and alerts background service
  static Future<void> saveName(String name) async {
    final cleanName = name.trim().isEmpty ? generateRandomName() : name.trim();
    try {
      AppDatabase.instance.setSetting('user_name', cleanName);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', cleanName);
    } catch (_) {}

    try {
      FlutterBackgroundService().invoke('update_user_name', {
        'name': cleanName,
      });
    } catch (_) {}
  }

  /// Synchronously or asynchronously reads from SharedPreferences for background isolates
  static Future<String> getBackgroundUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name');
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    } catch (_) {}
    return 'Friend';
  }

  /// Displays the Google Pay-style interactive Edit Name bottom sheet modal
  static Future<void> showEditNameModal(
    BuildContext context, {
    required ValueChanged<String> onNameChanged,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final currentName = getName();

    final controller = TextEditingController(text: currentName);
    List<String> suggestions = generateSuggestions(3);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSizes.p20,
                  right: AppSizes.p20,
                  top: AppSizes.p12,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + AppSizes.p24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p16),

                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Personalize Display Name',
                          style: AppTextStyles.subheading.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p16),

                    // Name Text Field with Shuffle Dice Suffix
                    TextFormField(
                      controller: controller,
                      autofocus: false,
                      textCapitalization: TextCapitalization.words,
                      style: AppTextStyles.body.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter name or nickname',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurfaceSecondary
                            : AppColors.surfaceSecondary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.casino_outlined,
                            color: accentColor,
                            size: 24,
                          ),
                          tooltip: 'Shuffle Random Nickname',
                          onPressed: () {
                            final fresh = generateRandomName();
                            setModalState(() {
                              controller.text = fresh;
                              suggestions = generateSuggestions(3);
                            });
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r8),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r8),
                          borderSide: BorderSide(
                            color: accentColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p16),

                    // Quick Suggestion Chips
                    Row(
                      children: [
                        Text(
                          'Suggestions: ',
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: suggestions.map((sug) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setModalState(() {
                                        controller.text = sug;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.primaryLight.withValues(
                                                alpha: 0.15,
                                              )
                                            : AppColors.mintAccent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.primaryLight
                                                    .withValues(alpha: 0.35)
                                              : AppColors.primaryLight
                                                    .withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        sug,
                                        style: AppTextStyles.small.copyWith(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.primaryLight
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Save Button
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
                        onPressed: () {
                          final chosenName = controller.text.trim().isEmpty
                              ? generateRandomName()
                              : controller.text.trim();
                          saveName(chosenName);
                          Navigator.pop(ctx);
                          onNameChanged(chosenName);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Display name updated to '$chosenName'!",
                              ),
                              backgroundColor: accentColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          'Save Name',
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
            );
          },
        );
      },
    );
  }
}
