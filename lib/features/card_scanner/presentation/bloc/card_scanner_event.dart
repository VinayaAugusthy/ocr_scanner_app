import 'package:equatable/equatable.dart';

sealed class CardScannerEvent extends Equatable {
  const CardScannerEvent();

  @override
  List<Object?> get props => [];
}

final class CardScannerReset extends CardScannerEvent {
  const CardScannerReset();
}

final class CardScannerPickCamera extends CardScannerEvent {
  const CardScannerPickCamera();
}

final class CardScannerPickGallery extends CardScannerEvent {
  const CardScannerPickGallery();
}
