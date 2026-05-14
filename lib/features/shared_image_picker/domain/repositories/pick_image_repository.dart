import 'package:equatable/equatable.dart';

abstract class PickImageRepository {
  Future<PickImageResult> pickFromCamera();

  Future<PickImageResult> pickFromGallery();
}

sealed class PickImageResult extends Equatable {
  const PickImageResult();

  @override
  List<Object?> get props => [];
}

final class PickImageSuccess extends PickImageResult {
  const PickImageSuccess(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

final class PickImageCancelled extends PickImageResult {
  const PickImageCancelled();
}

final class PickImageFailure extends PickImageResult {
  const PickImageFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
