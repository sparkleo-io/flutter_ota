import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_chunker.dart';
import 'package:flutter_ota/src/core/firmware_hash.dart';
import 'package:flutter_ota/src/core/ota_protocol.dart';
import 'package:flutter_ota/src/core/ota_transport.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/logging/ota_logger.dart';
import 'package:flutter_ota/src/models/constants.dart';
import 'package:flutter_ota/src/models/firmware_integrity.dart';

/// Arduino OTA transfer logic.
///
/// Terminology used in this protocol:
/// * **Firmware segment** — a fixed-size slice of the binary (see
///   [firmwareSegmentSize]) that the device acknowledges before requesting the
///   next one.
/// * **BLE packet** — one characteristic write within a segment (`mtuSize` bytes
///   of payload plus the 2-byte `0xFB` header).
class ArduinoOtaProtocol implements OtaProtocol {
  /// Creates an Arduino protocol instance.
  ///
  /// Pass [integrity] to enable optional post-flash SHA features that the
  /// paired firmware understands. Default is [FirmwareIntegrityConfig.none].
  ArduinoOtaProtocol({this.integrity = FirmwareIntegrityConfig.none});

  /// Bytes of firmware sent per device-acknowledged segment.
  static const int firmwareSegmentSize = 16000;

  /// Integrity features active for this session.
  final FirmwareIntegrityConfig integrity;

  StreamSubscription<Uint8List>? _subscription;
  Completer<bool>? _updateCompleter;
  bool _postTransferIntegritySent = false;

  @override
  int get maxWriteSize => maxMtuSize - arduinoHeaderSize;

