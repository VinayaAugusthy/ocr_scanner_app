import 'dart:math' as math;

import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/bank_details.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/passbook_account_candidate.dart';

final _dateLikeSeparatedRe = RegExp(r'^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}$');
final _nonAlnumRe = RegExp(r'[^A-Z0-9]');
final _nonDigitRe = RegExp(r'\D');
final _ifscLooseSpacedRe = RegExp(
  r'[A-Z]{4}\s*[0O]\s*[A-Z0-9\s\-]{6,12}',
  caseSensitive: false,
);
final _ifscAnchorRe = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final _indianMobileRe = RegExp(r'^[6-9]\d{9}$');
final _wsRe = RegExp(r'\s+');
final _digitRe = RegExp(r'\d');
final _alnumCompactRe = RegExp(r'[^A-Za-z0-9]');
final _unicodeLetterRe = RegExp(r'\p{L}', unicode: true);
final _unicodeLowerRe = RegExp(r'\p{Ll}', unicode: true);
final _unicodeUpperRe = RegExp(r'\p{Lu}', unicode: true);
final _leadingDigitRe = RegExp(r'^\d');
final _honorificPrefixRe = RegExp(
  r'^(?:mrs|miss|mr|ms|mx|dr|prof|shri|smt|sri|kumari|km)\.?\s',
  caseSensitive: false,
);
final _titleCaseMultiWordRe = RegExp(
  r'^[\p{Lu}][\p{Ll}]+(?:\s+[\p{Lu}][\p{Ll}]+)+\s*$',
  unicode: true,
);
final _initialTokenRe = RegExp(r'^[\p{L}]\.?$', unicode: true);
final _ifscLabelPrefixRe = RegExp(
  r'IFSC\s*'
  r'(?:[-–_/]\s*)?'
  r'(?:CODE|NO\.?|NUMBER|ID|#)?\s*'
  r'[:#.\-]?\s*',
  caseSensitive: false,
);
final _cleanOcrControlCharsRe = RegExp(
  r'[\u0000-\u0009\u000B\u000C\u000E-\u001F\u007F]',
);
final _cleanOcrSpacesRe = RegExp(r' +');
final _cleanOcrExcessNewlinesRe = RegExp(r'\n{3,}');
final _maskedAccountRe = RegExp(
  r'(?:X|\*)[\sX*\-]{2,}\d{3,}',
  caseSensitive: false,
);

/// Extraction confidence levels used across passbook parsing.
abstract final class PassbookParseConfidence {
  static const perfect = 1.0;
  static const labeledStrong = 0.92;
  static const labeledHonorific = 0.87;
  static const labeledDefault = 0.9;
  static const spacedLayout = 0.97;
  static const compactScan = 0.72;
  static const ocrCorrected = 0.86;
  static const relaxedBranch = 0.88;
  static const heuristic = 0.72;
  static const accountStrong = 0.96;
  static const accountGood = 0.88;
  static const accountFair = 0.78;
  static const accountWeak = 0.64;
  static const accountLow = 0.48;
}

const _bankNoiseWords = [
  'bank',
  'branch',
  'ifsc',
  'micr',
  'statement',
  'passbook',
  'customer care',
  'mobile',
  'email',
  'bank of',
  'state bank',
];

const _institutionTerms = [
  'bank',
  'branch',
  'india',
  'ltd',
  'limited',
  'finance',
  'cooperative',
  'co-operative',
];

const _nameHeuristicSkipTerms = [
  'address',
  'phone',
  'customer id',
  'cust id',
  'cif no',
  'pan ',
  'aadhaar',
  'swift',
  'iban',
  'branch code',
];

const _transactionWords = [
  'utr',
  'rrn',
  'cheque',
  'txn',
  'transaction id',
  'ref no',
  'reference',
  'upi',
  'imps',
  'neft',
  'rtgs',
];

bool _isAsciiDigit(String ch) =>
    ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

bool _isAccountSeparator(String ch) =>
    ch == ' ' || ch == '-' || ch == '/' || ch == '.';

bool _ifscSurroundedByDigits(String s, int i) {
  final prev = i > 0 && _isAsciiDigit(s[i - 1]);
  final next = i < s.length - 1 && _isAsciiDigit(s[i + 1]);
  return prev && next;
}

bool _runCharDigitLikeAt(String run, int idx) {
  if (idx < 0 || idx >= run.length) {
    return false;
  }
  final ch = run[idx];
  return _isAsciiDigit(ch) || _ocrLetterToDigit(ch) != null;
}

bool _runCharSurroundedByDigits(
  String run,
  int i, {
  bool allowTrailingEnd = false,
}) {
  if (!_runCharDigitLikeAt(run, i - 1)) {
    return false;
  }

  if (i >= run.length - 1) {
    return allowTrailingEnd;
  }

  return _runCharDigitLikeAt(run, i + 1);
}

int _countUnicodeLetters(String s) => _unicodeLetterRe.allMatches(s).length;

bool _lineHasInstitutionTerms(String lower) {
  for (final term in _institutionTerms) {
    if (lower.contains(term)) {
      return true;
    }
  }
  return false;
}

bool _lineSuggestsNonAccountNumeric(String lower) {
  if (_transactionWords.any(lower.contains)) {
    return true;
  }
  if (lower.contains('customer id') ||
      lower.contains('cust id') ||
      lower.contains('cif') ||
      lower.contains('user id')) {
    return true;
  }
  if (lower.contains('utr') ||
      lower.contains('rrn') ||
      lower.contains('ref no') ||
      lower.contains('reference no')) {
    return true;
  }
  return false;
}

bool _isPlausibleAccountCandidate(
  String digits,
  String lineLower, {
  bool hasAccountContext = false,
}) {
  if (digits.length < 9 || digits.length > 18) {
    return false;
  }
  if (_lineSuggestsNonAccountNumeric(lineLower)) {
    return false;
  }
  if (_indianMobileRe.hasMatch(digits) &&
      !hasAccountContext &&
      !lineLower.contains('account')) {
    return false;
  }
  if (_isSequentialDigits(digits) &&
      !hasAccountContext &&
      !lineLower.contains('account') &&
      !lineLower.contains('a/c')) {
    return false;
  }
  return true;
}

