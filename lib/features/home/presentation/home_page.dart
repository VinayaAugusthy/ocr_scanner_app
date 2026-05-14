import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/features/card_scanner/presentation/card_scanner_page.dart';
import 'package:ocr_scanner_app/features/passbook_scanner/presentation/passbook_scanner_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Scanner'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a scanner',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Card and passbook flows use on-device OCR; parsing is custom.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
                label: const Text('Card scanner'),
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
                label: const Text('Passbook / bank document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
