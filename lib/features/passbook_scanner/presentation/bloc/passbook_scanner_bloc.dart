import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/bank_details.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/usecases/extract_passbook_details_usecase.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/ocr/domain/utils/ocr_text_normalizer.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_event.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_state.dart';

class PassbookScannerBloc
    extends Bloc<PassbookScannerEvent, PassbookScannerState> {
  PassbookScannerBloc({
    required PickImageRepository pickImageRepository,
    required TextRecognitionRepository textRecognitionRepository,
    required ExtractPassbookDetailsUseCase extractPassbookDetails,
  }) : _pickImage = pickImageRepository,
       _textRecognition = textRecognitionRepository,
       _extractPassbookDetails = extractPassbookDetails,
       super(const PassbookScannerInitial()) {
    on<PassbookScannerReset>(_onReset);
    on<PassbookScannerPickCamera>(_onPickCamera);
    on<PassbookScannerPickGallery>(_onPickGallery);
  }

  final PickImageRepository _pickImage;
  final TextRecognitionRepository _textRecognition;
  final ExtractPassbookDetailsUseCase _extractPassbookDetails;

  String? _lastImagePath;
  BankDetails? _lastParsedDetails;
  String? _lastNormalizedOcr;

  void _onReset(
    PassbookScannerReset event,
    Emitter<PassbookScannerState> emit,
  ) {
    _lastImagePath = null;
    _lastParsedDetails = null;
    _lastNormalizedOcr = null;
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
        await _runOcrAndParse(emit, path);
      case PickImageCancelled():
        _emitAfterCancel(emit);
      case PickImageFailure(:final message):
        emit(
          PassbookScannerFailure(message, retainedImagePath: _lastImagePath),
        );
    }
  }

  Future<void> _runOcrAndParse(
    Emitter<PassbookScannerState> emit,
    String imagePath,
  ) async {
    final ocr = await _textRecognition.recognizeLatinFromFilePath(imagePath);
    switch (ocr) {
      case TextRecognitionFailure(:final message):
        emit(
          PassbookScannerFailure(message, retainedImagePath: _lastImagePath),
        );
        return;
      case TextRecognitionSuccess(:final text):
        if (text.trim().isEmpty) {
          emit(
            PassbookScannerFailure(
              AppStrings.ocrNoTextDetected,
              retainedImagePath: _lastImagePath,
            ),
          );
          return;
        }
        final norm = normalizeOcrForDuplicateComparison(text);
        if (norm == _lastNormalizedOcr && _lastParsedDetails != null) {
          emit(
            PassbookScannerSuccess(
              imagePath: imagePath,
              details: _lastParsedDetails!,
              duplicateScan: true,
            ),
          );
          return;
        }
        final details = _extractPassbookDetails(text);
        if (!details.hasExtractedFields) {
          emit(
            PassbookScannerFailure(
              AppStrings.passbookCouldNotReadDetails,
              retainedImagePath: _lastImagePath,
            ),
          );
          return;
        }
        _lastNormalizedOcr = norm;
        _lastParsedDetails = details;
        emit(
          PassbookScannerSuccess(
            imagePath: imagePath,
            details: details,
            duplicateScan: false,
          ),
        );
    }
  }

  void _emitAfterCancel(Emitter<PassbookScannerState> emit) {
    if (_lastImagePath != null) {
      emit(
        PassbookScannerSuccess(
          imagePath: _lastImagePath!,
          details: _lastParsedDetails ?? const BankDetails(),
        ),
      );
    } else {
      emit(const PassbookScannerInitial());
    }
  }
}
