import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_colors.dart';

abstract final class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.themeSeed),
      useMaterial3: true,
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
}
