import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/parsing/card_parser.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/parsing/passbook_parser.dart';

/// End-to-end parser checks on realistic OCR text blobs (no device required).
void main() {
  group('OCR parsing fixtures — card', () {
    test('synthetic card photo text', () {
      const raw = '''
STATE BANK CARD
4242 4242 4242 4242
VALID THRU 12/30
ALEX RIVER
''';

      final d = parseCard(raw);

      expect(d.cardNumberDigits, '4242424242424242');
      expect(d.luhnValid, isTrue);
      expect(d.expiryMonth, 12);
      expect(d.expiryYearYY, 30);
      expect(d.holderName, contains('ALEX'));
    });

    test('mandatory expiry formats 12/30, 12-30, compact 1230', () {
      expect(
        parseCard('4242424242424242\n12/30').expiryMonth,
        12,
      );
      expect(
        parseCard('4242424242424242\n12-30').expiryMonth,
        12,
      );
      expect(
        parseCard('4242424242424242\nEXP 1230').expiryMonth,
        12,
      );
    });
  });

  group('OCR parsing fixtures — passbook', () {
    test('synthetic passbook page text', () {
      const raw = '''
STATE BANK OF INDIA
IFSC Code: SBIN0001234
Savings Account No
302012345678
Name: Riya Sharma
''';

      final d = parsePassbook(raw);

      expect(d.ifscCode, 'SBIN0001234');
      expect(d.accountNumberDigits, '302012345678');
      expect(d.accountHolderName, 'Riya Sharma');
      expect(d.ifscConfidence, greaterThan(0.5));
    });

    test('picks account over UPI reference noise', () {
      const raw = '''
IFSC HDFC0001234
UPI ref 123456789012
Account No: 302012345678
Name: Test User
''';

      final d = parsePassbook(raw);

      expect(d.accountNumberDigits, '302012345678');
      expect(d.ifscCode, 'HDFC0001234');
    });
  });
}
