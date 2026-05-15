import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/utils/formatters.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/info_row.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/features/card_scanner/domain/entities/card_details.dart';

const double _kCardLabelWidth = 120;

class CardScanResultSection extends StatelessWidget {
  const CardScanResultSection({super.key, required this.details});

  final CardDetails? details;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final detailsData = details;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              AppStrings.extractedSectionTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 20),
          if (detailsData != null) ...[
            InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldNumber,
              value: maskCardNumberForDisplay(detailsData.cardNumberDigits),
            ),
            InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldExpiry,
              value: formatExpiryDisplay(
                detailsData.expiryMonth,
                detailsData.expiryYearYY,
              ),
            ),
            InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldCardholder,
              value: displayOrDash(detailsData.holderName),
            ),
            InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldNetwork,
              value: displayOrDash(detailsData.paymentNetwork),
            ),
            InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldLuhn,
              value: detailsData.luhnValid
                  ? AppStrings.luhnValid
                  : AppStrings.luhnInvalidOrUnknown,
            ),
          ] else ...[
            InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldNumber,
              value: maskCardNumberForDisplay(null),
            ),
            const InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldExpiry,
              value: AppStrings.emDash,
            ),
            const InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldCardholder,
              value: AppStrings.emDash,
            ),
            const InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldNetwork,
              value: AppStrings.emDash,
            ),
            const InfoRow(
              labelWidth: _kCardLabelWidth,
              label: AppStrings.cardFieldLuhn,
              value: AppStrings.emDash,
            ),
          ],
        ],
      ),
    );
  }
}
