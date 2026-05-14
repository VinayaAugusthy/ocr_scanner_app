import 'package:flutter/material.dart';import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/async_loading_overlay.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/camera_gallery_action_row.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/scan_image_frame.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/features/card_scanner/di/card_scanner_injector.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_event.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_state.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/widgets/card_scan_result_section.dart';

class CardScannerPage extends StatelessWidget {
  const CardScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardScannerInjector(
      child: _CardScannerView(),
    );
  }
}

class _CardScannerView extends StatelessWidget {
  const _CardScannerView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardScannerBloc, CardScannerState>(
      listenWhen: (prev, next) =>
          next is CardScannerFailure ||
          (next is CardScannerSuccess && next.duplicateScan),
      listener: (context, state) {
        if (!context.mounted) return;
        if (state is CardScannerFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is CardScannerSuccess && state.duplicateScan) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.duplicateScanUnchanged)),
          );
        }
      },
      builder: (context, state) {
        final theme = context.appTheme;
        String? path;
        var errorHint = false;
        if (state is CardScannerSuccess) {
          path = state.imagePath;
        } else if (state is CardScannerProcessing) {
          path = state.retainedImagePath;
        } else if (state is CardScannerFailure) {
          errorHint = true;
          path = state.retainedImagePath;
        }

        final isProcessing = state is CardScannerProcessing;
        final bloc = context.read<CardScannerBloc>();

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.cardScannerTitle),
            actions: [
              IconButton(
                tooltip: AppStrings.clearTooltip,
                onPressed: () => bloc.add(const CardScannerReset()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: AsyncLoadingOverlay(
            loading: isProcessing,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ScanImageFrame(imagePath: path, showErrorHint: errorHint),
                const SizedBox(height: 16),
                CameraGalleryActionRow(
                  isBusy: isProcessing,
                  onCamera: () => bloc.add(const CardScannerPickCamera()),
                  onGallery: () => bloc.add(const CardScannerPickGallery()),
                ),
                const SizedBox(height: 28),
                CardScanResultSection(
                  details: state is CardScannerSuccess ? state.details : null,
                ),
                if (state is CardScannerFailure) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
