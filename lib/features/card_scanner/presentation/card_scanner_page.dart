import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocr_scanner_app/core/presentation/formatters.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/scan_image_frame.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_bloc.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_event.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/bloc/card_scanner_state.dart';

class CardScannerPage extends StatelessWidget {
  const CardScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CardScannerBloc(),
      child: const _CardScannerView(),
    );
  }
}

class _CardScannerView extends StatelessWidget {
  const _CardScannerView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardScannerBloc, CardScannerState>(
      listenWhen: (prev, next) => next is CardScannerFailure,
      listener: (context, state) {
        if (state is CardScannerFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        String? path;
        var errorHint = false;
        if (state is CardScannerSuccess) {
          path = state.imagePath;
        } else if (state is CardScannerFailure) {
          errorHint = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Card scanner'),
            actions: [
              IconButton(
                tooltip: 'Clear',
                onPressed: () => context.read<CardScannerBloc>().add(
                      const CardScannerReset(),
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
                      onPressed: state is CardScannerProcessing
                          ? null
                          : () => context.read<CardScannerBloc>().add(
                                const CardScannerPickCamera(),
                              ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state is CardScannerProcessing
                          ? null
                          : () => context.read<CardScannerBloc>().add(
                                const CardScannerPickGallery(),
                              ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              if (state is CardScannerProcessing) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 28),
              Text('Extracted', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (state is CardScannerSuccess) ...[
                _InfoRow(
                  label: 'Card number',
                  value: maskCardNumberForDisplay(
                    state.details.cardNumberDigits,
                  ),
                ),
                _InfoRow(
                  label: 'Expiry',
                  value: formatExpiryDisplay(
                    state.details.expiryMonth,
                    state.details.expiryYearYY,
                  ),
                ),
                _InfoRow(
                  label: 'Cardholder',
                  value: displayOrDash(state.details.holderName),
                ),
                _InfoRow(
                  label: 'Luhn check',
                  value: state.details.luhnValid ? 'Valid' : 'Invalid / unknown',
                ),
              ] else ...[
                _InfoRow(
                  label: 'Card number',
                  value: maskCardNumberForDisplay(null),
                ),
                const _InfoRow(label: 'Expiry', value: '—'),
                const _InfoRow(label: 'Cardholder', value: '—'),
                const _InfoRow(label: 'Luhn check', value: '—'),
              ],
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
            width: 120,
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
