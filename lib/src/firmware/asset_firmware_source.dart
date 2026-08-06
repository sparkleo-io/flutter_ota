import 'package:flutter/services.dart';

import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/firmware/firmware_image.dart';

/// Loads firmware from a bundled `.bin` or `.img` asset path.
class AssetFirmwareSource implements FirmwareSource {
  AssetFirmwareSource(this.path);

  final String path;

  @override
  Future<Uint8List> load() async {
    validateFirmwareImage(path);
    final ByteData fileData = await rootBundle.load(path);
    return fileData.buffer.asUint8List(
      fileData.offsetInBytes,
      fileData.lengthInBytes,
    );
  }
}
