import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ota_ble_constants.dart';

typedef OtaCharacteristics = ({
  BluetoothCharacteristic notify,
  BluetoothCharacteristic write,
});

OtaCharacteristics? findOtaCharacteristics(List<BluetoothService> services) {
  for (final service in services) {
    if (service.uuid.toString() != OtaBleConstants.serviceUuid) continue;

    BluetoothCharacteristic? notify;
    BluetoothCharacteristic? write;
    for (final characteristic in service.characteristics) {
      final String uuid = characteristic.uuid.toString();
      if (uuid == OtaBleConstants.notifyCharacteristicUuid) {
        notify = characteristic;
      } else if (uuid == OtaBleConstants.writeCharacteristicUuid) {
        write = characteristic;
      }
    }

    if (notify != null && write != null) {
      return (notify: notify, write: write);
    }
  }
  return null;
}

Future<void> prepareOtaMtu(BluetoothDevice device) async {
  if (Platform.isAndroid) {
    await device.requestMtu(OtaBleConstants.androidRequestedMtu);
  }
}
