import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/domain/repositories/pick_image_repository.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_bloc.dart';

class PassbookScannerInjector extends StatelessWidget {
  const PassbookScannerInjector({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PassbookScannerBloc(
        pickImageRepository: context.read<PickImageRepository>(),
      ),
      child: child,
    );
  }
}
