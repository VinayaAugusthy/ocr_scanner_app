import 'package:equatable/equatable.dart';

class PassbookAccountCandidate extends Equatable {
  const PassbookAccountCandidate({
    required this.rawText,
    required this.normalizedText,
    required this.hadOcrCorrection,
    required this.lineNumber,
    required this.startInDoc,
    required this.lineText,
  });

  final String rawText;

  final String normalizedText;

  final bool hadOcrCorrection;

  final int lineNumber;

  final int startInDoc;

  final String lineText;

  @override
  List<Object?> get props => [
    rawText,
    normalizedText,
    hadOcrCorrection,
    lineNumber,
    startInDoc,
    lineText,
  ];
}
