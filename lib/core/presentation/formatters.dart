String maskCardNumberForDisplay(String? digitsOnly) {
  if (digitsOnly == null || digitsOnly.length < 4) {
    return '—';
  }
  final last4 = digitsOnly.substring(digitsOnly.length - 4);
  return 'XXXX XXXX XXXX $last4';
}

String formatExpiryDisplay(int? month, int? yearYY) {
  if (month == null || yearYY == null) return '—';
  final mm = month.toString().padLeft(2, '0');
  final yy = yearYY.toString().padLeft(2, '0');
  return '$mm/$yy';
}

String displayOrDash(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  return value.trim();
}
