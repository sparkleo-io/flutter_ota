import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/firmware/firmware_image.dart';
import 'package:flutter_ota/src/logging/ota_logger.dart';

/// Loads firmware from a user-selected `.bin` or `.img` file via the platform
/// file picker.
class FilePickerFirmwareSource implements FirmwareSource {
  @override
  Future<Uint8List> load() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedFirmwareExtensions.toList(),
      // Populate `bytes` so platforms/picker modes that do not expose a file
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      otaLogger.w('No firmware file selected');
      return Uint8List(0);
    }

    final file = result.files.first;
    otaLogger.d('Selected firmware file: ${file.name}');
    validateFirmwareImage(file.name);

    try {
      final Uint8List? bytes = file.bytes;
      if (bytes != null) {
        return Uint8List.fromList(bytes);
      }

      final String? path = file.path;
      if (path != null) {
        return Uint8List.fromList(await File(path).readAsBytes());
      }

      throw OtaException(
        'Selected firmware file "${file.name}" has no accessible bytes or '
        'path. Try a different file or picker mode.',
      );
    } on OtaException {
      rethrow;
    } catch (e) {
      throw OtaException('Error getting firmware data', e);
    }
  }
}