int _countBankNoiseTerms(String lower) {
  var hits = 0;
  for (final term in _bankNoiseWords) {
    if (lower.contains(term)) {
      hits++;
    }
  }
  return hits;
}

String _compactAlphaNum(String s) => s.replaceAll(_nonAlnumRe, '');

class ParsedLine {
  ParsedLine({
    required this.normalized,
    required this.lineNumber,
    required this.parsedLineIndex,
    required this.startInDoc,
    required this.lower,
    required this.compact,
    required this.digitsOnly,
    String? raw,
  }) : raw = raw ?? normalized;

  final String raw;
  final String normalized;

  final int lineNumber;

  final int parsedLineIndex;
  final int startInDoc;
  final String lower;
  final String compact;
  final String digitsOnly;
}

ParsedLine _buildParsedLine(
  String trimmed,
  int sourceLineIndex,
  int parsedLineIndex,
  int startInDoc,
) {
  final lower = trimmed.toLowerCase();
  return ParsedLine(
    normalized: trimmed,
    lineNumber: sourceLineIndex,
    parsedLineIndex: parsedLineIndex,
    startInDoc: startInDoc,
    lower: lower,
    compact: _compactAlphaNum(trimmed.toUpperCase()),
    digitsOnly: trimmed.replaceAll(_nonDigitRe, ''),
  );
}

String _ifscBankCodeLetterFromOcr(String c) {
  final u = c.toUpperCase();
  if (u.length != 1) {
    return u;
  }
  final code = u.codeUnitAt(0);
  if (code >= 0x41 && code <= 0x5a) {
    return u;
  }
  if (_isAsciiDigit(c)) {
    switch (c) {
      case '0':
        return 'O';
      case '1':
        return 'I';
      case '2':
        return 'Z';
      case '3':
        return 'E';
      case '4':
        return 'A';
      case '5':
        return 'S';
      case '6':
        return 'G';
      case '7':
        return 'T';
      case '8':
        return 'B';
      case '9':
        return 'Q';
    }
  }
  return u;
}

String _normalizeIfscOcr(String token) {
  final tailPart = token.length >= 11 ? token.substring(5) : '';
  final aggressiveTail = _isDigitHeavyIfscTail(tailPart);

  final b = StringBuffer();

  for (var i = 0; i < token.length; i++) {
    final c = token[i];

    if (i < 4) {
      b.write(_ifscBankCodeLetterFromOcr(c));
      continue;
    }

    if (i == 4) {
      b.write(_ifscFifthChar(c));
      continue;
    }

    if (aggressiveTail) {
      final aggressive = _ocrAggressiveShapeToDigit(c);

      if (aggressive != null && _ifscSurroundedByDigits(token, i)) {
        b.write(aggressive);
        continue;
      }
    }

    b.write(_ifscTailOcrChar(c));
  }

  return b.toString();
}

bool _isDigitHeavyIfscTail(String tail) {
  if (tail.isEmpty) {
    return false;
  }

  var digits = 0;

  for (var i = 0; i < tail.length; i++) {
    if (_isAsciiDigit(tail[i])) {
      digits++;
    }
  }

  return digits / tail.length >= 0.8;
}

int _ifscBranchDigitCount(String fixed) {
  if (fixed.length != 11) {
    return 0;
  }
  final tail = fixed.substring(5);
  var digits = 0;
  for (var i = 0; i < tail.length; i++) {
    if (_isAsciiDigit(tail[i])) {
      digits++;
    }
  }
  return digits;
}

bool _ifscBranchLooksPlausible(String fixed) =>
    _ifscBranchDigitCount(fixed) >= 4;

bool _ifscBranchLooksPlausibleRelaxed(String fixed) =>
    _ifscBranchDigitCount(fixed) >= 3;

String? _bestIfscFromCompact(String compact, {required bool allowRelaxed}) {
  String? bestStrict;
  var bestStrictDigits = -1;
  String? bestRelaxed;
  var bestRelaxedDigits = -1;

  for (var i = 0; i + 11 <= compact.length; i++) {
    final token = compact.substring(i, i + 11);
    final fixed = _normalizeIfscOcr(token);

    if (!_ifscAnchorRe.hasMatch(fixed)) {
      continue;
    }

    final dc = _ifscBranchDigitCount(fixed);

    if (_ifscBranchLooksPlausible(fixed)) {
      if (dc > bestStrictDigits) {
        bestStrictDigits = dc;
        bestStrict = fixed;
      }
    } else if (allowRelaxed && _ifscBranchLooksPlausibleRelaxed(fixed)) {
      if (dc > bestRelaxedDigits) {
        bestRelaxedDigits = dc;
        bestRelaxed = fixed;
      }
    }
  }

  return bestStrict ?? bestRelaxed;
}

String? _extractIfscNearKeyword(String line) {
  final n = _normalizeIfscLine(line);

  if (!n.toLowerCase().contains('ifsc')) {
    return null;
  }

  final m = _ifscLabelPrefixRe.firstMatch(n);
  final after = m != null ? n.substring(m.end) : n;
  final tail = after.trim();

  if (tail.isNotEmpty) {
    final tailCompact = _compactAlphaNum(tail);

    if (tailCompact.length >= 11) {
      final hit = _bestIfscFromCompact(tailCompact, allowRelaxed: true);

      if (hit != null) {
        return hit;
      }
    }
  }

  final fullCompact = _compactAlphaNum(n);

  return _bestIfscFromCompact(fullCompact, allowRelaxed: true);
}

