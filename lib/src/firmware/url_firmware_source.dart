import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/firmware/firmware_image.dart';

/// Downloads firmware from an HTTP(S) URL and validates the payload.
class UrlFirmwareSource implements FirmwareSource {
  UrlFirmwareSource(this.url);

  final String url;

  @override
  Future<Uint8List> load() async {
    return downloadAndValidateFirmware(url);
  }
}
