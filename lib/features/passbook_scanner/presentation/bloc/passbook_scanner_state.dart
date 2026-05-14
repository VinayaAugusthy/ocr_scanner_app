import 'package:equatable/equatable.dart';
import 'package:ocr_scanner_app/domain/entities/bank_details.dart';

sealed class PassbookScannerState extends Equatable {
  const PassbookScannerState();

  @override
  List<Object?> get props => [];
}

final class PassbookScannerInitial extends PassbookScannerState {
  const PassbookScannerInitial();
}

final class PassbookScannerProcessing extends PassbookScannerState {
  const PassbookScannerProcessing();
}

final class PassbookScannerSuccess extends PassbookScannerState {
  const PassbookScannerSuccess({
    required this.imagePath,
    required this.details,
    this.rawOcrText,
  });

  final String imagePath;
  final BankDetails details;
  final String? rawOcrText;

  @override
  List<Object?> get props => [imagePath, details, rawOcrText];
}

final class PassbookScannerFailure extends PassbookScannerState {
  const PassbookScannerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
