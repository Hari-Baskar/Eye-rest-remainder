import 'package:flutter_test/flutter_test.dart';
import 'package:reset/core/constants/app_strings.dart';
import 'package:reset/core/constants/app_colors.dart';
import 'package:reset/core/constants/app_sizes.dart';

void main() {
  test('Constants smoke test', () {
    expect(AppStrings.appName, 'LifeMint');
    expect(AppSizes.buttonHeight, 52.0);
    expect(AppColors.primary, isNotNull);
  });
}
