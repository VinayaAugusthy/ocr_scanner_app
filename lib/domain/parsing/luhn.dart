final _nonDigitRe = RegExp(r'\D');

bool isValidCard(String cardNumber) {
  final digits = cardNumber.replaceAll(_nonDigitRe, '');
  if (digits.length < 13 || digits.length > 19) {
    return false;
  }
  // All digits identical (000…0, 111…1, etc.) — optional OCR sanity check.
  final first = digits.codeUnitAt(0);
  var allDigitsIdentical = true;
  for (var i = 1; i < digits.length; i++) {
    if (digits.codeUnitAt(i) != first) {
      allDigitsIdentical = false;
      break;
    }
  }
  if (allDigitsIdentical) {
    return false;
  }
  var sum = 0;
  var alternate = false;

  for (var i = digits.length - 1; i >= 0; i--) {
    final unit = digits.codeUnitAt(i);
    if (unit < 0x30 || unit > 0x39) {
      return false;
    }
    var n = unit - 0x30;
    if (alternate) {
      n *= 2;
      if (n > 9) {
        n -= 9;
      }
    }
    sum += n;
    alternate = !alternate;
  }
  return sum % 10 == 0;
}