bool _ifscHitNeededOcrNormalization(String rawLine, String hit) {
  final compact = _compactAlphaNum(_normalizeIfscLine(rawLine));

  for (var i = 0; i + 11 <= compact.length; i++) {
    final w = compact.substring(i, i + 11);

    if (_normalizeIfscOcr(w) != hit) {
      continue;
    }

    if (w.toUpperCase() != hit) {
      return true;
    }
  }

  return false;
}

double _labeledIfscConfidence(String rawLine, String hit) {
  if (!_ifscBranchLooksPlausible(hit)) {
    return PassbookParseConfidence.relaxedBranch;
  }

  final n = _normalizeIfscLine(rawLine);

  if (RegExp(
    r'\b' + RegExp.escape(hit) + r'\b',
    caseSensitive: false,
  ).hasMatch(n)) {
    return PassbookParseConfidence.perfect;
  }

  if (_ifscHitNeededOcrNormalization(rawLine, hit)) {
    return PassbookParseConfidence.ocrCorrected;
  }

  return PassbookParseConfidence.spacedLayout;
}

String _ifscFifthChar(String c) {
  switch (c) {
    case '0':
    case 'O':
    case 'o':
    case 'D':
    case 'Q':
      return '0';

    case '1':
    case 'I':
    case 'l':
    case '|':
    case '!':
    case 'L':
      return '1';

    default:
      return c;
  }
}

String _ifscTailOcrChar(String c) {
  final d = _ocrLetterToDigit(c);
  return d != null ? '$d' : c;
}

String _normalizeIfscLine(String s) => s.toUpperCase();

({String? code, double confidence})? _findIfscOnNormalizedLine(
  String normalized,
) {
  for (final m in _ifscLooseSpacedRe.allMatches(normalized)) {
    final raw = m.group(0)!;
    final compact = _compactAlphaNum(raw);

    if (compact.length < 11) {
      continue;
    }

    final hit = _bestIfscFromCompact(compact, allowRelaxed: false);

    if (hit != null) {
      final spaced = RegExp(r'\s').hasMatch(raw);

      return (
        code: hit,
        confidence:
            compact.length == 11 &&
                _ifscAnchorRe.hasMatch(_normalizeIfscOcr(compact))
            ? PassbookParseConfidence.perfect
            : spaced
            ? PassbookParseConfidence.spacedLayout
            : PassbookParseConfidence.ocrCorrected,
      );
    }
  }

  final compact = _compactAlphaNum(normalized);

  for (var i = 0; i + 11 <= compact.length; i++) {
    final fixed = _normalizeIfscOcr(compact.substring(i, i + 11));

    if (_ifscAnchorRe.hasMatch(fixed) && _ifscBranchLooksPlausible(fixed)) {
      return (code: fixed, confidence: PassbookParseConfidence.compactScan);
    }
  }

  return null;
}

({String? code, double confidence}) findIfsc(List<ParsedLine> lines) {
  for (final pl in lines) {
    if (!pl.lower.contains('ifsc')) {
      continue;
    }

    final near = _extractIfscNearKeyword(pl.normalized);

    if (near != null) {
      return (
        code: near,
        confidence: _labeledIfscConfidence(pl.normalized, near),
      );
    }
  }

  for (final pl in lines) {
    final hit = _findIfscOnNormalizedLine(_normalizeIfscLine(pl.normalized));

    if (hit != null) {
      return hit;
    }
  }

  return (code: null, confidence: 0.0);
}

int? _ocrLetterToDigit(String c) {
  switch (c) {
    case 'O':
    case 'o':
    case 'D':
    case 'Q':
      return 0;

    case 'I':
    case 'l':
    case '|':
    case '!':
    case 'L':
      return 1;

    default:
      return null;
  }
}

int? _ocrAggressiveShapeToDigit(String c) {
  switch (c) {
    case 'S':
    case 's':
      return 5;

    case 'B':
    case 'b':
      return 8;

    case 'Z':
    case 'z':
      return 2;

    default:
      return null;
  }
}

bool _isDigitHeavyAccountRun(String run) {
  var digits = 0;
  var other = 0;

  for (var i = 0; i < run.length; i++) {
    final ch = run[i];

    if (_isAccountSeparator(ch)) {
      continue;
    }

    if (_isAsciiDigit(ch)) {
      digits++;
    } else {
      other++;
    }
  }

  final total = digits + other;

  return total > 0 && digits / total >= 0.80;
}

bool _hasTooManyNonDigitShapes(String run) {
  var noisy = 0;
  var total = 0;

  for (var i = 0; i < run.length; i++) {
    final ch = run[i];

    if (_isAccountSeparator(ch)) {
      continue;
    }

    total++;

    if (!_isAsciiDigit(ch)) {
      noisy++;
    }
  }

  return total > 0 && noisy / total > 0.35;
}

bool _lineHasAccountKeywordContext(String line) {
  final l = line.toLowerCase();

  return l.contains('account') || l.contains('a/c');
}

final _accountLabelAnchorRe = RegExp(
  r'(?:account|a\s*/\s*c|a/c)\s*(?:no\.?|number|#)?',
  caseSensitive: false,
);

bool _lineAnchorsAccountBlock(String line) {
  final l = line.trim().toLowerCase();
  if (_accountLabelAnchorRe.hasMatch(l)) {
    return true;
  }
  if (!l.contains('account')) {
    return false;
  }
  return l.contains('no') ||
      l.contains('number') ||
      l.contains(':') ||
      l.contains('#');
}

bool _lineIsAccountLabelOnly(String line) {
  if (!_lineAnchorsAccountBlock(line)) {
    return false;
  }
  return line.replaceAll(_nonDigitRe, '').length <= 2;
}

