import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/card_scanner_page.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/passbook_scanner_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.homeHeadline,
                style: context.appTheme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.homeSubtitle,
                style: context.appTheme.textTheme.bodyMedium?.copyWith(
                  color: context.appTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CardScannerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.credit_card),
                label: const Text(AppStrings.homeCardScannerButton),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PassbookScannerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text(AppStrings.homePassbookScannerButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
