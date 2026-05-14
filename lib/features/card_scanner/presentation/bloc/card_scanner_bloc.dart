import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/entities/card_details.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/usecases/extract_card_details_usecase.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/ocr/domain/utils/ocr_text_normalizer.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_event.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_state.dart';

class CardScannerBloc extends Bloc<CardScannerEvent, CardScannerState> {
  CardScannerBloc({
    required PickImageRepository pickImageRepository,
    required TextRecognitionRepository textRecognitionRepository,
    required ExtractCardDetailsUseCase extractCardDetails,
  }) : _pickImage = pickImageRepository,
       _textRecognition = textRecognitionRepository,
       _extractCardDetails = extractCardDetails,
       super(const CardScannerInitial()) {
    on<CardScannerReset>(_onReset);
    on<CardScannerPickCamera>(_onPickCamera);
    on<CardScannerPickGallery>(_onPickGallery);
  }

  final PickImageRepository _pickImage;
  final TextRecognitionRepository _textRecognition;
  final ExtractCardDetailsUseCase _extractCardDetails;

  String? _lastImagePath;
  CardDetails? _lastParsedDetails;
  String? _lastNormalizedOcr;

  void _onReset(CardScannerReset event, Emitter<CardScannerState> emit) {
    _lastImagePath = null;
    _lastParsedDetails = null;
    _lastNormalizedOcr = null;
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
        await _runOcrAndParse(emit, path);
      case PickImageCancelled():
        _emitAfterCancel(emit);
      case PickImageFailure(:final message):
        emit(CardScannerFailure(message, retainedImagePath: _lastImagePath));
    }
  }

  Future<void> _runOcrAndParse(
    Emitter<CardScannerState> emit,
    String imagePath,
  ) async {
    final ocr = await _textRecognition.recognizeLatinFromFilePath(imagePath);
    switch (ocr) {
      case TextRecognitionFailure(:final message):
        emit(CardScannerFailure(message, retainedImagePath: _lastImagePath));
        return;
      case TextRecognitionSuccess(:final text):
        if (text.trim().isEmpty) {
          emit(
            CardScannerFailure(
              AppStrings.ocrNoTextDetected,
              retainedImagePath: _lastImagePath,
            ),
          );
          return;
        }
        final norm = normalizeOcrForDuplicateComparison(text);
        if (norm == _lastNormalizedOcr && _lastParsedDetails != null) {
          emit(
            CardScannerSuccess(
              imagePath: imagePath,
              details: _lastParsedDetails!,
              duplicateScan: true,
            ),
          );
          return;
        }
        final details = _extractCardDetails(text);
        if (!details.hasCardNumber) {
          emit(
            CardScannerFailure(
              AppStrings.cardCouldNotReadNumber,
              retainedImagePath: _lastImagePath,
            ),
          );
          return;
        }
        _lastNormalizedOcr = norm;
        _lastParsedDetails = details;
        emit(
          CardScannerSuccess(
            imagePath: imagePath,
            details: details,
            duplicateScan: false,
          ),
        );
    }
  }

  void _emitAfterCancel(Emitter<CardScannerState> emit) {
    if (_lastImagePath != null) {
      emit(
        CardScannerSuccess(
          imagePath: _lastImagePath!,
          details: _lastParsedDetails ?? const CardDetails(),
        ),
      );
    } else {
      emit(const CardScannerInitial());
    }
  }
}
