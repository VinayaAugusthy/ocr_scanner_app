import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/bank_details.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/parsing/passbook_parser.dart';

class ExtractPassbookDetailsUseCase {
  const ExtractPassbookDetailsUseCase();

  BankDetails call(String rawOcrText) => parsePassbook(rawOcrText);
}
