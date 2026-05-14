import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';

class ImagePickerPickImageRepository implements PickImageRepository {
  ImagePickerPickImageRepository({
    ImagePicker? picker,
    this.maxWidth = 4096,
    this.maxHeight = 4096,
    this.imageQuality = 90,
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  final double maxWidth;
  final double maxHeight;
  final int imageQuality;

  @override
  Future<PickImageResult> pickFromCamera() {
    return _pick(ImageSource.camera);
  }

  @override
  Future<PickImageResult> pickFromGallery() {
    return _pick(ImageSource.gallery);
  }

  Future<PickImageResult> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        requestFullMetadata: false,
      );

      if (file == null) {
        return const PickImageCancelled();
      }

      final path = file.path.trim();

      if (path.isEmpty) {
        return const PickImageFailure('Image path is empty');
      }

      return PickImageSuccess(path);
    } on PlatformException catch (e) {
      return PickImageFailure(
        e.message ?? 'Permission denied while picking image',
      );
    } on Exception {
      return const PickImageFailure('Failed to pick image');
    }
  }
}
