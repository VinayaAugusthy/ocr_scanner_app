import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_event.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_state.dart';

/// Step 1: skeleton. Step 3 wires OCR + [parseCard].
class CardScannerBloc extends Bloc<CardScannerEvent, CardScannerState> {
  CardScannerBloc() : super(const CardScannerInitial()) {
    on<CardScannerReset>(_onReset);
    on<CardScannerPickCamera>(_onPickCamera);
    on<CardScannerPickGallery>(_onPickGallery);
  }

  void _onReset(CardScannerReset event, Emitter<CardScannerState> emit) {
    emit(const CardScannerInitial());
  }

  void _onPickCamera(
    CardScannerPickCamera event,
    Emitter<CardScannerState> emit,
  ) {
    emit(
      const CardScannerFailure(
        'OCR and camera are not wired yet. Commit after Step 3.',
      ),
    );
  }

  void _onPickGallery(
    CardScannerPickGallery event,
    Emitter<CardScannerState> emit,
  ) {
    emit(
      const CardScannerFailure(
        'OCR and gallery are not wired yet. Commit after Step 3.',
      ),
    );
  }
}
