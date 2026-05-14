import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/app.dart';

void main() {
  testWidgets('Home shows scanner choices', (WidgetTester tester) async {
    await tester.pumpWidget(const OcrScannerApp());

    expect(find.text('OCR Scanner'), findsOneWidget);
    expect(find.text('Card scanner'), findsOneWidget);
    expect(find.text('Passbook / bank document'), findsOneWidget);
  });
}
