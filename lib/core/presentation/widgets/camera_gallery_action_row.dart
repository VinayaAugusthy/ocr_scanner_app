import 'package:flutter/material.dart';
import 'package:ocr_scanner_app/core/constants/app_colors.dart';
import 'package:ocr_scanner_app/core/constants/app_strings.dart';

class CameraGalleryActionRow extends StatelessWidget {
  const CameraGalleryActionRow({
    super.key,
    required this.isBusy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool isBusy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.themeSeed,
              foregroundColor: AppColors.white,
            ),
            onPressed: isBusy ? null : onCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text(AppStrings.cameraButton),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.themeSeed,
              side: const BorderSide(color: AppColors.themeSeed),
            ),
            onPressed: isBusy ? null : onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text(AppStrings.galleryButton),
          ),
        ),
      ],
    );
  }
}
