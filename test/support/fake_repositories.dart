import 'package:ocr_scanner_app/features/ocr/domain/repositories/text_recognition_repository.dart';
import 'package:ocr_scanner_app/features/shared_image_picker/domain/repositories/pick_image_repository.dart';

class FakePickImageRepository implements PickImageRepository {
  FakePickImageRepository(this.result);

  PickImageResult result;

  @override
  Future<PickImageResult> pickFromCamera() async => result;

  @override
  Future<PickImageResult> pickFromGallery() async => result;
}

class FakeTextRecognitionRepository implements TextRecognitionRepository {
  FakeTextRecognitionRepository(this.result);

  TextRecognitionResult result;

  @override
  Future<TextRecognitionResult> recognizeLatinFromFilePath(String imagePath) async {
    return result;
  }
}
