import 'package:equatable/equatable.dart';
import 'package:ocr_scanner_app/domain/entities/card_details.dart';

sealed class CardScannerState extends Equatable {
  const CardScannerState();

  @override
  List<Object?> get props => [];
}

final class CardScannerInitial extends CardScannerState {
  const CardScannerInitial();
}

final class CardScannerProcessing extends CardScannerState {
  const CardScannerProcessing();
}

final class CardScannerSuccess extends CardScannerState {
  const CardScannerSuccess({
    required this.imagePath,
    required this.details,
    this.rawOcrText,
  });

  final String imagePath;
  final CardDetails details;
  final String? rawOcrText;

  @override
  List<Object?> get props => [imagePath, details, rawOcrText];
}

final class CardScannerFailure extends CardScannerState {
  const CardScannerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
