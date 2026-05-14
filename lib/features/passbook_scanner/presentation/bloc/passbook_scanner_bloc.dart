import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/bank_details.dart';
import 'package:ocr_scanner_app/core/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_event.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_state.dart';

class PassbookScannerBloc
    extends Bloc<PassbookScannerEvent, PassbookScannerState> {
  PassbookScannerBloc({required PickImageRepository pickImageRepository})
    : _pickImage = pickImageRepository,
      super(const PassbookScannerInitial()) {
    on<PassbookScannerReset>(_onReset);
    on<PassbookScannerPickCamera>(_onPickCamera);
    on<PassbookScannerPickGallery>(_onPickGallery);
  }

  final PickImageRepository _pickImage;

  String? _lastImagePath;

  void _onReset(
    PassbookScannerReset event,
    Emitter<PassbookScannerState> emit,
  ) {
    _lastImagePath = null;
    emit(const PassbookScannerInitial());
  }

  Future<void> _onPickCamera(
    PassbookScannerPickCamera event,
    Emitter<PassbookScannerState> emit,
  ) async {
    await _pick(emit, _pickImage.pickFromCamera);
  }

  Future<void> _onPickGallery(
    PassbookScannerPickGallery event,
    Emitter<PassbookScannerState> emit,
  ) async {
    await _pick(emit, _pickImage.pickFromGallery);
  }

  Future<void> _pick(
    Emitter<PassbookScannerState> emit,
    Future<PickImageResult> Function() pick,
  ) async {
    emit(PassbookScannerProcessing(retainedImagePath: _lastImagePath));
    final result = await pick();
    switch (result) {
      case PickImageSuccess(:final path):
        _lastImagePath = path;
        emit(
          PassbookScannerSuccess(imagePath: path, details: const BankDetails()),
        );
      case PickImageCancelled():
        _emitAfterCancel(emit);
      case PickImageFailure(:final message):
        emit(
          PassbookScannerFailure(
            message,
            retainedImagePath: _lastImagePath,
          ),
        );
    }
  }

  void _emitAfterCancel(Emitter<PassbookScannerState> emit) {
    if (_lastImagePath != null) {
      emit(
        PassbookScannerSuccess(
          imagePath: _lastImagePath!,
          details: const BankDetails(),
        ),
      );
    } else {
      emit(const PassbookScannerInitial());
    }
  }
}
