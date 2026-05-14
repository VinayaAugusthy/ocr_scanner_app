import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/usecases/extract_card_details_usecase.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';

class CardScannerInjector extends StatelessWidget {
  const CardScannerInjector({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CardScannerBloc(
        pickImageRepository: context.read<PickImageRepository>(),
        textRecognitionRepository: context.read<TextRecognitionRepository>(),
        extractCardDetails: const ExtractCardDetailsUseCase(),
      ),
      child: child,
    );
  }
}
