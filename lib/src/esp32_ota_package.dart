import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/core/ota_client.dart';
import 'package:flutter_ota/src/core/ota_protocol.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/firmware/asset_firmware_source.dart';
import 'package:flutter_ota/src/firmware/file_picker_firmware_source.dart';
import 'package:flutter_ota/src/firmware/url_firmware_source.dart';
import 'package:flutter_ota/src/models/constants.dart';
import 'package:flutter_ota/src/models/firmware_type.dart';
import 'package:flutter_ota/src/models/ota_package.dart';
import 'package:flutter_ota/src/models/update_type.dart';
import 'package:flutter_ota/src/protocol/arduino_ota_protocol.dart';
import 'package:flutter_ota/src/protocol/espidf_ota_protocol.dart';
import 'package:flutter_ota/src/transport/ble_ota_transport.dart';

/// ESP32 OTA client backed by the ESP-IDF and Arduino BLE protocols.
///
/// Backward-compatible facade over [OtaClient] that preserves the original
/// `updateFirmware(device, updateType, firmwareType, …)` API.
class Esp32OtaPackage implements OtaPackage {
  Esp32OtaPackage(this.notifyCharacteristic, this.writeCharacteristic);

  final BluetoothCharacteristic notifyCharacteristic;
  final BluetoothCharacteristic writeCharacteristic;

  OtaClient? _activeClient;
  StreamSubscription<int>? _progressSubscription;

  /// Set before the first `await` in [updateFirmware]; cleared in `finally`.
  bool _updateInFlight = false;

  StreamController<int> _percentageController =
      StreamController<int>.broadcast();

  @override
  Stream<int> get percentageStream => _percentageController.stream;

  @override
  bool get isUpdating =>
      _updateInFlight || (_activeClient?.isUpdating ?? false);

  @override
  bool get firmwareUpdate => _activeClient?.firmwareUpdate ?? false;

  @override
  Future<void> cancelUpdate() async {
    await _activeClient?.cancel();
  }

  @override
  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    await _activeClient?.dispose();
    _activeClient = null;
    _updateInFlight = false;
    if (!_percentageController.isClosed) {
      await _percentageController.close();
    }
  }

  @override
  Future<void> updateFirmware(
    BluetoothDevice device,
    UpdateType updateType,
    FirmwareType firmwareType, {
    String? uri,
    int mtuSize = 500,
  }) async {
    if (_updateInFlight || (_activeClient?.isUpdating ?? false)) {
      throw OtaException(
        'An OTA update is already in progress. Wait for it to finish or call '
        'cancelUpdate() before starting another.',
      );
    }
    _updateInFlight = true;

    try {
      if (firmwareType != FirmwareType.filepicker &&
          (uri == null || uri.isEmpty)) {
        throw OtaException('uri is required for the specified firmware type.');
      }

      final OtaProtocol protocol = _protocolFor(updateType);
      if (mtuSize < 1 || mtuSize > protocol.maxWriteSize) {
        throw OtaException(
          'mtuSize must be between 1 and ${protocol.maxWriteSize} bytes for '
          '${updateType.name} (got $mtuSize).',
        );
      }

      if (_percentageController.isClosed) {
        _percentageController = StreamController<int>.broadcast();
      }

      await _progressSubscription?.cancel();

      final BleOtaTransport transport = BleOtaTransport(
        device: device,
        notifyCharacteristic: notifyCharacteristic,
        writeCharacteristic: writeCharacteristic,
      );

      final OtaClient client = OtaClient(
        transport: transport,
        protocol: protocol,
        source: _sourceFor(firmwareType, uri),
      );
      _activeClient = client;

      _progressSubscription = client.percentageStream.listen((value) {
        if (_percentageController.isClosed) return;
        _percentageController.add(value);
        if (value == cancelledValue || value == failedValue || value == 100) {
          _percentageController.close();
        }
      });

      await client.run(mtuSize: mtuSize);
    } finally {
      _updateInFlight = false;
    }
  }

  OtaProtocol _protocolFor(UpdateType updateType) {
    return switch (updateType) {
      UpdateType.espidf => EspIdfOtaProtocol(),
      UpdateType.arduino => ArduinoOtaProtocol(),
    };
  }

  FirmwareSource _sourceFor(FirmwareType firmwareType, String? uri) {
    return switch (firmwareType) {
      FirmwareType.assets => AssetFirmwareSource(uri!),
      FirmwareType.filepicker => FilePickerFirmwareSource(),
      FirmwareType.url => UrlFirmwareSource(uri!),
    };
  }
}
