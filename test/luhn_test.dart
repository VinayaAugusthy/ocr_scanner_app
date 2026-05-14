import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/domain/parsing/luhn.dart';

void main() {
  group('isValidCard', () {
    test('accepts known-valid Visa-style PAN', () {
      expect(isValidCard('4242424242424242'), isTrue);
      expect(isValidCard('4532015112830366'), isTrue);
    });

    test('rejects wrong check digit', () {
      expect(isValidCard('4242424242424241'), isFalse);
      expect(isValidCard('4532015112830367'), isFalse);
    });

    test('ignores spaces and hyphens', () {
      expect(isValidCard('4242-4242-4242-4242'), isTrue);
      expect(isValidCard('4242 4242 4242 4242'), isTrue);
    });

    test('rejects too short or too long digit strings', () {
      expect(isValidCard('424242424242'), isFalse);
      expect(isValidCard('11111111111111111111'), isFalse);
    });

    test('rejects non-digit garbage', () {
      expect(isValidCard('xxxx'), isFalse);
      expect(isValidCard(''), isFalse);
    });

    test('rejects only when every digit is identical (OCR garbage)', () {
      expect(isValidCard('0000 0000 0000 0000'), isFalse);
      expect(isValidCard('1111 1111 1111 1111'), isFalse);
      expect(isValidCard('2222222222222222'), isFalse);
      expect(isValidCard('9999999999999999'), isFalse);
    });

    test(
      'still accepts PANs that contain repeated digits but are not all one digit',
      () {
        expect(isValidCard('4242424242424242'), isTrue);
        expect(isValidCard('4111111111111111'), isTrue);
      },
    );
  });
}
