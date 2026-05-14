import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/domain/entities/passbook_account_candidate.dart';
import 'package:ocr_scanner_app/domain/parsing/passbook_parser.dart';

void main() {
  group('findIfsc', () {
    test('extracts exact IFSC', () {
      final lines = [
        const ParsedLine(
          raw: 'IFSC SBIN0001234',
          normalized: 'IFSC SBIN0001234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0001234');
      expect(result.confidence, 1.0);
    });

    test('normalizes OCR characters in IFSC', () {
      final lines = [
        const ParsedLine(
          raw: 'IFSC SBINOO01234',
          normalized: 'IFSC SBINOO01234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0001234');
      expect(result.confidence, 0.86);
    });

    test('finds compact IFSC with spaces', () {
      final lines = [
        const ParsedLine(
          raw: 'IFSC SBIN 0001234',
          normalized: 'IFSC SBIN 0001234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0001234');
      expect(result.confidence, 0.72);
    });

    test('finds lowercase IFSC', () {
      final lines = [
        const ParsedLine(
          raw: 'ifsc sbin0aa1234',
          normalized: 'ifsc sbin0aa1234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0AA1234');
    });

    test('aggressively maps B/S/Z in digit-heavy IFSC tail', () {
      final lines = [
        const ParsedLine(
          raw: 'IFSC SBIN000B234',
          normalized: 'IFSC SBIN000B234',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, 'SBIN0008234');
    });

    test('returns null when IFSC absent', () {
      final lines = [
        const ParsedLine(
          raw: 'No code here',
          normalized: 'No code here',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = findIfsc(lines);

      expect(result.code, isNull);
      expect(result.confidence, 0.0);
    });
  });

  group('normalizeAccountRun', () {
    test('normalizes simple OCR chars', () {
      final result = normalizeAccountRun('12O45I789012');

      expect(result.digits, '120451789012');
      expect(result.hadOcrCorrection, true);
    });

    test('normalizes aggressive OCR chars on digit-heavy runs', () {
      final result = normalizeAccountRun('30201S23456B');

      expect(result.digits, '302015234568');
      expect(result.hadOcrCorrection, true);
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
        const ParsedLine(
          raw: 'Savings Account 302012345678',
          normalized: 'Savings Account 302012345678',
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
        const ParsedLine(
          raw: '302012345678  111111111',
          normalized: '302012345678  111111111',
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
        const ParsedLine(
          raw: 'Savings Account 12O45I789012',
          normalized: 'Savings Account 12O45I789012',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

      final result = extractAccountCandidates(lines);

      expect(result.first.normalizedText, '120451789012');
      expect(result.first.hadOcrCorrection, true);
    });

    test('ignores short digit runs', () {
      final lines = [
        const ParsedLine(
          raw: '12345',
          normalized: '12345',
          lineNumber: 0,
          startInDoc: 0,
        ),
      ];

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
  });
}
