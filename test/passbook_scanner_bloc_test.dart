import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/usecases/extract_passbook_details_usecase.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_event.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_state.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';

import 'support/fake_repositories.dart';

const _samplePassbookOcr = '''
IFSC SBIN0001234
Account No: 302012345678
Name: Riya Sharma
''';

PassbookScannerBloc _buildBloc({
  FakePickImageRepository? pick,
  TextRecognitionResult? ocrResult,
}) {
  return PassbookScannerBloc(
    pickImageRepository: pick ??
        FakePickImageRepository(const PickImageSuccess('/fake/passbook.jpg')),
    textRecognitionRepository: FakeTextRecognitionRepository(
      ocrResult ?? const TextRecognitionSuccess(_samplePassbookOcr),
    ),
    extractPassbookDetails: const ExtractPassbookDetailsUseCase(),
  );
}

void main() {
  group('PassbookScannerBloc', () {
    test('initial state is PassbookScannerInitial', () {
      final bloc = _buildBloc();
      addTearDown(bloc.close);
      expect(bloc.state, isA<PassbookScannerInitial>());
    });

    test('gallery pick emits processing then success', () async {
      final bloc = _buildBloc();
      addTearDown(bloc.close);

      bloc.add(const PassbookScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<PassbookScannerProcessing>(),
          isA<PassbookScannerSuccess>()
              .having((s) => s.duplicateScan, 'duplicate', false)
              .having((s) => s.details.ifscCode, 'ifsc', 'SBIN0001234')
              .having(
                (s) => s.details.accountNumberDigits,
                'account',
                '302012345678',
              )
              .having(
                (s) => s.details.accountHolderName,
                'name',
                'Riya Sharma',
              ),
        ]),
      );
    });

    test('fails when OCR text is empty', () async {
      final bloc = _buildBloc(
        ocrResult: const TextRecognitionSuccess(''),
      );
      addTearDown(bloc.close);

      bloc.add(const PassbookScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<PassbookScannerProcessing>(),
          isA<PassbookScannerFailure>().having(
            (s) => s.message,
            'message',
            AppStrings.ocrNoTextDetected,
          ),
        ]),
      );
    });

    test('fails when OCR recognition fails', () async {
      final bloc = _buildBloc(
        ocrResult: const TextRecognitionFailure('OCR engine error'),
      );
      addTearDown(bloc.close);

      bloc.add(const PassbookScannerPickGallery());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<PassbookScannerProcessing>(),
          isA<PassbookScannerFailure>().having(
            (s) => s.message,
            'message',
            'OCR engine error',
          ),
        ]),
      );
    });

    test('reset returns to initial', () async {
      final bloc = _buildBloc();
      addTearDown(bloc.close);

      bloc.add(const PassbookScannerPickGallery());
      await expectLater(bloc.stream, emitsThrough(isA<PassbookScannerSuccess>()));

      bloc.add(const PassbookScannerReset());
      await expectLater(bloc.stream, emits(isA<PassbookScannerInitial>()));
    });
  });
}
