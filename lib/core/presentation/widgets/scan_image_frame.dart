import 'dart:io';

import 'package:flutter/material.dart';

class ScanImageFrame extends StatelessWidget {
  const ScanImageFrame({super.key, this.imagePath, this.showErrorHint = false});

  final String? imagePath;
  final bool showErrorHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = showErrorHint
        ? theme.colorScheme.error.withValues(alpha: 0.6)
        : theme.colorScheme.outlineVariant;

    Widget child;
    if (imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync()) {
      child = Image.file(
        File(imagePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            _placeholder(theme, Icons.broken_image_outlined),
      );
    } else {
      child = _placeholder(theme, Icons.add_a_photo_outlined);
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.5),
          child: child,
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Scan preview',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
