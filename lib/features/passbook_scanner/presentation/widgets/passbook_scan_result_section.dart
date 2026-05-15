import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/presentation/widgets/info_row.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/core/utils/formatters.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/domain/entities/bank_details.dart';

class PassbookScanResultSection extends StatelessWidget {
  const PassbookScanResultSection({super.key, required this.details});

  final BankDetails? details;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final detailsData = details;

    return Padding(
      padding: const EdgeInsets.all(8),
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
              label: AppStrings.passbookFieldHolder,
              value: displayOrDash(detailsData.accountHolderName),
            ),
            InfoRow(
              label: AppStrings.passbookFieldAccount,
              value: displayOrDash(detailsData.accountNumberDigits),
            ),
            InfoRow(
              label: AppStrings.passbookFieldIfsc,
              value: displayOrDash(detailsData.ifscCode),
            ),
          ] else ...[
            const InfoRow(
              label: AppStrings.passbookFieldHolder,
              value: AppStrings.emDash,
            ),
            const InfoRow(
              label: AppStrings.passbookFieldAccount,
              value: AppStrings.emDash,
            ),
            const InfoRow(
              label: AppStrings.passbookFieldIfsc,
              value: AppStrings.emDash,
            ),
          ],
        ],
      ),
    );
  }
}
