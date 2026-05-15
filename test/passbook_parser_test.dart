import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/passbook_account_candidate.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/parsing/passbook_parser.dart';

void main() {
  group('cleanOcr', () {
    test('collapses extra spaces and preserves paragraph breaks', () {
      expect(
        cleanOcr('IFSC  SBIN0001234\n\n\nSavings'),
        'IFSC SBIN0001234\n\nSavings',
      );
    });

    test('preserves Unicode letters and strips control characters', () {
      final nbsp = String.fromCharCode(0xA0);
      expect(cleanOcr('Name:${nbsp}Riya'), 'Name:${nbsp}Riya');
      expect(cleanOcr('hello\u{200B}world'), 'hello\u{200B}world');
      expect(cleanOcr('line\u{0007}break'), 'line break');
    });

    test('strips BOM and trims', () {
      expect(cleanOcr('\u{FEFF}  IFSC SBIN0001234  '), 'IFSC SBIN0001234');
    });

    test('parsePassbook applies cleanOcr before parsing', () {
      final nbsp = String.fromCharCode(0xA0);
      final d = parsePassbook('IFSC${nbsp}SBIN0001234');
      expect(d.ifscCode, 'SBIN0001234');
    });
  });

  group('findIfsc', () {
    test('extracts exact IFSC', () {
      final lines = [
        parsedLineForTest('IFSC SBIN0001234', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0001234');
      expect(result.confidence, 1.0);
    });

    test('normalizes OCR characters in IFSC', () {
      final lines = [
        parsedLineForTest('IFSC SBINOO01234', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0001234');
      expect(result.confidence, 0.86);
    });

    test('finds compact IFSC with spaces', () {
      final lines = [
        parsedLineForTest('IFSC SBIN 0001234', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0001234');
      expect(result.confidence, 0.97);
    });

    test('finds lowercase IFSC', () {
      final lines = [
        parsedLineForTest('ifsc sbin0aa1234', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0AA1234');
    });

    test('does not corrupt branch letters away from digits', () {
      final lines = [
        parsedLineForTest('IFSC SBIN0ABSZ12', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, isNot('SBIN0A85212'));
    });

    test('aggressively maps B/S/Z in digit-heavy IFSC tail', () {
      final lines = [
        parsedLineForTest('IFSC SBIN000B234', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0008234');
    });

    test('returns null when IFSC absent', () {
      final lines = [
        parsedLineForTest('No code here', lineNumber: 0, startInDoc: 0),
      ];

      final result = findIfsc(lines);

      expect(result.code, isNull);
      expect(result.confidence, 0.0);
    });

    test('finds IFSC on labeled line when branch has only three digits', () {
      final lines = [
        parsedLineForTest(
          'IFSC CODE SBIN000ABC1',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN000ABC1');
      expect(result.confidence, greaterThan(0.85));
    });

    test('does not join separate lines to invent an IFSC', () {
      final lines = [
        parsedLineForTest('IFSC Code', lineNumber: 0, startInDoc: 0),
        parsedLineForTest('SBIN000', lineNumber: 1, startInDoc: 9),
        parsedLineForTest('1234', lineNumber: 2, startInDoc: 16),
      ];

      final result = findIfsc(lines);

      expect(result.code, isNull);
      expect(result.confidence, 0.0);
    });

    test('finds IFSC after IFSC Code label with colon', () {
      final lines = [
        parsedLineForTest(
          'IFSC Code: SBIN0001234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      expect(findIfsc(lines).code, 'SBIN0001234');
    });

    test('finds IFSC after IFSC-CODE hyphen label', () {
      final lines = [
        parsedLineForTest(
          'IFSC-CODE SBIN0001234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      expect(findIfsc(lines).code, 'SBIN0001234');
    });

    test('finds IFSC after IFSC slash Code label', () {
      final lines = [
        parsedLineForTest(
          'IFSC / Code SBIN0001234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      expect(findIfsc(lines).code, 'SBIN0001234');
    });

    test('finds IFSC when label is preceded by branch text', () {
      final lines = [
        parsedLineForTest(
          'Main Branch IFSC Code SBIN0001234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      expect(findIfsc(lines).code, 'SBIN0001234');
    });
  });

  group('normalizeAccountRun', () {
    test('normalizes simple OCR chars', () {
      final result = normalizeAccountRun('12O45I789012');

      expect(result.digits, '120451789012');
      expect(result.hadOcrCorrection, true);
    });

    test('normalizes aggressive OCR chars when surrounded by digits', () {
      final result = normalizeAccountRun(
        '30201S234568',
        allowAggressiveShapeCorrection: true,
      );

      expect(result.digits, '302015234568');
      expect(result.hadOcrCorrection, true);
    });

    test('skips aggressive OCR at run end without digit neighbor', () {
      final result = normalizeAccountRun(
        '30201S23456B',
        allowAggressiveShapeCorrection: true,
      );

      expect(result.digits, '30201523456');
    });

    test('does not map S or B to digits without aggressive flag', () {
      final result = normalizeAccountRun('30201S23456B');

      expect(result.digits, '3020123456');
      expect(result.hadOcrCorrection, false);
    });

    test('keeps normal digits unchanged', () {
      final result = normalizeAccountRun('302012345678');

      expect(result.digits, '302012345678');
      expect(result.hadOcrCorrection, false);
    });
  });

  group('extractAccountCandidates', () {
    test('extracts valid account candidates', () {
      final lines = [
        parsedLineForTest(
          'Savings Account 302012345678',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.length, 1);
      expect(result.first.normalizedText, '302012345678');
    });

    test('splits runs on double spaces', () {
      final lines = [
        parsedLineForTest(
          '302012345678  111111111',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.length, 2);

      expect(result[0].normalizedText, '302012345678');
      expect(result[1].normalizedText, '111111111');
    });

    test('supports OCR correction inside candidate extraction', () {
      final lines = [
        parsedLineForTest(
          'Savings Account 12O45I789012',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.first.normalizedText, '120451789012');
      expect(result.first.hadOcrCorrection, true);
    });

    test('treats S as digit on digit-heavy run without account label', () {
      final lines = [
        parsedLineForTest('PNR 30201S23456', lineNumber: 0, startInDoc: 0),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.length, 1);
      expect(result.first.normalizedText, '30201523456');
    });

    test('treats S as digit inside run when line has a/c', () {
      final lines = [
        parsedLineForTest('A/c no 30201S234568', lineNumber: 0, startInDoc: 0),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.length, 1);
      expect(result.first.normalizedText, '302015234568');
      expect(result.first.hadOcrCorrection, true);
    });

    test('stitches account split across label and two lines', () {
      final lines = [
        parsedLineForTest('Account No :', lineNumber: 0, startInDoc: 0),
        parsedLineForTest('123456', lineNumber: 1, startInDoc: 13),
        parsedLineForTest('789012', lineNumber: 2, startInDoc: 19),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.any((c) => c.normalizedText == '123456789012'), isTrue);
    });

    test('stitches partial account on label line with next line', () {
      final lines = [
        parsedLineForTest('Account No : 123456', lineNumber: 0, startInDoc: 0),
        parsedLineForTest('789012', lineNumber: 1, startInDoc: 20),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.any((c) => c.normalizedText == '123456789012'), isTrue);
    });

    test('parsePassbook recovers cross-line account number', () {
      const raw = '''
IFSC SBIN0001234
Account No :
123456
789012
Name: Test User
''';
      final d = parsePassbook(raw);
      expect(d.accountNumberDigits, '123456789012');
      expect(d.ifscCode, 'SBIN0001234');
    });

    test('extracts slash-separated account number', () {
      final lines = [
        parsedLineForTest(
          'A/C NO : 1234/5678/9012',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.length, 1);
      expect(result.first.normalizedText, '123456789012');
    });

    test('deduplicates identical account candidates', () {
      final lines = [
        parsedLineForTest('Account 302012345678', lineNumber: 0, startInDoc: 0),
        parsedLineForTest('302012345678', lineNumber: 1, startInDoc: 20),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.length, 1);
      expect(result.first.normalizedText, '302012345678');
    });

    test('ignores short digit runs', () {
      final lines = [parsedLineForTest('12345', lineNumber: 0, startInDoc: 0)];

      final result = extractAccountCandidates(lines);

      expect(result, isEmpty);
    });
  });

  group('accountScore', () {
    test('boosts account keyword lines', () {
      final score = accountScore(
        '302012345678',
        'savings account 302012345678',
        'SBIN0001234',
        0,
      );

      expect(score, greaterThan(20));
    });

    test('penalizes transaction lines', () {
      final score = accountScore(
        '9876543210123456',
        'utr 9876543210123456',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });

    test('penalizes mobile numbers without account keywords', () {
      final score = accountScore(
        '9876543210',
        'phone 9876543210',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });

    test('penalizes sequential digits', () {
      final score = accountScore(
        '123456789012',
        'savings account',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });

    test('penalizes repeating patterns', () {
      final score = accountScore(
        '909090909090',
        'savings account',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });

    test('penalizes low diversity numbers', () {
      final score = accountScore(
        '11112222',
        'savings account',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });

    test('penalizes amount-like values', () {
      final score = accountScore('5000000000', 'balance', 'SBIN0001234', 0);

      expect(score, lessThan(0));
    });

    test('penalizes date-like values with date context', () {
      final score = accountScore(
        '01012024',
        'transaction date',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });

    test('penalizes customer id lines', () {
      final score = accountScore(
        '1234567890',
        'customer id 1234567890',
        'SBIN0001234',
        0,
      );

      expect(score, lessThan(0));
    });
  });

  group('findBestAccount', () {
    test('selects best account candidate', () {
      final candidates = [
        const PassbookAccountCandidate(
          rawText: '9876543210',
          normalizedText: '9876543210',
          hadOcrCorrection: false,
          lineNumber: 0,
          startInDoc: 0,
          lineText: 'Phone 9876543210',
        ),
        const PassbookAccountCandidate(
          rawText: '302012345678',
          normalizedText: '302012345678',
          hadOcrCorrection: false,
          lineNumber: 1,
          startInDoc: 10,
          lineText: 'Savings Account 302012345678',
        ),
      ];

      final result = findBestAccount(candidates, 'SBIN0001234');

      expect(result.digits, '302012345678');
      expect(result.confidence, greaterThan(0.75));
    });

    test('reduces confidence when OCR correction used', () {
      final candidates = [
        const PassbookAccountCandidate(
          rawText: '12O45I789012',
          normalizedText: '120451789012',
          hadOcrCorrection: true,
          lineNumber: 0,
          startInDoc: 0,
          lineText: 'Savings Account 12O45I789012',
        ),
      ];

      final result = findBestAccount(candidates, 'SBIN0001234');

      expect(result.digits, '120451789012');
      expect(result.confidence, lessThan(0.96));
    });

    test('prefers longer candidate on score tie', () {
      final candidates = [
        const PassbookAccountCandidate(
          rawText: '123456789',
          normalizedText: '123456789',
          hadOcrCorrection: false,
          lineNumber: 0,
          startInDoc: 0,
          lineText: 'Savings Account 123456789',
        ),
        const PassbookAccountCandidate(
          rawText: '302012345678',
          normalizedText: '302012345678',
          hadOcrCorrection: false,
          lineNumber: 0,
          startInDoc: 20,
          lineText: 'Savings Account 302012345678',
        ),
      ];

      final result = findBestAccount(candidates, 'SBIN0001234');

      expect(result.digits, '302012345678');
    });

    test('returns null when candidate list empty', () {
      final result = findBestAccount([], 'SBIN0001234');

      expect(result.digits, isNull);
      expect(result.confidence, 0.0);
    });
  });

  group('parsePassbook', () {
    test('extracts IFSC, account, and labeled holder on synthetic OCR', () {
      const raw = '''
IFSC SBIN0001234
Savings Account 302012345678
Account Holder: Riya Sharma
''';
      final d = parsePassbook(raw);
      expect(d.ifscCode, 'SBIN0001234');
      expect(d.accountNumberDigits, '302012345678');
      expect(d.accountHolderName, contains('Riya'));
      expect(d.accountCandidates, isNotEmpty);
    });

    test('nullable fields when only IFSC is present', () {
      const raw = 'IFSC YESB0000456';
      final d = parsePassbook(raw);
      expect(d.ifscCode, 'YESB0000456');
      expect(d.accountNumberDigits, isNull);
      expect(d.accountHolderName, isNull);
      expect(d.accountCandidates, isEmpty);
    });

    test('prefers account holder over nominee when both are labeled', () {
      const raw = '''
Account Holder: Riya Sharma
SB A/c 302012345678
Nominee: Not This Person
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'Riya Sharma');
      expect(d.accountNumberDigits, '302012345678');
    });

    test('parses name of account holder label', () {
      const raw = '''
Name of Account Holder : Amit Verma
Savings Account 302012345678
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'Amit Verma');
      expect(d.accountNumberDigits, '302012345678');
    });

    test('parses Name colon with honorific', () {
      const raw = '''
IFSC SBIN0001234
Name: Mr. Rajesh Kumar
A/c 302012345678
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'Mr. Rajesh Kumar');
      expect(d.accountNumberDigits, '302012345678');
    });

    test('parses stand-alone Mrs line as holder', () {
      const raw = '''
IFSC SBIN0001234
Mrs. Ananya Sen
Savings 302012345678
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'Mrs. Ananya Sen');
      expect(d.accountNumberDigits, '302012345678');
    });

    test('heuristic rejects letter-digit OCR noise as holder name', () {
      const raw = '''
IFSC SBIN0001234
Savings Account 302012345678
M1CHA3L KUM4R
''';
      final d = parsePassbook(raw);
      expect(d.accountNumberDigits, '302012345678');
      expect(d.accountHolderName, isNull);
    });

    test('heuristic picks clean multi-word name without label', () {
      const raw = '''
IFSC SBIN0001234
Savings Account 302012345678
Michael Kumar
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'Michael Kumar');
    });

    test('heuristic accepts uppercase initials style name', () {
      const raw = '''
IFSC SBIN0001234
S RINIVASAN
Savings Account 302012345678
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'S RINIVASAN');
    });

    test('heuristic prefers name near account line over distant line', () {
      const raw = '''
STATE BANK OF INDIA MAIN BRANCH MUMBAI
IFSC SBIN0001234
Michael Kumar
Savings Account 302012345678
''';
      final d = parsePassbook(raw);
      expect(d.accountNumberDigits, '302012345678');
      expect(d.accountHolderName, 'Michael Kumar');
    });

    test('parses A/C holder label and collapses extra spaces', () {
      const raw = '''
IFSC HDFC0001234
A/C  Holder  :  Amit   Verma
''';
      final d = parsePassbook(raw);
      expect(d.ifscCode, 'HDFC0001234');
      expect(d.accountHolderName, 'Amit Verma');
    });

    test('rejects branch line as holder via institution terms', () {
      const raw = '''
IFSC SBIN0001234
State Bank of India Main Branch
Savings Account 302012345678
Riya Sharma
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'Riya Sharma');
    });

    test('parses Unicode holder name heuristically', () {
      const raw = '''
IFSC SBIN0001234
Savings Account 302012345678
रिया शर्मा
''';
      final d = parsePassbook(raw);
      expect(d.accountHolderName, 'रिया शर्मा');
    });

    test('detects masked account with spaced X mask', () {
      const raw = '''
IFSC SBIN0001234
Account X X X X 5678
''';
      final d = parsePassbook(raw);
      expect(d.isMaskedAccount, isTrue);
      expect(d.maskedAccountNumber, isNotNull);
    });

    test('physical lineNumber skips blank source lines', () {
      const raw = 'Line A\n\nLine B';
      final pre = preprocessPassbookLinesForTest(raw);
      expect(pre.length, 2);
      expect(pre[0].lineNumber, 0);
      expect(pre[1].lineNumber, 2);
    });
  });

  group('parser improvements', () {
    test('finds spaced IFSC on non-label line', () {
      final lines = [parsedLineForTest('SBIN 0 001234', lineNumber: 0)];

      expect(findIfsc(lines).code, 'SBIN0001234');
    });

    test('findBestAccount applies multiplicative OCR confidence penalty', () {
      final candidates = [
        const PassbookAccountCandidate(
          rawText: '12O45I789012',
          normalizedText: '120451789012',
          hadOcrCorrection: true,
          lineNumber: 0,
          startInDoc: 0,
          lineText: 'Savings Account 12O45I789012',
        ),
      ];

      final result = findBestAccount(candidates, 'SBIN0001234');
      final uncorrected = findBestAccount([
        const PassbookAccountCandidate(
          rawText: '302012345678',
          normalizedText: '302012345678',
          hadOcrCorrection: false,
          lineNumber: 0,
          startInDoc: 0,
          lineText: 'Savings Account 302012345678',
        ),
      ], 'SBIN0001234');

      expect(result.confidence, closeTo(uncorrected.confidence * 0.94, 0.001));
    });

    test('filters UPI reference before candidate list', () {
      final lines = [parsedLineForTest('UPI ref 123456789012', lineNumber: 0)];

      expect(extractAccountCandidates(lines), isEmpty);
    });
  });
}
