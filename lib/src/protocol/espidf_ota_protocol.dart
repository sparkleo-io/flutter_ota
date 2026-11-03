import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_chunker.dart';
import 'package:flutter_ota/src/core/ota_protocol.dart';
import 'package:flutter_ota/src/core/ota_transport.dart';
import 'package:flutter_ota/src/logging/ota_logger.dart';
import 'package:flutter_ota/src/models/constants.dart';

/// ESP-IDF OTA transfer logic.
class EspIdfOtaProtocol implements OtaProtocol {
  @override
  int get maxWriteSize => maxMtuSize;

  @override
  Future<void> cancel() async {
    // Cancellation is cooperative via [isCancelRequested] in [performUpdate].
  }

  @override
  Future<bool> performUpdate({
    required OtaTransport transport,
    required Uint8List firmware,
    required int mtuSize,
    required bool Function() isCancelRequested,
    required void Function(int percent) onProgress,
  }) async {
    otaLogger.i('Starting ESP-IDF OTA — chunk size (MTU): $mtuSize');

    final int totalChunks = chunkCount(firmware.length, mtuSize);

    final Uint8List mtuPacket = Uint8List(2)
      ..[0] = mtuSize & 0xFF
      ..[1] = (mtuSize >> 8) & 0xFF;

    await transport.writeData(mtuPacket);
    await transport.writeControl(Uint8List.fromList([1]));

    Uint8List value = await transport.readControl().timeout(
      const Duration(seconds: 10),
    );
    if (value.isEmpty) {
      otaLogger.e('OTA update failed: empty control characteristic read');
      return false;
    }
    otaLogger.d('Control characteristic returned: ${value[0]}');

    int chunkIndex = 0;
    otaLogger.i('Sending $totalChunks firmware chunks');
    for (final Uint8List chunk in chunkFirmware(firmware, mtuSize)) {
      if (isCancelRequested()) {
        otaLogger.w('OTA update cancelled while sending firmware');
        return false;
      }

      await transport.writeData(chunk);
      chunkIndex++;

      final double progress = (chunkIndex / totalChunks) * 100;
      final int roundedProgress = progress.round();
      otaLogger.d('Writing chunk $chunkIndex/$totalChunks — $roundedProgress%');
      onProgress(roundedProgress);
    }

    await transport.writeControl(Uint8List.fromList([4]));

    value = await transport.readControl().timeout(const Duration(seconds: 600));
    if (value.isEmpty) {
      otaLogger.e('OTA update failed: empty final control characteristic read');
      return false;
    }
    otaLogger.d('Control characteristic returned: ${value[0]}');

    if (value[0] == 5) {
      otaLogger.i('OTA update finished successfully');
      return true;
    }

    otaLogger.e('OTA update failed (unexpected status ${value[0]})');
    return false;
  }
}
