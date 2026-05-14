import 'dart:math' as math;

import 'package:ocr_scanner_app/features/card_scanner/domain/entities/card_details.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/parsing/luhn.dart';

bool _isAsciiDigit(String ch) =>
    ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

final _digitRe = RegExp(r'\d');
final _letterRe = RegExp(r'[A-Za-z]');
final _upperLetterRe = RegExp(r'[A-Z]');
final _nonDigitRe = RegExp(r'\D');
final _whitespaceRunRe = RegExp(r'\s+');
final _lineBreaksRe = RegExp(r'[\r\n]+');
final _expiryLabelHintsRe = RegExp(
  r'exp|valid|thru|good',
  caseSensitive: false,
);
final _expiryWithSlashRe = RegExp(
  r'\b(0[1-9]|1[0-2])\s*[/\-]\s*(\d{2}|\d{4})\b',
);
final _expiryCompactRe = RegExp(r'(?<!\d)(0[1-9]|1[0-2])(\d{2})(?!\d)');
final _holderExpiryLikeRe = RegExp(
  r'\b(0[1-9]|1[0-2])\s*[/\-]\s*(\d{2}|\d{4})\b|\b(0[1-9]|1[0-2])(\d{2})\b',
);

String _normalizeOcrInput(String raw) {
  return raw
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ')
      .replaceAll('\u2007', ' ')
      .replaceAll('\t', ' ');
}

