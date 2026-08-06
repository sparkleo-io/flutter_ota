import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE read/write helpers used by the OTA protocols.
class BleRepository {
  Future<void> writeDataCharacteristic(
    BluetoothCharacteristic characteristic,
    Uint8List data,
  ) async {
    await characteristic.write(data);
  }

  Future<List<int>> readCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    return characteristic.read();
  }

  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }

  Future<void> setNotifyValue(
    BluetoothCharacteristic characteristic,
    bool enabled,
  ) async {
    await characteristic.setNotifyValue(enabled);
  }
}
