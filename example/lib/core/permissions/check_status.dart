import 'dart:io';

import 'bluetooth_adapter.dart';
import 'location_enable.dart';
import 'permissions.dart';


class PermissionEnable {
  Future<bool> check() async {
    bool serviceEnabled = false;
    bool checkBlueTooth = false;
    bool permissionGranted = false;

    checkBlueTooth = await BluetoothAdapter().enableBT();
    serviceEnabled = await LocationPermission().enable();

    if (Platform.isIOS) {
      if (serviceEnabled && checkBlueTooth) {
        return true;
      } else {
        await LocationPermission().enable();
        return false;
      }
    } else {
      permissionGranted = await PermissionsStatus().status();

      if (permissionGranted && serviceEnabled && checkBlueTooth) {
        return true;
      } else {
        return false;
      }
    }
  }
}
