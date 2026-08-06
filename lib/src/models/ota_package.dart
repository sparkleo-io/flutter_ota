import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter_ota/src/models/constants.dart';
import 'package:flutter_ota/src/models/firmware_integrity.dart';
import 'package:flutter_ota/src/models/firmware_type.dart';
import 'package:flutter_ota/src/models/update_type.dart';

/// Contract for an OTA client that flashes firmware over BLE.
abstract class OtaPackage {
  /// Method to update firmware.
  ///
  /// [device]: The Bluetooth device to update firmware on.
  /// [updateType]: The type of update operation.
  /// [firmwareType]: The type of firmware to update.
  /// [uri]: The file path or URL of the firmware binary (optional). Required for
  ///   every [FirmwareType] except [FirmwareType.filepicker].
  /// [mtuSize]: The chunk size (in bytes) used to split the firmware into
  ///   packets sent to the device (optional). Must be at least 1 and not exceed
  ///   the BLE single-write limit: [maxMtuSize] (512) for [UpdateType.espidf],
  ///   or [maxMtuSize] - [arduinoHeaderSize] (510) for [UpdateType.arduino],
  ///   which adds a 2-byte packet header. Out-of-range values are rejected.
  /// [integrity]: Optional firmware integrity features (SHA-256 before
  ///   transfer, post-flash SHA-256). Defaults to
  ///   [FirmwareIntegrityConfig.none]. Enable only what the device firmware
  ///   supports — features combine freely.
  /// [saveOtaLogs]: When `true` (the default), OTA log lines for this run are
  ///   captured in memory and available via `otaSessionLogs` /
  ///   `otaSessionLogText` for in-app debug screens. When `false`, capture is
  ///   disabled for the run.
  Future<void> updateFirmware(
    BluetoothDevice device,
    UpdateType updateType,
    FirmwareType firmwareType, {
    String? uri,
    int mtuSize,
    FirmwareIntegrityConfig integrity,
    bool saveOtaLogs,
  });

  /// Whether the most recent OTA update completed successfully.
  ///
  /// Read-only; updated internally when an update reaches a terminal state.
  /// Prefer listening to [percentageStream] for progress and terminal values
  /// ([cancelledValue], [failedValue], or `100`).
  bool get firmwareUpdate;

  /// Stream to provide progress percentage.
  ///
  /// When an update is cancelled via [cancelUpdate], a value of [cancelledValue]
  /// (`-1`) is emitted so listeners can react to the cancellation. If the update
  /// fails because of a BLE error (e.g. the device disconnects mid-transfer or a
  /// write fails with a GATT error), [failedValue] (`-2`) is emitted instead of
  /// throwing, so the caller can update the UI without the app crashing.
  Stream<int> get percentageStream;

  /// Whether an OTA update is currently in progress.
  bool get isUpdating;

  /// Requests cancellation of an in-progress OTA update.
  ///
  /// This stops sending further firmware data and tears down any active
  /// notification subscription. It is safe to call even when no update is
  /// running. After cancelling, [cancelledValue] is emitted on
  /// [percentageStream].
  ///
  /// IMPORTANT: Cancelling only stops the app from sending data; it does NOT
  /// reset the OTA state machine on the ESP32, which is left mid-update. The
  /// caller MUST disconnect and reconnect (re-discovering services) before
  /// starting a new OTA on the same device. Starting another OTA on the same
  /// connection leaves the two sides out of sync and typically results in a BLE
  /// disconnect / GATT error.
  Future<void> cancelUpdate();

  /// Releases resources held by this instance.
  ///
  /// Cancels any active notification subscription and closes
  /// [percentageStream]. The package already disposes itself automatically when
  /// an update reaches a terminal state (success, failure, or cancellation), so
  /// you normally do NOT need to call this. Use it only to abandon an update
  /// that has not finished (e.g. on app shutdown). The instance must not be
  /// used after disposing.
  Future<void> dispose();
}
