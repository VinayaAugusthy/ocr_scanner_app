import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_event.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_state.dart';

/// Step 1: skeleton. Step 3 wires OCR + [parsePassbook].
class PassbookScannerBloc extends Bloc<PassbookScannerEvent, PassbookScannerState> {
  PassbookScannerBloc() : super(const PassbookScannerInitial()) {
    on<PassbookScannerReset>(_onReset);
    on<PassbookScannerPickCamera>(_onPickCamera);
    on<PassbookScannerPickGallery>(_onPickGallery);
  }

  void _onReset(
    PassbookScannerReset event,
    Emitter<PassbookScannerState> emit,
  ) {
    emit(const PassbookScannerInitial());
  }

  void _onPickCamera(
    PassbookScannerPickCamera event,
    Emitter<PassbookScannerState> emit,
  ) {
    emit(
      const PassbookScannerFailure(
        'OCR and camera are not wired yet. Commit after Step 3.',
      ),
    );
  }

  void _onPickGallery(
    PassbookScannerPickGallery event,
    Emitter<PassbookScannerState> emit,
  ) {
    emit(
      const PassbookScannerFailure(
        'OCR and gallery are not wired yet. Commit after Step 3.',
      ),
    );
  }
}
