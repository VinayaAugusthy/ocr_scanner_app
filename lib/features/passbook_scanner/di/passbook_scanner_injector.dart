import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/usecases/extract_passbook_details_usecase.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_bloc.dart';

class PassbookScannerInjector extends StatelessWidget {
  const PassbookScannerInjector({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PassbookScannerBloc(
        pickImageRepository: context.read<PickImageRepository>(),
        textRecognitionRepository: context.read<TextRecognitionRepository>(),
        extractPassbookDetails: const ExtractPassbookDetailsUseCase(),
      ),
      child: child,
    );
  }
}
