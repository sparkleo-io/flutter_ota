import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothAdapter {
  static bool isBluetoothOn = false;

  static void initBleStateStream() {
    /**
     * call this method in main file or when you initialize dependencies it should be done
     * before calling the check method
     */

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        isBluetoothOn = true;
      } else {
        isBluetoothOn = false;
      }
    });
  }

  Future<bool> enableBT() async {
    debugPrint("isbluettoth turn on is $isBluetoothOn");
    if (Platform.isAndroid) {
      if (isBluetoothOn) {
        return true;
      } else {
        try {
          await FlutterBluePlus.turnOn();
          return isBluetoothOn;
        } catch (e) {
          // show toast to turn on bluetooth
          return false;
        }
      }
    } else {
      // iOS apps cannot turn Bluetooth on programmatically. The cached
      // `isBluetoothOn` flag can still be stale here because the adapter state
      // starts as `unknown` until CBCentralManager initializes and the state
      // stream may not have emitted yet. Resolve the real state by waiting for
      // the first definitive (non-`unknown`) value instead of trusting the flag.
      if (isBluetoothOn) {
        return true;
      }
      try {
        final state = await FlutterBluePlus.adapterState
            .firstWhere((s) => s != BluetoothAdapterState.unknown)
            .timeout(const Duration(seconds: 5));
        isBluetoothOn = state == BluetoothAdapterState.on;
        debugPrint("iOS resolved adapter state: $state");
        return isBluetoothOn;
      } catch (e) {
        // Timed out or errored before a definitive state arrived.
        debugPrint("iOS Bluetooth state could not be resolved: $e");
        return false;
      }
    }
  }
  /*Future<bool> enableBT() async {
    bool androidAbove12 = await _androidVerAbove12();

    bool bleEnable =
        await (FlutterBluePlus.adapterState.first) == BluetoothAdapterState.on
            ? true
            : false;

    if (bleEnable) {
      return true;
    } else {
      if (androidAbove12) {
        showToast("Please turn on bluetooth");
        return false;
      } else {
        await FlutterBluePlus.turnOn();
        return await (FlutterBluePlus.adapterState.first) ==
                BluetoothAdapterState.on
            ? true
            : false;
      }
    }
  }*/

  // static Future<bool> _androidVerAbove12() async {
  //   final deviceInfo = await DeviceInfoPlugin().androidInfo;
  //   final aInfo = deviceInfo.version.release;
  //   double ver = double.parse(aInfo);
  //   if (ver > 13) {
  //     return true;
  //   } else {
  //     return false;
  //   }
  // }
}
