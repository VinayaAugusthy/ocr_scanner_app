import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/entities/card_details.dart';
import 'package:ocr_scanner_app/core/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_event.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_state.dart';

class CardScannerBloc extends Bloc<CardScannerEvent, CardScannerState> {
  CardScannerBloc({required PickImageRepository pickImageRepository})
    : _pickImage = pickImageRepository,
      super(const CardScannerInitial()) {
    on<CardScannerReset>(_onReset);
    on<CardScannerPickCamera>(_onPickCamera);
    on<CardScannerPickGallery>(_onPickGallery);
  }

  final PickImageRepository _pickImage;

  String? _lastImagePath;

  void _onReset(CardScannerReset event, Emitter<CardScannerState> emit) {
    _lastImagePath = null;
    emit(const CardScannerInitial());
  }

  Future<void> _onPickCamera(
    CardScannerPickCamera event,
    Emitter<CardScannerState> emit,
  ) async {
    await _pick(emit, _pickImage.pickFromCamera);
  }

  Future<void> _onPickGallery(
    CardScannerPickGallery event,
    Emitter<CardScannerState> emit,
  ) async {
    await _pick(emit, _pickImage.pickFromGallery);
  }

  Future<void> _pick(
    Emitter<CardScannerState> emit,
    Future<PickImageResult> Function() pick,
  ) async {
    emit(CardScannerProcessing(retainedImagePath: _lastImagePath));
    final result = await pick();
    switch (result) {
      case PickImageSuccess(:final path):
        _lastImagePath = path;
        emit(CardScannerSuccess(imagePath: path, details: const CardDetails()));
      case PickImageCancelled():
        _emitAfterCancel(emit);
      case PickImageFailure(:final message):
        emit(
          CardScannerFailure(
            message,
            retainedImagePath: _lastImagePath,
          ),
        );
    }
  }

  void _emitAfterCancel(Emitter<CardScannerState> emit) {
    if (_lastImagePath != null) {
      emit(
        CardScannerSuccess(
          imagePath: _lastImagePath!,
          details: const CardDetails(),
        ),
      );
    } else {
      emit(const CardScannerInitial());
    }
  }
}