/// Trims and collapses internal whitespace (common with ML Kit / gallery OCR).
String? _normalizeHolderField(String? holder) {
  if (holder == null) return null;
  var t = holder
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ')
      .replaceAll('\u2007', ' ')
      .replaceAll('\t', ' ');
  t = t.trim();
  if (t.isEmpty) return null;
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

CardDetails parseCard(String rawText) {
  final text = _normalizeOcrInput(rawText);
  final candidates = _extractPanCandidates(text);
  final luhnCandidates = candidates.where(isValidCard).toList();

  String? panDigits;
  if (luhnCandidates.isNotEmpty) {
    panDigits = luhnCandidates.reduce((a, b) => a.length >= b.length ? a : b);
  }
  final expiryRaw = _parseExpiry(text, panDigits);
  final expiry = _sanitizeExpiryTuple(expiryRaw);
  final holder = _parseHolderName(text, panDigits);

  return CardDetails(
    cardNumberDigits: panDigits,
    expiryMonth: expiry?.$1,
    expiryYearYY: expiry?.$2,
    holderName: _normalizeHolderField(holder),
    paymentNetwork: _detectPaymentNetwork(panDigits),
    luhnValid: panDigits != null && isValidCard(panDigits),
  );
}

bool _isPanRunChar(String c) {
  if (c.length != 1) {
    return false;
  }
  if (_isAsciiDigit(c)) {
    return true;
  }
  if (c == ' ' || c == '-') {
    return true;
  }
  return _ocrDigitMapFull(c) != null;
}

int? _ocrDigitMapFull(String c) {
  switch (c) {
    case '0':
    case 'O':
    case 'o':
    case 'Q':
    case 'D':
    case 'U':
    case 'u':
      return 0;
    case '1':
    case 'I':
    case 'l':
    case 'i':
    case '|':
    case '!':
    case 'L':
      return 1;
    case '2':
    case 'Z':
    case 'z':
      return 2;
    case '3':
    case 'E':
      return 3;
    case '4':
    case 'A':
    case 'a':
      return 4;
    case '5':
    case 'S':
    case 's':
      return 5;
    case '6':
    case 'G':
    case 'b':
      return 6;
    case '7':
    case 'T':
    case '?':
    case '¥':
      return 7;
    case '8':
    case 'B':
      return 8;
    case '9':
    case 'g':
    case 'q':
      return 9;
    default:
      return null;
  }
}

int? _ocrDigitMapStrict(String c) {
  switch (c) {
    case '0':
    case 'O':
    case 'o':
    case 'Q':
    case 'D':
    case 'U':
    case 'u':
      return 0;
    case '1':
    case 'I':
    case 'l':
    case 'i':
    case '|':
    case '!':
    case 'L':
      return 1;
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      return int.parse(c);
    default:
      return null;
  }
}

bool _isDigitHeavyPanRun(String run) {
  var digitCount = 0;
  var ocrLetterCount = 0;
  for (final ch in run.split('')) {
    if (ch == ' ' || ch == '-') {
      continue;
    }
    if (_isAsciiDigit(ch)) {
      digitCount++;
    } else if (_ocrDigitMapFull(ch) != null) {
      ocrLetterCount++;
    }
  }
  final total = digitCount + ocrLetterCount;
  if (total == 0) {
    return false;
  }
  return digitCount / total >= 0.55;
}

String _normalizePanRun(String run) {
  final aggressive = _isDigitHeavyPanRun(run);
  final b = StringBuffer();
  for (final ch in run.split('')) {
    if (ch == ' ' || ch == '-') {
      continue;
    }
    if (_isAsciiDigit(ch)) {
      b.write(ch);
      continue;
    }
    final d = aggressive ? _ocrDigitMapFull(ch) : _ocrDigitMapStrict(ch);
    if (d != null) {
      b.write('$d');
    }
  }
  return b.toString();
}

List<String> _extractPanCandidates(String input) {
  final seen = <String>{};
  final ordered = <String>[];
  final buf = StringBuffer();

  void flush() {
    if (buf.isEmpty) {
      return;
    }
    final run = buf.toString();
    buf.clear();
    final digits = _normalizePanRun(run);
    if (digits.length >= 13 && digits.length <= 19 && seen.add(digits)) {
      ordered.add(digits);
    }
  }

  for (final unit in input.runes) {
    final ch = String.fromCharCode(unit);
    if (_isPanRunChar(ch)) {
      buf.write(ch);
    } else {
      flush();
    }
  }
  flush();
  return ordered;
}

(int month, int yearYY)? _parseExpiry(String text, String? panDigits) {
  final search = _stripPanForExpirySearch(text, panDigits);

  final m1 = _expiryWithSlashRe.firstMatch(search);
  if (m1 != null) {
    final mm = int.parse(m1.group(1)!);
    final yyStr = m1.group(2)!;
    final yy = int.parse(yyStr.length == 4 ? yyStr.substring(2) : yyStr);
    return (mm, yy);
  }

  for (final m in _expiryCompactRe.allMatches(search)) {
    final start = m.start;
    final end = m.end;
    final window = search.substring(
      start > 4 ? start - 4 : 0,
      end + 4 < search.length ? end + 4 : search.length,
    );
    if (_expiryLabelHintsRe.hasMatch(window)) {
      final mm = int.parse(m.group(1)!);
      final yy = int.parse(m.group(2)!);
      return (mm, yy);
    }
  }

  final m2 = _expiryCompactRe.firstMatch(search);
  if (m2 != null) {
    return (int.parse(m2.group(1)!), int.parse(m2.group(2)!));
  }

  return null;
}

/// Drops invalid months and **past** expiry (current month still valid).
(int month, int yearYY)? _sanitizeExpiryTuple((int month, int yearYY)? raw) {
  if (raw == null) {
    return null;
  }
  final mm = raw.$1;
  final yy = raw.$2;
  if (mm < 1 || mm > 12) {
    return null;
  }
  final yFull = yy >= 70 ? 1900 + yy : 2000 + yy;
  final now = DateTime.now();
  final nowIndex = now.year * 12 + now.month;
  final expIndex = yFull * 12 + mm;
  if (expIndex < nowIndex) {
    return null;
  }
  return (mm, yy);
}

String _stripPanForExpirySearch(String text, String? panDigits) {
  if (panDigits == null || panDigits.isEmpty) {
    return text;
  }
  final parts = panDigits.split('').map(RegExp.escape).join(r'[^\d]{0,3}');
  return text.replaceFirst(RegExp(parts), ' ');
}

String? _detectPaymentNetwork(String? pan) {
  if (pan == null || pan.length < 2) {
    return null;
  }
  if (pan.startsWith('34') || pan.startsWith('37')) {
    if (pan.length == 15) {
      return 'American Express';
    }
  }
  if (pan.startsWith('4')) {
    return 'Visa';
  }
  if (pan.length >= 2) {
    final two = int.tryParse(pan.substring(0, 2));
    if (two != null && two >= 51 && two <= 55) {
      return 'Mastercard';
    }
  }
  if (pan.length >= 4) {
    final four = int.tryParse(pan.substring(0, 4));
    if (four != null && four >= 2221 && four <= 2720) {
      return 'Mastercard';
    }
  }
  return null;
}

String? _parseHolderName(String text, String? panDigits) {
  final skipSubstrings = [
    'valid',
    'thru',
    'expires',
    'expire',
    'exp date',
    'expd',
    'card',
    'debit',
    'credit',
    'visa',
    'master',
    'amex',
    'unionpay',
    'world',
    'gold',
    'platinum',
    'member',
    'since',
  ];

  final lines = text.split(_lineBreaksRe);
  int? panLineIndex;
  if (panDigits != null && panDigits.length >= 4) {
    final prefix = panDigits.substring(0, 4);
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(prefix)) {
        panLineIndex = i;
        break;
      }
    }
  }

  String? best;
  var bestScore = -999999;

  for (var i = 0; i < lines.length; i++) {
    final t = lines[i].trim();
    if (t.length < 3 || t.length > 42) {
      continue;
    }
    final lower = t.toLowerCase();

    const blockedExact = {
      'visa',
      'mastercard',
      'master card',
      'platinum',
      'gold',
      'world',
      'rupay',
    };
    if (blockedExact.contains(lower.trim())) {
      continue;
    }
    if (lower.contains('visa') ||
        lower.contains('mastercard') ||
        lower.contains('rupay')) {
      continue;
    }

    if (RegExp(
          r'^\s*(?:exp\s|expiry|expires?|exp\.?\s*date|valid\s+thru|thru\s)',
          caseSensitive: false,
        ).hasMatch(lower) &&
        RegExp(r'\d{2,}').hasMatch(t)) {
      continue;
    }

    if (skipSubstrings.any(lower.contains)) {
      continue;
    }
    if (_holderExpiryLikeRe.hasMatch(t)) {
      continue;
    }
    final digitChars = _digitRe.allMatches(t).length;
    if (digitChars > t.length * 0.45) {
      continue;
    }
    final letters = _letterRe.allMatches(t).length;
    if (letters < 2 || letters < t.length * 0.35) {
      continue;
    }
    final lineDigits = t.replaceAll(_nonDigitRe, '');
    if (panDigits != null &&
        lineDigits.length >= 13 &&
        lineDigits == panDigits) {
      continue;
    }

    var score = 0;
    final tokens = t.split(_whitespaceRunRe).where((w) => w.isNotEmpty).length;
    score += tokens * 3;
    score += letters;
    final upper = _upperLetterRe.allMatches(t).length;
    score += ((upper / math.max(1, t.length)) * 20).round();

    final panLine = panLineIndex;
    if (panLine != null) {
      if (i < panLine) {
        score += (panLine - i) * 6;
      } else if (i > panLine) {
        score += math.max(0, 10 - (i - panLine) * 2);
      }
    }

    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }
  return best;
}
