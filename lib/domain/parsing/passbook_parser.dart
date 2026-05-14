import 'dart:math' as math;

import 'package:ocr_scanner_app/domain/entities/bank_details.dart';
import 'package:ocr_scanner_app/domain/entities/passbook_account_candidate.dart';

final _dateLikeSeparatedRe = RegExp(r'^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}$');
final _nonAlnumRe = RegExp(r'[^A-Z0-9]');
final _nonDigitRe = RegExp(r'\D');
final _ifscLooseRe = RegExp(r'\b[A-Z]{4}[A-Z0-9]{7}\b');
final _ifscAnchorRe = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final _indianMobileRe = RegExp(r'^[6-9]\d{9}$');

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

String _compactAlphaNum(String s) => s.replaceAll(_nonAlnumRe, '');

class ParsedLine {
  const ParsedLine({
    required this.raw,
    required this.normalized,
    required this.lineNumber,
    required this.startInDoc,
  });

  final String raw;
  final String normalized;
  final int lineNumber;
  final int startInDoc;
}

String _normalizeIfscOcr(String token) {
  final tailPart = token.length >= 11 ? token.substring(5) : '';
  final aggressiveTail = _isDigitHeavyIfscTail(tailPart);

  final b = StringBuffer();

  for (var i = 0; i < token.length; i++) {
    final c = token[i];

    if (i < 4) {
      b.write(c);
      continue;
    }

    if (i == 4) {
      b.write(_ifscFifthChar(c));
      continue;
    }

    if (aggressiveTail) {
      final aggressive = _ifscTailAggressiveShapeToDigit(c);

      if (aggressive != null) {
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

  return digits / tail.length >= 0.7;
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
  switch (c) {
    case 'O':
    case 'o':
    case 'D':
    case 'Q':
      return '0';

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

String? _ifscTailAggressiveShapeToDigit(String c) {
  switch (c) {
    case 'B':
    case 'b':
      return '8';

    case 'S':
    case 's':
      return '5';

    case 'Z':
    case 'z':
      return '2';

    default:
      return null;
  }
}

({String? code, double confidence}) findIfsc(List<ParsedLine> lines) {
  for (final pl in lines) {
    final normalized = pl.normalized
        .toUpperCase()
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ');

    for (final m in _ifscLooseRe.allMatches(normalized)) {
      final raw = m.group(0)!;

      if (raw.length != 11) {
        continue;
      }

      final fixed = _normalizeIfscOcr(raw);

      if (_ifscAnchorRe.hasMatch(fixed)) {
        return (
          code: fixed,
          confidence: _ifscAnchorRe.hasMatch(raw) ? 1.0 : 0.86,
        );
      }
    }

    final compact = _compactAlphaNum(normalized);

    for (var i = 0; i + 11 <= compact.length; i++) {
      final token = compact.substring(i, i + 11);

      final fixed = _normalizeIfscOcr(token);

      if (_ifscAnchorRe.hasMatch(fixed)) {
        return (code: fixed, confidence: 0.72);
      }
    }
  }

  return (code: null, confidence: 0.0);
}

int? _accountOcrToDigit(String c) {
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

int? _accountAggressiveShapeToDigit(String c) {
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

    if (ch == ' ' || ch == '-') {
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

    if (ch == ' ' || ch == '-') {
      continue;
    }

    total++;

    if (!_isAsciiDigit(ch)) {
      noisy++;
    }
  }

  return total > 0 && noisy / total > 0.35;
}

({String digits, bool hadOcrCorrection}) normalizeAccountRun(String run) {
  final aggressive =
      _isDigitHeavyAccountRun(run) && !_hasTooManyNonDigitShapes(run);

  final b = StringBuffer();
  var corrected = false;

  for (var i = 0; i < run.length; i++) {
    final ch = run[i];

    if (ch == ' ' || ch == '-') {
      continue;
    }

    if (_isAsciiDigit(ch)) {
      b.write(ch);
      continue;
    }

    if (aggressive) {
      final aggressiveDigit = _accountAggressiveShapeToDigit(ch);

      if (aggressiveDigit != null) {
        corrected = true;
        b.write(aggressiveDigit);
        continue;
      }
    }

    final d = _accountOcrToDigit(ch);

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

  if (c == ' ' || c == '-') {
    return true;
  }

  if (c == 'o' && !allowLowercaseOAsZero) {
    return false;
  }

  return _accountOcrToDigit(c) != null;
}

List<PassbookAccountCandidate> extractAccountCandidates(
  List<ParsedLine> lines,
) {
  final out = <PassbookAccountCandidate>[];

  for (final pl in lines) {
    final line = pl.normalized;

    if (line.isEmpty) {
      continue;
    }

    final local = _extractAccountCandidatesFromLine(line);

    for (final c in local) {
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

    final norm = normalizeAccountRun(run);

    if (norm.digits.length >= 9 && norm.digits.length <= 18) {
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

    if (ch == ' ' || ch == '-') {
      return true;
    }

    if (inRun &&
        runHasAsciiDigit &&
        _accountAggressiveShapeToDigit(ch) != null) {
      return true;
    }

    return _isAccountRunChar(
      ch,
      allowLowercaseOAsZero: inRun && runHasAsciiDigit,
    );
  }

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];

    final isSep = ch == ' ' || ch == '-';

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
})
findBestAccount(List<PassbookAccountCandidate> candidates, String? ifsc) {
  if (candidates.isEmpty) {
    return (
      digits: null,
      confidence: 0.0,
      candidates: const <PassbookAccountCandidate>[],
      hadOcrCorrection: false,
      matchedLineSnippet: null,
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
    );
  }

  double confidence;

  if (bestScore >= 52) {
    confidence = 0.96;
  } else if (bestScore >= 36) {
    confidence = 0.88;
  } else if (bestScore >= 20) {
    confidence = 0.78;
  } else if (bestScore >= 8) {
    confidence = 0.64;
  } else {
    confidence = 0.48;
  }

  if (best.hadOcrCorrection) {
    confidence -= 0.06;
  }

  return (
    digits: best.normalizedText,
    confidence: confidence.clamp(0.0, 1.0).toDouble(),
    candidates: candidates,
    hadOcrCorrection: best.hadOcrCorrection,
    matchedLineSnippet: _snippet(best.lineText),
  );
}

({List<ParsedLine> lines, String doc}) _preprocessPassbookText(String rawText) {
  var normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  normalized = normalized
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ')
      .replaceAll('\u2007', ' ')
      .replaceAll('\t', ' ');

  final splits = normalized.split('\n');
  final lines = <ParsedLine>[];
  final sb = StringBuffer();
  var offset = 0;

  for (var i = 0; i < splits.length; i++) {
    final trimmed = splits[i].trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (sb.isNotEmpty) {
      sb.write('\n');
      offset++;
    }
    lines.add(
      ParsedLine(
        raw: trimmed,
        normalized: trimmed,
        lineNumber: lines.length,
        startInDoc: offset,
      ),
    );
    sb.write(trimmed);
    offset += trimmed.length;
  }

  return (lines: lines, doc: sb.toString());
}

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
) {
  final labeled = RegExp(
    r'^(?:customer\s+name|account\s*holder(?:\s*name)?|account\s*name|name|m\s*/\s*s|m/s)\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  );

  for (final pl in lines) {
    final t = pl.normalized.trim();
    if (t.isEmpty) {
      continue;
    }

    final m = labeled.firstMatch(t);
    if (m != null) {
      final n = m.group(1)?.trim();
      if (n != null && n.length >= 2) {
        return (
          name: n,
          confidence: 0.9,
          strategy: 'labeled',
          matchedLineSnippet: _snippet(t),
        );
      }
    }
  }

  final ifscNorm = ifscCode?.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

  for (final pl in lines) {
    final t = pl.normalized.trim();
    if (t.length < 3 || t.length > 48) {
      continue;
    }

    final lower = t.toLowerCase();
    if (lower.contains('ifsc') ||
        lower.contains('branch code') ||
        lower.contains('micr')) {
      continue;
    }
    if (lower.contains('bank of') || lower.contains('state bank')) {
      continue;
    }

    final compact = t.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (ifscNorm != null &&
        ifscNorm.isNotEmpty &&
        compact == ifscNorm) {
      continue;
    }

    if (accountDigits != null &&
        t.replaceAll(RegExp(r'\D'), '') == accountDigits) {
      continue;
    }

    if (lower.contains('account') &&
        RegExp(r'\d').hasMatch(t) &&
        t.replaceAll(RegExp(r'\D'), '').length >= 8) {
      continue;
    }

    final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final nonSpaceLen = t.replaceAll(RegExp(r'\s'), '').length;
    if (nonSpaceLen == 0) {
      continue;
    }
    if (letters.length < nonSpaceLen * 0.25) {
      continue;
    }

    return (
      name: t,
      confidence: 0.72,
      strategy: 'heuristic',
      matchedLineSnippet: _snippet(t),
    );
  }

  return (
    name: null,
    confidence: 0.0,
    strategy: null,
    matchedLineSnippet: null,
  );
}

BankDetails parsePassbook(String rawText) {
  final pre = _preprocessPassbookText(rawText);
  final lines = pre.lines;
  final ifsc = findIfsc(lines);
  final cands = extractAccountCandidates(lines);
  final acc = findBestAccount(cands, ifsc.code);
  final name = _findAccountHolderName(lines, acc.digits, ifsc.code);
  final masked = RegExp(
    r'(?:X|\*){2,}[0-9]{4,}',
    caseSensitive: false,
  ).firstMatch(pre.doc);

  return BankDetails(
    accountHolderName: name.name,
    accountNumberDigits: acc.digits,
    ifscCode: ifsc.code,
    ifscConfidence: ifsc.confidence,
    accountConfidence: acc.confidence,
    nameConfidence: name.confidence,
    accountCandidateCount: cands.length,
    accountExtractionStrategy: 'per-line+scored',
    accountMatchedLine: acc.matchedLineSnippet,
    accountOcrCorrected: acc.hadOcrCorrection,
    accountCandidates: acc.candidates,
    nameMatchStrategy: name.strategy,
    nameMatchedLine: name.matchedLineSnippet,
    maskedAccountNumber: masked?.group(0),
    isMaskedAccount: masked != null,
  );
}
