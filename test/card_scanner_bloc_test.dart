import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/usecases/extract_card_details_usecase.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_event.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_state.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';

import 'support/fake_repositories.dart';

const _sampleCardOcr = '''
4242424242424242
VALID THRU 12/30
JANE DOE
''';

CardScannerBloc _buildBloc({
  FakePickImageRepository? pick,
  TextRecognitionResult? ocrResult,
}) {
  return CardScannerBloc(
    pickImageRepository:
        pick ?? FakePickImageRepository(const PickImageSuccess('/fake/card.jpg')),
    textRecognitionRepository: FakeTextRecognitionRepository(
      ocrResult ?? const TextRecognitionSuccess(_sampleCardOcr),
    ),
    extractCardDetails: const ExtractCardDetailsUseCase(),
  );
}

void main() {
  group('CardScannerBloc', () {
    test('initial state is CardScannerInitial', () {
      final bloc = _buildBloc();
      addTearDown(bloc.close);
      expect(bloc.state, isA<CardScannerInitial>());
    });

    test('gallery pick emits processing then success', () async {
      final bloc = _buildBloc();
      addTearDown(bloc.close);

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CardScannerProcessing>(),
          isA<CardScannerSuccess>()
              .having((s) => s.duplicateScan, 'duplicate', false)
              .having(
                (s) => s.details.cardNumberDigits,
                'pan',
                '4242424242424242',
              ),
        ]),
      );

      bloc.add(const CardScannerPickGallery());
      await expectation;
    });

    test('fails when OCR text is empty', () async {
      final bloc = _buildBloc(
        ocrResult: const TextRecognitionSuccess('   '),
      );
      addTearDown(bloc.close);

      bloc.add(const CardScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CardScannerProcessing>(),
          isA<CardScannerFailure>().having(
            (s) => s.message,
            'message',
            AppStrings.ocrNoTextDetected,
          ),
        ]),
      );
    });

    test('fails when card number cannot be parsed', () async {
      final bloc = _buildBloc(
        ocrResult: const TextRecognitionSuccess('no card digits here'),
      );
      addTearDown(bloc.close);

      bloc.add(const CardScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CardScannerProcessing>(),
          isA<CardScannerFailure>().having(
            (s) => s.message,
            'message',
            AppStrings.cardCouldNotReadNumber,
          ),
        ]),
      );
    });

    test('reset returns to initial', () async {
      final bloc = _buildBloc();
      addTearDown(bloc.close);

      bloc.add(const CardScannerPickGallery());
      await expectLater(bloc.stream, emitsThrough(isA<CardScannerSuccess>()));

      bloc.add(const CardScannerReset());
      await expectLater(bloc.stream, emits(isA<CardScannerInitial>()));
    });

    test('second identical OCR marks duplicateScan', () async {
      final bloc = _buildBloc();
      addTearDown(bloc.close);

      bloc.add(const CardScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<CardScannerSuccess>().having((s) => s.duplicateScan, 'dup', false),
        ),
      );

      bloc.add(const CardScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<CardScannerSuccess>().having((s) => s.duplicateScan, 'dup', true),
        ),
      );
    });

    test('cancelled pick after success keeps last details', () async {
      final pick = FakePickImageRepository(const PickImageSuccess('/f.jpg'));
      final bloc = _buildBloc(pick: pick);
      addTearDown(bloc.close);

      bloc.add(const CardScannerPickGallery());
      await expectLater(bloc.stream, emitsThrough(isA<CardScannerSuccess>()));

      pick.result = const PickImageCancelled();
      bloc.add(const CardScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<CardScannerSuccess>().having(
            (s) => s.details.cardNumberDigits,
            'pan',
            '4242424242424242',
          ),
        ),
      );
    });
  });
}