  @override
  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    final Completer<bool>? completer = _updateCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    _updateCompleter = null;
  }

  @override
  Future<bool> performUpdate({
    required OtaTransport transport,
    required Uint8List firmware,
    required int mtuSize,
    required bool Function() isCancelRequested,
    required void Function(int percent) onProgress,
  }) async {
    otaLogger.i('Starting Arduino OTA — chunk size (MTU): $mtuSize');
    otaLogger.d('Firmware length: ${firmware.length} bytes');
    if (integrity.features.isNotEmpty) {
      otaLogger.i('Integrity features: ${integrity.features}');
    }

    final int firmwareByteLength = firmware.length;
    final int totalSegmentCount = (firmwareByteLength / firmwareSegmentSize)
        .ceil();
    otaLogger.d(
      'Firmware length: $firmwareByteLength bytes, '
      'segments: $totalSegmentCount',
    );

    _updateCompleter = Completer<bool>();

    _subscription = transport.inbound.listen((value) async {
      if (isCancelRequested()) {
        otaLogger.w('OTA update cancelled while sending firmware');
        _completeUpdate(false);
        return;
      }

      try {
        verboseTrace('Received notification value: $value');
        if (value.isEmpty) {
          otaLogger.w('Ignoring empty Arduino OTA notification');
          return;
        }

        final int messageType = value[0];

        switch (messageType) {
          case 0x0F:
            otaLogger.i('OTA update complete');
            _completeUpdate(true);
            return;
          case arduinoHashMismatchOpcode:
            final List<int>? expected = integrity.resolvedExpectedSha256;
            final String transferredHex = sha256ToHex(sha256Of(firmware));
            final String expectedHex = expected != null
                ? sha256ToHex(expected)
                : '(none configured)';
            otaLogger.e(
              'Device reported post-flash SHA-256 mismatch.\n'
              '  Expected (sent to device): $expectedHex\n'
              '  SHA-256 of bytes transferred by app: $transferredHex\n'
              '  If those two differ → wrong expectedSha256 on the app/server.\n'
              '  If they match → device hashed a different flash region/content '
              '(or transfer corruption).',
            );
            _failUpdateWithException(DeviceHashMismatchException());
            return;
          case 0xF2:
            otaLogger.i('New bin file installation begins on ESP32');
            return;
          case 0xF1:
            if (value.length < 3) {
              _failUpdate('Short segment request (length ${value.length})');
              return;
            }

            final int segmentIndex = (value[1] << 8) | value[2];
            if (segmentIndex >= totalSegmentCount) {
              _failUpdate(
                'Out-of-range segment index $segmentIndex '
                '(expected 0..${totalSegmentCount - 1})',
              );
              return;
            }

            final int roundedProgress =
                ((segmentIndex / totalSegmentCount) * 100).round().clamp(0, 99);
            otaLogger.d(
              'Segment $segmentIndex/$totalSegmentCount — $roundedProgress%',
            );
            onProgress(roundedProgress);

            otaLogger.d('Next segment requested: $segmentIndex');
            await _sendFirmwareSegment(
              transport,
              segmentIndex,
              firmware,
              mtuSize,
              isCancelRequested,
            );
            await _sendPostTransferIntegrityIfNeeded(
              transport,
              firmware,
              segmentIndex: segmentIndex,
              totalSegmentCount: totalSegmentCount,
            );
            return;
          default:
            if (value.length < 3) {
              otaLogger.w(
                'Ignoring unknown short Arduino OTA notification '
                '(type 0x${messageType.toRadixString(16)}, length ${value.length})',
              );
              return;
            }
            _failUpdate(
              'Unknown Arduino OTA opcode 0x${messageType.toRadixString(16)}',
            );
        }
      } catch (e) {
        otaLogger.e('Arduino OTA failed', error: e);
        _completeUpdate(false);
      }
    });

    try {
      _postTransferIntegritySent = false;
      await _sendHandshake(
        transport,
        firmwareByteLength: firmwareByteLength,
        totalSegmentCount: totalSegmentCount,
        mtuSize: mtuSize,
      );

      // Match ESP-IDF PostSHA: transfer the full image first, then send the
      // expected digest (0xF9 / 0xFA) for device-side flash verification.
      const int initialSegmentIndex = 0;
      await _sendFirmwareSegment(
        transport,
        initialSegmentIndex,
        firmware,
        mtuSize,
        isCancelRequested,
      );
      await _sendPostTransferIntegrityIfNeeded(
        transport,
        firmware,
        segmentIndex: initialSegmentIndex,
        totalSegmentCount: totalSegmentCount,
      );
      onProgress(0);
      otaLogger.d(
        'Started segment $initialSegmentIndex/$totalSegmentCount — 0%',
      );

      return await _updateCompleter!.future;
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _updateCompleter = null;
    }
  }

  /// After the last firmware segment, send `0xF9` / `0xFA` when
  /// [IntegrityFeature.shaAfterFlash] is enabled (ESP-IDF-aligned timing).
  Future<void> _sendPostTransferIntegrityIfNeeded(
    OtaTransport transport,
    Uint8List firmware, {
    required int segmentIndex,
    required int totalSegmentCount,
  }) async {
    if (_postTransferIntegritySent) return;
    if (totalSegmentCount <= 0 || segmentIndex != totalSegmentCount - 1) {
      return;
    }
    if (!integrity.verifyAfterFlash) return;

    _postTransferIntegritySent = true;

    int flags = 0;
    flags |= integrityFlagShaAfterFlash;

    final Uint8List flagsPacket = Uint8List.fromList([
      arduinoIntegrityFlagsOpcode,
      flags,
    ]);
    await transport.writeData(flagsPacket);
    otaLogger.d('Sent integrity flags: 0x${flags.toRadixString(16)}');

    final List<int> digest =
        integrity.resolvedExpectedSha256 ?? sha256Of(firmware);
    final String digestHex = sha256ToHex(digest);
    otaLogger.i(
      'SHA-256 to send to firmware after image (post-flash verify): $digestHex',
    );
    final Uint8List hashPacket = Uint8List(1 + sha256DigestSize)
      ..[0] = arduinoExpectedHashOpcode;
    hashPacket.setRange(1, 1 + sha256DigestSize, digest);
    await transport.writeData(hashPacket);
    otaLogger.d('Sent expected SHA-256 for post-flash verify: $digestHex');
  }

  void _completeUpdate(bool succeeded) {
    final Completer<bool>? completer = _updateCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(succeeded);
    }
  }

  /// Completes [performUpdate] with [error] so [OtaClient] can emit
  /// [failedValue] and rethrow typed integrity failures to the caller.
  void _failUpdateWithException(Object error) {
    otaLogger.e('Arduino OTA failed', error: error);
    final Completer<bool>? completer = _updateCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void _failUpdate(String reason, [Object? cause]) {
    otaLogger.e('Arduino OTA failed: $reason', error: cause);
    _completeUpdate(false);
  }

  /// Sends one firmware segment as a sequence of BLE packets, then the `0xFC`
  /// segment-complete marker.
  Future<void> _sendFirmwareSegment(
    OtaTransport transport,
    int segmentIndex,
    Uint8List firmware,
    int mtuSize,
    bool Function() isCancelRequested,
  ) async {
    if (isCancelRequested()) {
      otaLogger.w('sendFirmwareSegment aborted due to cancellation');
      return;
    }

    final int segmentStart = segmentIndex * firmwareSegmentSize;
    int segmentEnd = (segmentIndex + 1) * firmwareSegmentSize;
    if (firmware.length < segmentEnd) {
      segmentEnd = firmware.length;
    }
    final int segmentLength = segmentEnd - segmentStart;
    final Uint8List segment = Uint8List.sublistView(
      firmware,
      segmentStart,
      segmentEnd,
    );

    final int totalSegmentCount = (firmware.length / firmwareSegmentSize)
        .ceil();
    final int overallProgress = totalSegmentCount == 0
        ? 0
        : (((segmentIndex + 1) / totalSegmentCount) * 100).round();
    otaLogger.d(
      'Segment $segmentIndex: ${chunkCount(segmentLength, mtuSize)} BLE '
      'packets — overall $overallProgress%',
    );

    int packetIndex = 0;
    for (final Uint8List payload in chunkFirmware(segment, mtuSize)) {
      verboseTrace(
        'BLE packet $packetIndex in segment $segmentIndex '
        '— overall $overallProgress%',
      );

      final Uint8List packet = Uint8List(payload.length + arduinoHeaderSize);
      packet[0] = 0xFB;
      packet[1] = packetIndex;
      packet.setRange(
        arduinoHeaderSize,
        arduinoHeaderSize + payload.length,
        payload,
      );

      verboseTrace(
        'Writing BLE packet, payload length is ${packet.length} '
        '— overall $overallProgress%',
      );
      await transport.writeData(packet);
      packetIndex++;
    }

    final Uint8List segmentCompleteMarker = Uint8List.fromList([
      0xFC,
      (segmentLength ~/ 256),
      (segmentLength % 256),
      (segmentIndex ~/ 256),
      (segmentIndex % 256),
    ]);

    await transport.writeData(segmentCompleteMarker);
    verboseTrace('Sent segment-complete marker: $segmentCompleteMarker');
  }

  /// Sends the Arduino OTA handshake (`0xFD`, file size, OTA info).
  Future<void> _sendHandshake(
    OtaTransport transport, {
    required int firmwareByteLength,
    required int totalSegmentCount,
    required int mtuSize,
  }) async {
    final Uint8List startCommand = Uint8List(1)..[0] = 0xFD;
    await transport.writeData(startCommand);

    final Uint8List fileSizePacket = Uint8List(5)
      ..[0] = 0xFE
      ..[1] = (firmwareByteLength >> 24) & 0xFF
      ..[2] = (firmwareByteLength >> 16) & 0xFF
      ..[3] = (firmwareByteLength >> 8) & 0xFF
      ..[4] = firmwareByteLength & 0xFF;
    verboseDebug('Sending file size packet: $fileSizePacket');
    await transport.writeData(fileSizePacket);

    final Uint8List otaInfoPacket = Uint8List(5)
      ..[0] = 0xFF
      ..[1] = totalSegmentCount ~/ 256
      ..[2] = totalSegmentCount % 256
      ..[3] = mtuSize ~/ 256
      ..[4] = mtuSize % 256;
    verboseDebug('Sending OTA info packet: $otaInfoPacket');
    await transport.writeData(otaInfoPacket);
  }
}
