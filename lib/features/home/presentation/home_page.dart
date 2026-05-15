import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_colors.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/pages/card_scanner_page.dart';
import 'package:ocr_scanner_app/features/home/presentation/widgets/scanner_options.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/pages/passbook_scanner_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.themeSeed,
        foregroundColor: AppColors.white,
        title: const Text(AppStrings.appTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const SizedBox(height: 12),

              Text(
                textAlign: TextAlign.center,
                AppStrings.homeHeadline,
                style: context.appTheme.textTheme.titleLarge,
              ),

              const SizedBox(height: 32),
              ScannerCard(
                title: AppStrings.homeCardScannerButton,
                icon: Icons.credit_card_rounded,
                iconBg: AppColors.cardScannerIconBg,
                iconColor: AppColors.cardScannerIcon,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CardScannerPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              ScannerCard(
                title: AppStrings.homePassbookScannerButton,
                icon: Icons.account_balance_rounded,
                iconBg: AppColors.passbookScannerIconBg,
                iconColor: AppColors.passbookScannerIcon,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PassbookScannerPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
