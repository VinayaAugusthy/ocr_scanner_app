import 'package:ocr_scanner_app/features/card_scanner/domain/entities/card_details.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/parsing/card_parser.dart';

class ExtractCardDetailsUseCase {
  const ExtractCardDetailsUseCase();

  CardDetails call(String rawOcrText) => parseCard(rawOcrText);
}
