import 'dart:io';

import 'bluetooth_adapter.dart';
import 'location_enable.dart';
import 'permissions.dart';

class PermissionEnable {
  Future<bool> check() async {
    final bool checkBlueTooth = await BluetoothAdapter().enableBT();

    // iOS does NOT require location services or permission to scan for BLE
    // devices — that is an Android requirement. Calling the location plugin on
    // iOS only triggers the CLLocationManager main-thread warning and wrongly
    // blocks scanning, so on iOS we gate solely on Bluetooth being on.
    if (Platform.isIOS) {
      return checkBlueTooth;
    }

    final bool serviceEnabled = await LocationPermission().enable();
    final bool permissionGranted = await PermissionsStatus().status();

    return checkBlueTooth && serviceEnabled && permissionGranted;
  }
}
