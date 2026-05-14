import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/data/repositories/image_picker_pick_image_repository.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/ocr/data/repositories/mlkit_text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/home/presentation/home_page.dart';

class OcrScannerApp extends StatelessWidget {
  const OcrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PickImageRepository>(
          create: (_) => ImagePickerPickImageRepository(),
        ),
        RepositoryProvider<TextRecognitionRepository>(
          create: (_) => MlKitTextRecognitionRepository(),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.materialAppTitle,
        theme: AppTheme.light(),
        home: const HomePage(),
      ),
    );
  }
}
