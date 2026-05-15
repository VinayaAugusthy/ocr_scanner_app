import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_colors.dart';
import 'package:ocr_scanner_app/core/theme/app_theme.dart';

class ScannerCard extends StatelessWidget {
  const ScannerCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 82,
              width: 82,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: iconColor, size: 38),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Text(title, style: context.appTheme.textTheme.titleMedium),
            ),

            Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}
