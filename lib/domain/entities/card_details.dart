import 'package:equatable/equatable.dart';

/// Parsed card fields from OCR text. [cardNumberDigits] is digits only, no spaces.
class CardDetails extends Equatable {
  const CardDetails({
    this.cardNumberDigits,
    this.expiryMonth,
    this.expiryYearYY,
    this.holderName,
    required this.luhnValid,
  });

  final String? cardNumberDigits;
  final int? expiryMonth;
  final int? expiryYearYY;
  final String? holderName;
  final bool luhnValid;

  bool get hasCardNumber =>
      cardNumberDigits != null && cardNumberDigits!.isNotEmpty;

  @override
  List<Object?> get props =>
      [cardNumberDigits, expiryMonth, expiryYearYY, holderName, luhnValid];
}
