import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_hash.dart';
import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/core/ota_protocol.dart';
import 'package:flutter_ota/src/core/ota_transport.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/logging/ota_logger.dart';
import 'package:flutter_ota/src/models/constants.dart';
import 'package:flutter_ota/src/models/firmware_integrity.dart';

/// Generic OTA orchestrator that wires together a transport, protocol, and
/// firmware source.
///
/// Owns progress streaming, cancellation, and terminal-state emission so
/// transport/protocol implementations stay focused on transfer logic.
class OtaClient {
  OtaClient({
    required OtaTransport transport,
    required OtaProtocol protocol,
    required FirmwareSource source,
  }) : _transport = transport,
       _protocol = protocol,
       _source = source;

  final OtaTransport _transport;
  final OtaProtocol _protocol;
  final FirmwareSource _source;

  bool _cancelRequested = false;
  bool _firmwareUpdateSucceeded = false;
  bool _isUpdating = false;

  final StreamController<int> _percentageController =
      StreamController<int>.broadcast();

  /// Stream of progress percentages and terminal values.
  ///
  /// Emits `0`–`99` during transfer, [cancelledValue] on cancellation,
  /// [failedValue] on failure, and `100` only after the device acknowledges
  /// a successful update.
  Stream<int> get percentageStream => _percentageController.stream;

  /// Whether an OTA update is currently in progress.
  bool get isUpdating => _isUpdating;

  /// Whether the most recent OTA update completed successfully.
  bool get firmwareUpdate => _firmwareUpdateSucceeded;

  /// Runs the OTA update.
  ///
  /// Pass [integrity] to optionally verify the binary before transfer
  /// ([IntegrityFeature.shaBeforeTransfer]). Post-flash SHA is handled by the
  /// [OtaProtocol] when configured on that protocol instance; device-reported
  /// mismatches surface as [DeviceHashMismatchException] (after
  /// [failedValue] is emitted), matching pre-transfer
  /// [FirmwareHashMismatchException] handling.
  Future<void> run({
    required int mtuSize,
    FirmwareIntegrityConfig integrity = FirmwareIntegrityConfig.none,
  }) async {
    integrity.validate();

    if (mtuSize < 1 || mtuSize > _protocol.maxWriteSize) {
      throw OtaException(
        'mtuSize must be between 1 and ${_protocol.maxWriteSize} bytes '
        '(got $mtuSize).',
      );
    }

    // Check-and-set before any await so concurrent run() calls cannot both
    // proceed and interleave writes on the shared transport.
    if (_isUpdating) {
      throw OtaException(
        'An OTA update is already in progress. Wait for it to finish or call '
        'cancel() before starting another.',
      );
    }
    _cancelRequested = false;
    _firmwareUpdateSucceeded = false;
    _isUpdating = true;

    Object? rethrowError;

    try {
      final Uint8List firmware = await _source.load();
      if (firmware.isEmpty) {
        throw EmptyFirmwareException();
      }

      if (integrity.verifyBeforeTransfer) {
        final List<int> expected = integrity.resolvedExpectedSha256!;
        final Uint8List actual = sha256Of(firmware);
        otaLogger.i(
          'Pre-transfer SHA-256: ${sha256ToHex(actual)} '
          '(expected ${sha256ToHex(expected)})',
        );
        assertSha256Matches(
          actual: actual,
          expected: expected,
          phase: 'before-transfer',
        );
      }

      await _transport.prepare(mtuSize: mtuSize);
      await _transport.startInbound();

      final bool succeeded = await _protocol.performUpdate(
        transport: _transport,
        firmware: firmware,
        mtuSize: mtuSize,
        isCancelRequested: () => _cancelRequested,
        onProgress: _emitPercentage,
      );

      if (_cancelRequested) {
        _firmwareUpdateSucceeded = false;
        _completeUpdate(cancelledValue);
        return;
      }

      _firmwareUpdateSucceeded = succeeded;
      _completeUpdate(succeeded ? 100 : failedValue);
    } catch (e) {
      // Setup / integrity failures: emit failedValue for UI, then rethrow so
      // callers can show the real reason (download HTML, empty binary, SHA
      // mismatch, unsupported image). Mid-transfer BLE faults stay stream-only.
      rethrowError = e is FirmwareIntegrityException ||
              e is FirmwareDownloadException ||
              e is EmptyFirmwareException ||
              e is UnsupportedFirmwareImageException
          ? e
          : null;
      _handleUpdateError(e);
    } finally {
      await _transport.dispose();
    }

    if (rethrowError != null) {
      throw rethrowError;
    }
  }

  /// Requests cancellation of an in-progress OTA update.
  Future<void> cancel() async {
    if (!_isUpdating) return;
    otaLogger.w('OTA update cancellation requested');
    _cancelRequested = true;
    await _protocol.cancel();
    _completeUpdate(cancelledValue);
  }

  /// Releases resources held by this instance.
  Future<void> dispose() async {
    if (!_percentageController.isClosed) {
      await _percentageController.close();
    }
  }

  void _emitPercentage(int value) {
    if (_percentageController.isClosed) return;
    _percentageController.add(value);
  }

  void _completeUpdate(int value) {
    if (_percentageController.isClosed) return;
    _isUpdating = false;
    _percentageController.add(value);
    _percentageController.close();
  }

  void _handleUpdateError(Object error) {
    // otaLogger.e(
    //   'OTA update aborted: Device either returned an error or did not acknowledge the operation. '
    //   'Some devices may not support acknowledgement.'
    //   'Please ensure the device firmware supports proper OTA acknowledgement flow.',
    // );
    otaLogger.e('OTA update aborted', error: error);
    _firmwareUpdateSucceeded = false;
    _completeUpdate(_cancelRequested ? cancelledValue : failedValue);
  }
}
