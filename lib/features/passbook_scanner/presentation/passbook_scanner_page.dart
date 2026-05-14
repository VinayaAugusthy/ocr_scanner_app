import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/presentation/formatters.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/scan_image_frame.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_event.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/bloc/passbook_scanner_state.dart';

class PassbookScannerPage extends StatelessWidget {
  const PassbookScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PassbookScannerBloc(),
      child: const _PassbookScannerView(),
    );
  }
}

class _PassbookScannerView extends StatelessWidget {
  const _PassbookScannerView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PassbookScannerBloc, PassbookScannerState>(
      listenWhen: (prev, next) => next is PassbookScannerFailure,
      listener: (context, state) {
        if (state is PassbookScannerFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        String? path;
        var errorHint = false;
        if (state is PassbookScannerSuccess) {
          path = state.imagePath;
        } else if (state is PassbookScannerFailure) {
          errorHint = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Passbook scanner'),
            actions: [
              IconButton(
                tooltip: 'Clear',
                onPressed: () => context.read<PassbookScannerBloc>().add(
                      const PassbookScannerReset(),
                    ),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ScanImageFrame(imagePath: path, showErrorHint: errorHint),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state is PassbookScannerProcessing
                          ? null
                          : () => context.read<PassbookScannerBloc>().add(
                                const PassbookScannerPickCamera(),
                              ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state is PassbookScannerProcessing
                          ? null
                          : () => context.read<PassbookScannerBloc>().add(
                                const PassbookScannerPickGallery(),
                              ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              if (state is PassbookScannerProcessing) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 28),
              Text('Extracted', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (state is PassbookScannerSuccess) ...[
                _InfoRow(
                  label: 'Account holder',
                  value: displayOrDash(state.details.accountHolderName),
                ),
                _InfoRow(
                  label: 'Account number',
                  value: displayOrDash(state.details.accountNumberDigits),
                ),
                _InfoRow(
                  label: 'IFSC',
                  value: displayOrDash(state.details.ifscCode),
                ),
              ] else ...[
                const _InfoRow(label: 'Account holder', value: '—'),
                const _InfoRow(label: 'Account number', value: '—'),
                const _InfoRow(label: 'IFSC', value: '—'),
              ],
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
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
