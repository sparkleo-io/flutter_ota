import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionsStatus {
  static Future<bool> _locationStatus() async {
    PermissionStatus permissionStatus = await Permission.location.status;
    if (permissionStatus.isGranted) {
      return true;
    } else {
      await Permission.location.request();
      return false;
    }
  }

  static Future<bool> _bleConnectStatus() async {
    PermissionStatus permissionStatus =
        await Permission.bluetoothConnect.status;
    if (permissionStatus.isGranted) {
      return true;
    } else {
      await Permission.bluetoothConnect.request();
      return false;
    }
  }

  static Future<bool> _bleScanStatus() async {
    PermissionStatus permissionStatus = await Permission.bluetoothScan.status;
    if (permissionStatus.isGranted) {
      return true;
    } else {
      await Permission.bluetoothScan.request();
      return false;
    }
  }

  Future<bool> status() async {
    if (Platform.isAndroid) {
      final locationPStatus = await _locationStatus();
      final bleScanPStatus = await _bleScanStatus();
      final bleConnectPStatus = await _bleConnectStatus();
      if (locationPStatus &&
          bleConnectPStatus &&
          bleConnectPStatus &&
          bleScanPStatus) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }
}
