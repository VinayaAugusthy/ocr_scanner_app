import 'package:equatable/equatable.dart';

class BankDetails extends Equatable {
  const BankDetails({
    this.accountHolderName,
    this.accountNumberDigits,
    this.ifscCode,
  });

  final String? accountHolderName;
  final String? accountNumberDigits;
  final String? ifscCode;

  @override
  List<Object?> get props => [accountHolderName, accountNumberDigits, ifscCode];
}
