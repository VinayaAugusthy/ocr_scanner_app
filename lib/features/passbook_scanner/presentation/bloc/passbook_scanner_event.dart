import 'package:equatable/equatable.dart';

sealed class PassbookScannerEvent extends Equatable {
  const PassbookScannerEvent();

  @override
  List<Object?> get props => [];
}

final class PassbookScannerReset extends PassbookScannerEvent {
  const PassbookScannerReset();
}

final class PassbookScannerPickCamera extends PassbookScannerEvent {
  const PassbookScannerPickCamera();
}

final class PassbookScannerPickGallery extends PassbookScannerEvent {
  const PassbookScannerPickGallery();
}
