import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class AudioFileSelection {
  final String path;
  final String name;
  final int sizeInBytes;
  final Uint8List? bytes;

  const AudioFileSelection({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    this.bytes,
  });
}

class DeviceCapabilitiesService {
  final ImagePicker _imagePicker;

  DeviceCapabilitiesService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  bool get hasCamera {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Selecciona una imagen de portada mediante ImagePicker encapsulado
  Future<String?> pickCoverPhoto({bool fromCamera = false}) async {
    try {
      final source = (fromCamera && hasCamera)
          ? ImageSource.camera
          : ImageSource.gallery;

      final XFile? file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      return file?.path;
    } catch (e) {
      debugPrint('Error en DeviceCapabilitiesService.pickCoverPhoto: $e');
      return null;
    }
  }

  /// Selecciona un archivo de audio (.mp3, .wav, .m4a) mediante FilePicker encapsulado
  Future<AudioFileSelection?> pickAudioFile() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final path = file.path ?? '';
        final size = await file.length() ?? file.lengthSync() ?? 0;
        final bytes = await file.readAsBytes();
        return AudioFileSelection(
          path: path,
          name: file.name,
          sizeInBytes: size,
          bytes: bytes,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error en DeviceCapabilitiesService.pickAudioFile: $e');
      return null;
    }
  }
}