bool _lineIsNumericContinuationSegment(String line) {
  final t = line.trim();
  if (t.isEmpty || t.length > 24) {
    return false;
  }

  final lower = t.toLowerCase();
  if (lower.contains('ifsc') ||
      lower.contains('micr') ||
      lower.contains('utr') ||
      lower.contains('txn')) {
    return false;
  }
  if (_countBankNoiseTerms(lower) >= 2) {
    return false;
  }

  if (_lineAnchorsAccountBlock(t) && !_lineIsAccountLabelOnly(t)) {
    return false;
  }

  final letters = _countUnicodeLetters(t);
  final nonSpace = t.replaceAll(_wsRe, '').length;
  if (nonSpace == 0 || letters / nonSpace > 0.2) {
    return false;
  }

  final norm = normalizeAccountRun(
    t,
    allowAggressiveShapeCorrection: _isDigitHeavyAccountRun(t),
  );

  return norm.digits.length >= 3 && norm.digits.length <= 14;
}

String? _accountDigitFragmentOnLine(String line) {
  var start = 0;

  if (_lineAnchorsAccountBlock(line)) {
    final colon = line.indexOf(':');
    final searchFrom = colon >= 0 ? colon + 1 : 0;
    start = line.length;

    for (var i = searchFrom; i < line.length; i++) {
      final ch = line[i];

      if (_isAsciiDigit(ch) || _ocrLetterToDigit(ch) != null) {
        start = i;
        break;
      }
    }

    if (start >= line.length) {
      return null;
    }
  }

  final buf = StringBuffer();

  for (var i = start; i < line.length; i++) {
    final ch = line[i];

    if (_isAsciiDigit(ch)) {
      buf.write(ch);
    } else if (_isAccountSeparator(ch)) {
      buf.write(ch);
    } else if (_ocrLetterToDigit(ch) != null) {
      buf.write(_ocrLetterToDigit(ch));
    } else if (buf.isNotEmpty) {
      break;
    }
  }

  final frag = buf.toString().trim();

  if (frag.replaceAll(_nonDigitRe, '').length < 3) {
    return null;
  }

  return frag;
}

int _stitchedDigitCount(List<String> parts) {
  if (parts.isEmpty) {
    return 0;
  }

  final raw = parts.join(' ');
  final hasContext = parts.any(_lineAnchorsAccountBlock);

  return normalizeAccountRun(
    raw,
    allowAggressiveShapeCorrection: hasContext || _isDigitHeavyAccountRun(raw),
  ).digits.length;
}

({String digits, bool hadOcrCorrection, String rawText})?
_mergeStitchedAccountParts(
  List<String> parts, {
  bool hasAccountContext = false,
}) {
  if (parts.isEmpty) {
    return null;
  }

  final raw = parts.join(' ');
  final hasContext = hasAccountContext || parts.any(_lineAnchorsAccountBlock);
  final norm = normalizeAccountRun(
    raw,
    allowAggressiveShapeCorrection: hasContext || _isDigitHeavyAccountRun(raw),
  );

  if (norm.digits.length < 9 || norm.digits.length > 18) {
    return null;
  }

  if (!_isPlausibleAccountCandidate(
    norm.digits,
    raw.toLowerCase(),
    hasAccountContext: hasContext,
  )) {
    return null;
  }

  return (
    digits: norm.digits,
    hadOcrCorrection: norm.hadOcrCorrection,
    rawText: raw,
  );
}

List<PassbookAccountCandidate> _extractCrossLineAccountCandidates(
  List<ParsedLine> lines,
) {
  final out = <PassbookAccountCandidate>[];
  final stitchedContinuationLines = <int>{};

  for (var i = 0; i < lines.length; i++) {
    final pl = lines[i];
    final line = pl.normalized;

    if (!_lineAnchorsAccountBlock(line)) {
      continue;
    }

    final parts = <String>[];
    final digitsOnLine = line.replaceAll(_nonDigitRe, '').length;

    if (digitsOnLine >= 3) {
      final frag = _accountDigitFragmentOnLine(line);

      if (frag != null) {
        parts.add(frag);
      } else if (!_lineIsAccountLabelOnly(line)) {
        continue;
      }
    } else if (!_lineIsAccountLabelOnly(line)) {
      continue;
    }

    var j = i + 1;
    while (j < lines.length && j - i <= 4) {
      final nextLine = lines[j].normalized;
      if (!_lineIsNumericContinuationSegment(nextLine)) {
        break;
      }

      final trial = [...parts, nextLine];
      final trialDigits = _stitchedDigitCount(trial);

      if (trialDigits > 18) {
        break;
      }

      parts.add(nextLine);
      stitchedContinuationLines.add(j);
      j++;

      if (trialDigits >= 9) {
        break;
      }
    }

    final merged = _mergeStitchedAccountParts(parts, hasAccountContext: true);
    if (merged == null) {
      continue;
    }

    final isMultiPart = parts.length >= 2;
    final isLabelWithContinuation =
        _lineIsAccountLabelOnly(line) && parts.isNotEmpty;

    if (!isMultiPart && !isLabelWithContinuation) {
      continue;
    }

    if (parts.length == 1 &&
        digitsOnLine >= 9 &&
        !_lineIsAccountLabelOnly(line)) {
      continue;
    }

    out.add(
      PassbookAccountCandidate(
        rawText: merged.rawText,
        normalizedText: merged.digits,
        hadOcrCorrection: merged.hadOcrCorrection,
        lineNumber: pl.lineNumber,
        startInDoc: pl.startInDoc,
        lineText: parts.join(' | '),
      ),
    );
  }

  for (var i = 0; i < lines.length - 1; i++) {
    if (stitchedContinuationLines.contains(i)) {
      continue;
    }
    if (i > 0 && _lineAnchorsAccountBlock(lines[i - 1].normalized)) {
      continue;
    }

    final first = lines[i].normalized;
    final second = lines[i + 1].normalized;

    if (!_lineIsNumericContinuationSegment(first) ||
        !_lineIsNumericContinuationSegment(second)) {
      continue;
    }

    if (_stitchedDigitCount([first]) >= 9 ||
        _stitchedDigitCount([second]) >= 9) {
      continue;
    }

    final merged = _mergeStitchedAccountParts([first, second]);
    if (merged == null) {
      continue;
    }

    out.add(
      PassbookAccountCandidate(
        rawText: merged.rawText,
        normalizedText: merged.digits,
        hadOcrCorrection: merged.hadOcrCorrection,
        lineNumber: lines[i].lineNumber,
        startInDoc: lines[i].startInDoc,
        lineText: '$first | $second',
      ),
    );
    stitchedContinuationLines.add(i + 1);
  }

  return out;
}

