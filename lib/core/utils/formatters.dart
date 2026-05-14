import 'package:ocr_scanner_app/core/constants/app_strings.dart';

String maskCardNumberForDisplay(String? digitsOnly) {
  if (digitsOnly == null || digitsOnly.length < 4) {
    return AppStrings.emDash;
  }
  final last4 = digitsOnly.substring(digitsOnly.length - 4);
  return '${AppStrings.cardNumberMaskPrefix}$last4';
}

String formatExpiryDisplay(int? month, int? yearYY) {
  if (month == null || yearYY == null) return AppStrings.emDash;
  final mm = month.toString().padLeft(2, '0');
  final yy = yearYY.toString().padLeft(2, '0');
  return '$mm/$yy';
}

String displayOrDash(String? value) {
  if (value == null || value.trim().isEmpty) return AppStrings.emDash;
  return value.trim();
}
