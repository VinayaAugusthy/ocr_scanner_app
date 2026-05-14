import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_bloc.dart';

class CardScannerInjector extends StatelessWidget {
  const CardScannerInjector({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CardScannerBloc(
        pickImageRepository: context.read<PickImageRepository>(),
      ),
      child: child,
    );
  }
}