({String digits, bool hadOcrCorrection}) normalizeAccountRun(
  String run, {
  bool allowAggressiveShapeCorrection = false,
}) {
  final digitHeavy = _isDigitHeavyAccountRun(run);
  final aggressive =
      allowAggressiveShapeCorrection &&
      digitHeavy &&
      !_hasTooManyNonDigitShapes(run);

  final b = StringBuffer();
  var corrected = false;

  for (var i = 0; i < run.length; i++) {
    final ch = run[i];

    if (_isAccountSeparator(ch)) {
      continue;
    }

    if (_isAsciiDigit(ch)) {
      b.write(ch);
      continue;
    }

    if (aggressive) {
      final aggressiveDigit = _ocrAggressiveShapeToDigit(ch);

      if (aggressiveDigit != null && _runCharSurroundedByDigits(run, i)) {
        corrected = true;
        b.write(aggressiveDigit);
        continue;
      }
    }

    final d = _ocrLetterToDigit(ch);

    if (d != null) {
      corrected = true;
      b.write(d);
    }
  }

  return (digits: b.toString(), hadOcrCorrection: corrected);
}

bool _isAccountRunChar(String c, {bool allowLowercaseOAsZero = false}) {
  if (c.length != 1) {
    return false;
  }

  final code = c.codeUnitAt(0);

  if (code >= 0x30 && code <= 0x39) {
    return true;
  }

  if (_isAccountSeparator(c)) {
    return true;
  }

  if (c == 'o' && !allowLowercaseOAsZero) {
    return false;
  }

  return _ocrLetterToDigit(c) != null;
}

List<PassbookAccountCandidate> extractAccountCandidates(
  List<ParsedLine> lines,
) {
  final out = <PassbookAccountCandidate>[];
  final seenDigits = <String>{};

  for (final pl in lines) {
    final line = pl.normalized;

    if (line.isEmpty) {
      continue;
    }

    final local = _extractAccountCandidatesFromLine(line);

    for (final c in local) {
      if (!seenDigits.add(c.normalizedText)) {
        continue;
      }

      out.add(
        PassbookAccountCandidate(
          rawText: c.rawText,
          normalizedText: c.normalizedText,
          hadOcrCorrection: c.hadOcrCorrection,
          lineNumber: pl.lineNumber,
          startInDoc: pl.startInDoc + c.start,
          lineText: line,
        ),
      );
    }
  }

  for (final stitched in _extractCrossLineAccountCandidates(lines)) {
    if (!seenDigits.add(stitched.normalizedText)) {
      continue;
    }

    out.add(stitched);
  }

  return out;
}

List<
  ({int start, String rawText, String normalizedText, bool hadOcrCorrection})
>
_extractAccountCandidatesFromLine(String line) {
  final out =
      <
        ({
          int start,
          String rawText,
          String normalizedText,
          bool hadOcrCorrection,
        })
      >[];

  final hasAccountContext = _lineHasAccountKeywordContext(line);

  final buf = StringBuffer();

  var runStart = 0;
  var inRun = false;
  var sepStreak = 0;
  var runHasAsciiDigit = false;

  void flush() {
    if (!inRun) {
      return;
    }

    inRun = false;
    sepStreak = 0;
    runHasAsciiDigit = false;

    final run = buf.toString();

    buf.clear();

    final norm = normalizeAccountRun(
      run,
      allowAggressiveShapeCorrection:
          hasAccountContext || _isDigitHeavyAccountRun(run),
    );

    if (_isPlausibleAccountCandidate(
      norm.digits,
      line.toLowerCase(),
      hasAccountContext: hasAccountContext,
    )) {
      out.add((
        start: runStart,
        rawText: run,
        normalizedText: norm.digits,
        hadOcrCorrection: norm.hadOcrCorrection,
      ));
    }
  }

  bool isRunChar(String ch) {
    if (_isAsciiDigit(ch)) {
      return true;
    }

    if (_isAccountSeparator(ch)) {
      return true;
    }

    if (inRun && runHasAsciiDigit && _ocrAggressiveShapeToDigit(ch) != null) {
      final runSoFar = buf.toString();
      final idx = runSoFar.length;
      if ((hasAccountContext || _isDigitHeavyAccountRun('$runSoFar$ch')) &&
          _runCharSurroundedByDigits(
            '$runSoFar$ch',
            idx,
            allowTrailingEnd: true,
          )) {
        return true;
      }
    }

    return _isAccountRunChar(
      ch,
      allowLowercaseOAsZero: inRun && runHasAsciiDigit,
    );
  }

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];

    final isSep = _isAccountSeparator(ch);

    if (isSep) {
      if (inRun) {
        sepStreak++;

        if (sepStreak >= 2) {
          flush();
          continue;
        }

        buf.write(ch);
      }

      continue;
    }

    sepStreak = 0;

    if (isRunChar(ch)) {
      if (!inRun) {
        runStart = i;
        inRun = true;
      }

      if (_isAsciiDigit(ch)) {
        runHasAsciiDigit = true;
      }

      buf.write(ch);
    } else {
      flush();
    }
  }

  flush();

  return out;
}

bool _looksLikeDate(String value, String lineLower) {
  if (_dateLikeSeparatedRe.hasMatch(value)) {
    return true;
  }

  final hasDateContext =
      lineLower.contains('date') ||
      lineLower.contains('txn') ||
      lineLower.contains('transaction');

  if (!hasDateContext) {
    return false;
  }

  if (value.length == 8) {
    final dd = int.tryParse(value.substring(0, 2));
    final mm = int.tryParse(value.substring(2, 4));

    if (dd != null &&
        mm != null &&
        dd >= 1 &&
        dd <= 31 &&
        mm >= 1 &&
        mm <= 12) {
      return true;
    }
  }

  return false;
}

