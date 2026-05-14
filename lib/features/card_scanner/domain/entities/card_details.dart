import 'package:equatable/equatable.dart';

class CardDetails extends Equatable {
  const CardDetails({
    this.cardNumberDigits,
    this.expiryMonth,
    this.expiryYearYY,
    this.holderName,
    this.paymentNetwork,
    this.luhnValid = false,
  });

  final String? cardNumberDigits;
  final int? expiryMonth;
  final int? expiryYearYY;
  final String? holderName;

  final String? paymentNetwork;
  final bool luhnValid;

  bool get hasCardNumber =>
      cardNumberDigits != null && cardNumberDigits!.isNotEmpty;

  @override
  List<Object?> get props => [
    cardNumberDigits,
    expiryMonth,
    expiryYearYY,
    holderName,
    paymentNetwork,
    luhnValid,
  ];
}
