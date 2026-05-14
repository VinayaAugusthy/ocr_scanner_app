import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/domain/parsing/card_parser.dart';

void main() {
  group('parseCard', () {
    test('extracts PAN, expiry, and holder from noisy OCR text', () {
      const raw = '''
JANE DOE
4532 0151 1283 0366
Valid Thru 12/29
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4532015112830366');
      expect(d.luhnValid, isTrue);
      expect(d.expiryMonth, 12);
      expect(d.expiryYearYY, 29);
      expect(d.holderName, contains('JANE'));
    });

    test('maps OCR O to 0 inside digit run', () {
      const raw = '''
4532 O151 1283 O366
12-29
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4532015112830366');
      expect(d.luhnValid, isTrue);
    });

    test('maps OCR I to 1 inside PAN', () {
      const raw = '''
4I11 1111 1111 1111
12/29
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4111111111111111');
      expect(d.luhnValid, isTrue);
    });

    test('detects MMYY expiry when labelled', () {
      const raw = '''
4242424242424242
EXP 1228
''';

      final d = parseCard(raw);

      expect(d.expiryMonth, 12);
      expect(d.expiryYearYY, 28);
    });

    test('extracts expiry with hyphen separator', () {
      const raw = '''
4242424242424242
VALID THRU 08-30
''';

      final d = parseCard(raw);

      expect(d.expiryMonth, 8);
      expect(d.expiryYearYY, 30);
    });

    test('extracts expiry with 4-digit year', () {
      const raw = '''
4111111111111111
VALID THRU 12/2029
''';

      final d = parseCard(raw);

      expect(d.expiryMonth, 12);
      expect(d.expiryYearYY, 29);
    });

    test('ignores invalid expiry month', () {
      const raw = '''
4111111111111111
13/29
''';

      final d = parseCard(raw);

      expect(d.expiryMonth, isNull);
      expect(d.expiryYearYY, isNull);
    });

    test('prefers Luhn-valid PAN among several digit runs', () {
      const raw = '''
9876543210
4242 4242 4242 4242
01/30
Alex River
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4242424242424242');
      expect(d.luhnValid, isTrue);
      expect(d.holderName, contains('Alex'));
    });

    test('returns null PAN when no candidate passes Luhn', () {
      const raw = '''
4242424242424241
11/30
NO NAME HERE
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, isNull);
      expect(d.luhnValid, isFalse);
    });

    test('normalizes NBSP and tabs before extracting PAN', () {
      const raw = '4532\u00A00151\t1283 0366';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4532015112830366');
    });

    test('drops expired expiry dates', () {
      const raw = '''
4242424242424242
Valid 01/25
''';

      final d = parseCard(raw);

      expect(d.expiryMonth, isNull);
      expect(d.expiryYearYY, isNull);
    });

    test('detects payment network from PAN prefix', () {
      expect(parseCard('4242424242424242').paymentNetwork, 'Visa');

      expect(parseCard('5555555555554444').paymentNetwork, 'Mastercard');
    });

    test('supports Mastercard 2-series BIN', () {
      const raw = '''
2223000048400011
12/30
''';

      final d = parseCard(raw);

      expect(d.paymentNetwork, 'Mastercard');
      expect(d.luhnValid, isTrue);
    });

    test('extracts American Express correctly', () {
      const raw = '''
378282246310005
09/31
KIRAN PATEL
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '378282246310005');
      expect(d.paymentNetwork, 'American Express');
      expect(d.expiryMonth, 9);
      expect(d.expiryYearYY, 31);
      expect(d.luhnValid, isTrue);
    });

    test('handles missing holder and expiry gracefully', () {
      const raw = '4242424242424242';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4242424242424242');
      expect(d.holderName, isNull);
      expect(d.expiryMonth, isNull);
      expect(d.expiryYearYY, isNull);
    });

    test('does not treat expiry line as holder name', () {
      const raw = '''
4242424242424242
12/29
VALID THRU
''';

      final d = parseCard(raw);

      expect(d.holderName, isNull);
    });

    test('does not treat card brand as holder name', () {
      const raw = '''
VISA PLATINUM
4242424242424242
12/29
''';

      final d = parseCard(raw);

      expect(d.holderName, isNull);
    });

    test('does not treat EXP plus digits line as holder name', () {
      const raw = '''
4242424242424242
EXP 1228
JANE DOE
12/29
''';

      final d = parseCard(raw);

      expect(d.holderName, 'JANE DOE');
    });

    test('does not choose brand-only line as holder over real name', () {
      const raw = '''
VISA GOLD
JOHN SMITH
4111111111111111
12/29
''';

      final d = parseCard(raw);

      expect(d.holderName, 'JOHN SMITH');
    });

    test('extracts PAN with mixed separators', () {
      const raw = '''
4242-4242 4242-4242
12/29
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4242424242424242');
    });

    test('extracts PAN without spaces', () {
      const raw = '''
4111111111111111
12/29
JOHN DOE
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4111111111111111');
      expect(d.luhnValid, isTrue);
    });

    test('handles lowercase OCR letters in PAN', () {
      const raw = '''
41l1 1111 1111 1111
12/29
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4111111111111111');
    });

    test('handles OCR B as 8 in aggressive digit run', () {
      const raw = '''
4242 4242 4242 42B2
12/29
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, isNotNull);
    });

    test('ignores short numeric runs', () {
      const raw = '''
Ref 12345678
Mobile 9876543210
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, isNull);
    });

    test('ignores PAN-like number embedded in text', () {
      const raw = '''
Transaction Ref: 4242424242424242XYZ
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, isNull);
    });

    test('removes PAN before expiry compact scan', () {
      const raw = '''
4242424242421229
EXP 10/30
''';

      final d = parseCard(raw);

      expect(d.expiryMonth, 10);
      expect(d.expiryYearYY, 30);
    });

    test('returns null payment network for unsupported PAN', () {
      const raw = '6011111111111117';

      final d = parseCard(raw);

      expect(d.paymentNetwork, isNull);
      expect(d.luhnValid, isTrue);
    });

    test('extracts holder name with mixed case', () {
      const raw = '''
4111111111111111
Vinaya Augusthy
12/29
''';

      final d = parseCard(raw);

      expect(d.holderName, 'Vinaya Augusthy');
    });
  });
}