bool _hasLowDigitDiversity(String s) {
  return s.split('').toSet().length <= 2;
}

bool _isRepeatingPattern(String s) {
  for (var size = 1; size <= s.length ~/ 2; size++) {
    if (s.length % size != 0) {
      continue;
    }

    final pattern = s.substring(0, size);

    var ok = true;

    for (var i = size; i < s.length; i += size) {
      if (s.substring(i, i + size) != pattern) {
        ok = false;
        break;
      }
    }

    if (ok) {
      return true;
    }
  }

  return false;
}

bool _isCyclicAscending(String s) {
  for (var i = 1; i < s.length; i++) {
    final prev = int.parse(s[i - 1]);
    final curr = int.parse(s[i]);
    if ((curr - prev + 10) % 10 != 1) {
      return false;
    }
  }
  return true;
}

bool _isSequentialDigits(String s) {
  if (s.length < 6) {
    return false;
  }

  if (_isCyclicAscending(s)) {
    return true;
  }

  var asc = true;
  var desc = true;

  for (var i = 1; i < s.length; i++) {
    final prev = int.parse(s[i - 1]);
    final curr = int.parse(s[i]);

    if (curr != prev + 1) {
      asc = false;
    }

    if (curr != prev - 1) {
      desc = false;
    }
  }

  return asc || desc;
}

bool _looksLikeAmount(String value) {
  if (value.length < 5) {
    return false;
  }

  final trailingZeros = RegExp(r'0+$').firstMatch(value)?.group(0)?.length ?? 0;

  if (trailingZeros < math.max(4, value.length ~/ 2)) {
    return false;
  }

  return value.startsWith('0') || (trailingZeros * 3 >= value.length * 2);
}

int accountKeywordScore(String lineLower) {
  var score = 0;

  if (lineLower.contains('account number')) {
    score += 22;
  }

  if (lineLower.contains('account no')) {
    score += 20;
  }

  if (lineLower.contains('a/c no')) {
    score += 20;
  }

  if (lineLower.contains('ac no')) {
    score += 18;
  }

  if (lineLower.contains('account')) {
    score += 10;
  }

  if (lineLower.contains('acct')) {
    score += 8;
  }

  if (lineLower.contains('sb a/c')) {
    score += 12;
  }

  if (RegExp(r'\bsb\b', caseSensitive: false).hasMatch(lineLower)) {
    score += 3;
  }

  if (lineLower.contains('holder')) {
    score += 2;
  }

  if (lineLower.contains('joint')) {
    score += 1;
  }

  return score;
}

int accountScore(String value, String lineLower, String? ifsc, int lineNumber) {
  var score = 0;

  score += math.max(0, 10 - lineNumber);

  score += accountKeywordScore(lineLower);

  final len = value.length;

  if (len >= 9 && len <= 18) {
    score += 8;
  }

  if (len >= 10 && len <= 16) {
    score += 4;
  }

  if (lineLower.contains('ifsc')) {
    score += 6;
  }

  if (_transactionWords.any(lineLower.contains)) {
    score -= 25;
  }

  if (_looksLikeDate(value, lineLower)) {
    score -= 45;
  }

  if (_isSequentialDigits(value)) {
    score -= 35;
  }

  if (_isRepeatingPattern(value)) {
    score -= 40;
  }

  if (_hasLowDigitDiversity(value)) {
    score -= 30;
  }

  if (_looksLikeAmount(value)) {
    score -= 20;
  }

  if (len == 10 &&
      _indianMobileRe.hasMatch(value) &&
      accountKeywordScore(lineLower) == 0) {
    score -= 18;
  }

  if (lineLower.contains('customer id') ||
      lineLower.contains('cif') ||
      lineLower.contains('user id')) {
    score -= 35;
  }

  if (ifsc != null && ifsc.replaceAll(_nonDigitRe, '').contains(value)) {
    score -= 40;
  }

  if (ifsc != null && value.length <= 6 && ifsc.contains(value)) {
    score -= 30;
  }

  return score;
}

const _snippetMax = 120;

String _snippet(String s) {
  final t = s.trim();
  if (t.length <= _snippetMax) {
    return t;
  }
  return '${t.substring(0, _snippetMax)}…';
}

({
  String? digits,
  double confidence,
  List<PassbookAccountCandidate> candidates,
  bool hadOcrCorrection,
  String? matchedLineSnippet,
  int? accountLineNumber,
})
findBestAccount(List<PassbookAccountCandidate> candidates, String? ifsc) {
  if (candidates.isEmpty) {
    return (
      digits: null,
      confidence: 0.0,
      candidates: const <PassbookAccountCandidate>[],
      hadOcrCorrection: false,
      matchedLineSnippet: null,
      accountLineNumber: null,
    );
  }

  PassbookAccountCandidate? best;

  var bestScore = -999999;

  for (final c in candidates) {
    final score = accountScore(
      c.normalizedText,
      c.lineText.toLowerCase(),
      ifsc,
      c.lineNumber,
    );

    if (score > bestScore ||
        (score == bestScore &&
            (best == null ||
                c.normalizedText.length >= best.normalizedText.length))) {
      bestScore = score;
      best = c;
    }
  }

  if (best == null) {
    return (
      digits: null,
      confidence: 0.0,
      candidates: candidates,
      hadOcrCorrection: false,
      matchedLineSnippet: null,
      accountLineNumber: null,
    );
  }

  double confidence;

  if (bestScore >= 52) {
    confidence = PassbookParseConfidence.accountStrong;
  } else if (bestScore >= 36) {
    confidence = PassbookParseConfidence.accountGood;
  } else if (bestScore >= 20) {
    confidence = PassbookParseConfidence.accountFair;
  } else if (bestScore >= 8) {
    confidence = PassbookParseConfidence.accountWeak;
  } else {
    confidence = PassbookParseConfidence.accountLow;
  }

  if (best.hadOcrCorrection) {
    confidence *= 0.94;
  }

  return (
    digits: best.normalizedText,
    confidence: confidence.clamp(0.0, 1.0).toDouble(),
    candidates: candidates,
    hadOcrCorrection: best.hadOcrCorrection,
    matchedLineSnippet: _snippet(best.lineText),
    accountLineNumber: best.lineNumber,
  );
}

