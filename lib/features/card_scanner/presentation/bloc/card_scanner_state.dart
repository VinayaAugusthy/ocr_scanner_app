import 'package:equatable/equatable.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/entities/card_details.dart';

sealed class CardScannerState extends Equatable {
  const CardScannerState();

  @override
  List<Object?> get props => [];
}

final class CardScannerInitial extends CardScannerState {
  const CardScannerInitial();
}

final class CardScannerProcessing extends CardScannerState {
  const CardScannerProcessing({this.retainedImagePath});

  final String? retainedImagePath;

  @override
  List<Object?> get props => [retainedImagePath];
}

final class CardScannerSuccess extends CardScannerState {
  const CardScannerSuccess({
    required this.imagePath,
    required this.details,
    this.duplicateScan = false,
  });

  final String imagePath;
  final CardDetails details;
  final bool duplicateScan;

  @override
  List<Object?> get props => [imagePath, details, duplicateScan];
}

final class CardScannerFailure extends CardScannerState {
  const CardScannerFailure(this.message, {this.retainedImagePath});

  final String message;

  final String? retainedImagePath;

  @override
  List<Object?> get props => [message, retainedImagePath];
}
