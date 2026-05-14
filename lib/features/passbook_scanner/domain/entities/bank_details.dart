import 'package:equatable/equatable.dart';

import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/passbook_account_candidate.dart';

class BankDetails extends Equatable {
  const BankDetails({
    this.accountHolderName,
    this.accountNumberDigits,
    this.ifscCode,
    this.accountConfidence = 0,
    this.nameConfidence = 0,
    this.ifscConfidence = 0,
    this.accountCandidateCount,
    this.accountExtractionStrategy,
    this.accountMatchedLine,
    this.accountOcrCorrected = false,
    this.accountCandidates = const [],
    this.nameMatchStrategy,
    this.nameMatchedLine,
    this.maskedAccountNumber,
    this.isMaskedAccount = false,
  });

  final String? accountHolderName;
  final String? accountNumberDigits;
  final String? ifscCode;

  final double accountConfidence;
  final double nameConfidence;
  final double ifscConfidence;

  final int? accountCandidateCount;

  final String? accountExtractionStrategy;

  final String? accountMatchedLine;

  final bool accountOcrCorrected;

  final List<PassbookAccountCandidate> accountCandidates;

  final String? nameMatchStrategy;

  final String? nameMatchedLine;

  final String? maskedAccountNumber;

  final bool isMaskedAccount;

  @override
  List<Object?> get props => [
    accountHolderName,
    accountNumberDigits,
    ifscCode,
    accountConfidence,
    nameConfidence,
    ifscConfidence,
    accountCandidateCount,
    accountExtractionStrategy,
    accountMatchedLine,
    accountOcrCorrected,
    accountCandidates,
    nameMatchStrategy,
    nameMatchedLine,
    maskedAccountNumber,
    isMaskedAccount,
  ];
}
