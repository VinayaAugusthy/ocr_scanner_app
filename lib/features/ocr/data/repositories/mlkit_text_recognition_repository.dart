import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';

class MlKitTextRecognitionRepository implements TextRecognitionRepository {
  @override
  Future<TextRecognitionResult> recognizeLatinFromFilePath(
    String imagePath,
  ) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const TextRecognitionFailure(AppStrings.ocrUnsupportedPlatform);
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      final joined = _concatenateRecognizedLines(recognized);
      return TextRecognitionSuccess(joined);
    } on Exception {
      return const TextRecognitionFailure(AppStrings.ocrCouldNotReadImage);
    } finally {
      await recognizer.close();
    }
  }

  String _concatenateRecognizedLines(RecognizedText recognized) {
    final buffer = StringBuffer();
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(line.text);
      }
    }
    return buffer.toString();
  }
}
