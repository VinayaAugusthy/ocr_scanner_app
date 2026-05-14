import 'package:equatable/equatable.dart';

abstract class TextRecognitionRepository {
  Future<TextRecognitionResult> recognizeLatinFromFilePath(String imagePath);
}

sealed class TextRecognitionResult extends Equatable {
  const TextRecognitionResult();

  @override
  List<Object?> get props => [];
}

final class TextRecognitionSuccess extends TextRecognitionResult {
  const TextRecognitionSuccess(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

final class TextRecognitionFailure extends TextRecognitionResult {
  const TextRecognitionFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
