import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/constants/app_colors.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/async_loading_overlay.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/camera_gallery_action_row.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/scan_image_frame.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/di/passbook_scanner_injector.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_event.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_state.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/widgets/passbook_scan_result_section.dart';

class PassbookScannerPage extends StatelessWidget {
  const PassbookScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PassbookScannerInjector(child: _PassbookScannerView());
  }
}

class _PassbookScannerView extends StatelessWidget {
  const _PassbookScannerView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PassbookScannerBloc, PassbookScannerState>(
      listenWhen: (prev, next) =>
          next is PassbookScannerFailure ||
          (next is PassbookScannerSuccess && next.duplicateScan),
      listener: (context, state) {
        if (!context.mounted) return;
        if (state is PassbookScannerFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is PassbookScannerSuccess && state.duplicateScan) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.duplicateScanUnchanged)),
          );
        }
      },
      builder: (context, state) {
        final theme = context.appTheme;
        String? path;
        var errorHint = false;
        if (state is PassbookScannerSuccess) {
          path = state.imagePath;
        } else if (state is PassbookScannerProcessing) {
          path = state.retainedImagePath;
        } else if (state is PassbookScannerFailure) {
          errorHint = true;
          path = state.retainedImagePath;
        }

        final isProcessing = state is PassbookScannerProcessing;
        final bloc = context.read<PassbookScannerBloc>();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.themeSeed,
            foregroundColor: AppColors.white,
            centerTitle: true,
            title: const Text(AppStrings.passbookScannerTitle),
            actions: [
              IconButton(
                tooltip: AppStrings.clearTooltip,
                onPressed: () => bloc.add(const PassbookScannerReset()),
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
                  onCamera: () => bloc.add(const PassbookScannerPickCamera()),
                  onGallery: () => bloc.add(const PassbookScannerPickGallery()),
                ),
                const SizedBox(height: 28),
                PassbookScanResultSection(
                  details: state is PassbookScannerSuccess
                      ? state.details
                      : null,
                ),
                if (state is PassbookScannerFailure) ...[
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