String cleanOcr(String text) {
  return text
      .replaceAll('\t', ' ')
      .replaceAll(_cleanOcrControlCharsRe, ' ')
      .replaceAll(_cleanOcrSpacesRe, ' ')
      .replaceAll(_cleanOcrExcessNewlinesRe, '\n\n')
      .trim();
}

({List<ParsedLine> lines, String doc}) _preprocessPassbookText(String rawText) {
  final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final splits = normalized.split('\n');
  final lines = <ParsedLine>[];
  final sb = StringBuffer();
  var offset = 0;
  var parsedLineIndex = 0;

  for (
    var sourceLineIndex = 0;
    sourceLineIndex < splits.length;
    sourceLineIndex++
  ) {
    final trimmed = splits[sourceLineIndex].trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (sb.isNotEmpty) {
      sb.write('\n');
      offset++;
    }
    lines.add(
      _buildParsedLine(trimmed, sourceLineIndex, parsedLineIndex++, offset),
    );
    sb.write(trimmed);
    offset += trimmed.length;
  }

  return (lines: lines, doc: sb.toString());
}

String? _normalizePassbookHolderName(String? raw) {
  if (raw == null) {
    return null;
  }
  final t = raw.replaceAll('\t', ' ').trim();
  if (t.isEmpty) {
    return null;
  }
  return t.replaceAll(_wsRe, ' ');
}

bool _nameHeuristicTokenHasLetterDigitMix(String token) {
  final core = token.replaceAll(_alnumCompactRe, '');

  if (core.length < 2) {
    return false;
  }

  return _unicodeLetterRe.hasMatch(core) && _digitRe.hasMatch(core);
}

bool _nameHeuristicLineRejectedForOcrNoise(String t) {
  for (final w in t.split(_wsRe)) {
    if (w.isEmpty) {
      continue;
    }

    if (_nameHeuristicTokenHasLetterDigitMix(w)) {
      return true;
    }
  }

  return false;
}

({
  String? name,
  double confidence,
  String? strategy,
  String? matchedLineSnippet,
})
_holderNameNotFound() =>
    (name: null, confidence: 0.0, strategy: null, matchedLineSnippet: null);

bool _nameHeuristicLineExcluded(
  String line,
  String lower, {
  required String? ifscNorm,
  required String? accountDigits,
}) {
  if (_countBankNoiseTerms(lower) >= 2) {
    return true;
  }

  if (_lineHasInstitutionTerms(lower)) {
    return true;
  }

  for (final term in _nameHeuristicSkipTerms) {
    if (lower.contains(term)) {
      return true;
    }
  }

  final compact = line.replaceAll(_alnumCompactRe, '').toUpperCase();
  if (ifscNorm != null && ifscNorm.isNotEmpty && compact == ifscNorm) {
    return true;
  }

  if (accountDigits != null &&
      line.replaceAll(_nonDigitRe, '') == accountDigits) {
    return true;
  }

  if (lower.contains('account') &&
      _digitRe.hasMatch(line) &&
      line.replaceAll(_nonDigitRe, '').length >= 8) {
    return true;
  }

  return false;
}

/// Boosts name candidates on lines near the chosen account number line.
double _nameProximityToAccountScore(int lineNumber, int? accountLineNumber) {
  if (accountLineNumber == null) {
    return 0;
  }

  final distance = (lineNumber - accountLineNumber).abs();

  if (distance <= 2) {
    return 12;
  }
  if (distance <= 5) {
    return 5;
  }

  return 0;
}

final List<RegExp> _holderLabeledPatterns = [
  RegExp(
    r'^name\s+of\s+(?:the\s+)?(?:account\s+)?holder\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  ),
  RegExp(
    r'^name\s+of\s+(?:the\s+)?customer\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  ),
  RegExp(r'^name\s*[:\-#.]\s*(.+)$', caseSensitive: false),
  RegExp(
    r'^((?:mrs|miss|mr|ms|mx|dr|prof|shri|smt|sri|kumari|km)\.?\s+[A-Za-z].{0,80})$',
    caseSensitive: false,
  ),
  RegExp(
    r'^(?:customer\s+name|account\s*holder(?:\s*name)?|account\s*name|name|m\s*/\s*s|m/s)\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  ),
  RegExp(
    r'^(?:a\s*/\s*c|a/c)\s*(?:\s*\.\s*)?holder(?:\s*name)?\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  ),
  RegExp(
    r'^acc(?:ount|\.)?\s*holder(?:\s*name)?\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  ),
  RegExp(r'^beneficiary(?:\s+name)?\s*[:\-]?\s*(.+)$', caseSensitive: false),
  RegExp(r'^nominee(?:\s+name)?\s*[:\-]?\s*(.+)$', caseSensitive: false),
];

({
  String? name,
  double confidence,
  String? strategy,
  String? matchedLineSnippet,
})
_findAccountHolderName(
  List<ParsedLine> lines,
  String? accountDigits,
  String? ifscCode,
  int? accountLineNumber,
) {
  final labeledHits = <({ParsedLine pl, String name, int patternIdx})>[];

  for (final pl in lines) {
    final t = pl.normalized.trim();
    if (t.isEmpty) {
      continue;
    }

    for (var pi = 0; pi < _holderLabeledPatterns.length; pi++) {
      final labeled = _holderLabeledPatterns[pi];
      final m = labeled.firstMatch(t);
      if (m != null) {
        final n = _normalizePassbookHolderName(m.group(1));
        if (n != null && n.length >= 2) {
          labeledHits.add((pl: pl, name: n, patternIdx: pi));
          break;
        }
      }
    }
  }

  if (labeledHits.isNotEmpty) {
    double scoreLabeled(({ParsedLine pl, String name, int patternIdx}) h) {
      var s = 120.0 - h.patternIdx * 4;

      final lt = h.pl.normalized.toLowerCase();

      s += _nameProximityToAccountScore(h.pl.lineNumber, accountLineNumber);

      if (lt.contains('nominee')) {
        s -= 14;
      }
      if (lt.contains('guardian')) {
        s -= 8;
      }
      if (lt.contains('authorised') || lt.contains('authorized')) {
        s -= 6;
      }

      final trimmedName = h.name.trim();

      if (trimmedName.length >= 3 &&
          _titleCaseMultiWordRe.hasMatch(trimmedName)) {
        s += 6;
      }

      if (_honorificPrefixRe.hasMatch(trimmedName)) {
        s += 5;
      }

      s += math.min(trimmedName.length, 64) * 0.06;

      if (_leadingDigitRe.hasMatch(trimmedName)) {
        s -= 55;
      }

      if (trimmedName.replaceAll(_nonDigitRe, '').length >= 8 &&
          _countUnicodeLetters(trimmedName) <= 2) {
        s -= 40;
      }

      return s;
    }

    labeledHits.sort((a, b) => scoreLabeled(b).compareTo(scoreLabeled(a)));
    final best = labeledHits.first;
    final conf = best.patternIdx <= 2
        ? PassbookParseConfidence.labeledStrong
        : best.patternIdx == 3
        ? PassbookParseConfidence.labeledHonorific
        : PassbookParseConfidence.labeledDefault;

    return (
      name: best.name,
      confidence: conf,
      strategy: 'labeled',
      matchedLineSnippet: _snippet(best.pl.normalized),
    );
  }

  final ifscNorm = ifscCode?.replaceAll(_nonAlnumRe, '').toUpperCase();
  final heuristicCandidates = <({String text, double score, String snippet})>[];

  for (final pl in lines) {
    final t = pl.normalized.trim();
    if (t.length < 3 || t.length > 52) {
      continue;
    }

    if (_nameHeuristicLineExcluded(
      t,
      pl.lower,
      ifscNorm: ifscNorm,
      accountDigits: accountDigits,
    )) {
      continue;
    }

    final letters = _countUnicodeLetters(t);
    final nonSpaceLen = t.replaceAll(_wsRe, '').length;
    if (nonSpaceLen == 0) {
      continue;
    }

    final words = t.split(_wsRe).where((w) => w.isNotEmpty).toList();
    final alphaRatio = letters / nonSpaceLen;

    if (alphaRatio < 0.45 && words.length < 2) {
      continue;
    }

    if (_nameHeuristicLineRejectedForOcrNoise(t)) {
      continue;
    }

    var score = 0.0;
    score += words.length * 1.6;
    score += letters * 0.07;

    if (_unicodeLowerRe.hasMatch(t) && _unicodeUpperRe.hasMatch(t)) {
      score += 5;
    }
    if (words.length >= 2) {
      score += 3;
    }
    if (words.isNotEmpty &&
        words.every((w) => w.length <= 2 && _initialTokenRe.hasMatch(w))) {
      score += 5;
    }
    if (t == t.toUpperCase() && letters >= 3) {
      score += 4;
    }
    if (pl.lower.contains('holder') || pl.lower.contains('customer')) {
      score += 2;
    }
    if (t == t.toUpperCase() && t.length <= 2) {
      score -= 4;
    }

    score += _nameProximityToAccountScore(pl.lineNumber, accountLineNumber);

    heuristicCandidates.add((text: t, score: score, snippet: _snippet(t)));
  }

  if (heuristicCandidates.isEmpty) {
    return _holderNameNotFound();
  }
  heuristicCandidates.sort((a, b) => b.score.compareTo(a.score));
  final best = heuristicCandidates.first;
  if (best.score < 4) {
    return _holderNameNotFound();
  }

  return (
    name: _normalizePassbookHolderName(best.text),
    confidence: PassbookParseConfidence.heuristic,
    strategy: 'heuristic',
    matchedLineSnippet: best.snippet,
  );
}

BankDetails parsePassbook(String rawText) {
  final pre = _preprocessPassbookText(cleanOcr(rawText));
  final lines = pre.lines;
  final ifsc = findIfsc(lines);
  final cands = extractAccountCandidates(lines);
  final acc = findBestAccount(cands, ifsc.code);
  final name = _findAccountHolderName(
    lines,
    acc.digits,
    ifsc.code,
    acc.accountLineNumber,
  );
  final masked = _maskedAccountRe.firstMatch(pre.doc);

  return BankDetails(
    accountHolderName: name.name,
    accountNumberDigits: acc.digits,
    ifscCode: ifsc.code,
    ifscConfidence: ifsc.confidence,
    accountConfidence: acc.confidence,
    nameConfidence: name.confidence,
    accountCandidateCount: cands.length,
    accountExtractionStrategy: 'per-line+stitched+scored',
    accountMatchedLine: acc.matchedLineSnippet,
    accountOcrCorrected: acc.hadOcrCorrection,
    accountCandidates: acc.candidates,
    nameMatchStrategy: name.strategy,
    nameMatchedLine: name.matchedLineSnippet,
    maskedAccountNumber: masked?.group(0),
    isMaskedAccount: masked != null,
  );
}

/// Preprocesses OCR text the same way [parsePassbook] does (for unit tests).
List<ParsedLine> preprocessPassbookLinesForTest(String raw) =>
    _preprocessPassbookText(cleanOcr(raw)).lines;

/// Builds a [ParsedLine] for unit tests (precomputes cached fields).
ParsedLine parsedLineForTest(
  String normalized, {
  int lineNumber = 0,
  int parsedLineIndex = 0,
  int startInDoc = 0,
}) => _buildParsedLine(normalized, lineNumber, parsedLineIndex, startInDoc);
