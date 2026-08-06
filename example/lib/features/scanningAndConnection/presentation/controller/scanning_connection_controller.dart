import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/toast/show_toast.dart';

class HomePageController extends GetxController {
  RxString selectedLeoDevice = "".obs;

  RxList<BluetoothDevice> scannedDevicesList = <BluetoothDevice>[].obs;
  RxDouble screenHeight = 0.0.obs;
  BluetoothDevice? gBleDevice;
  RxList<BluetoothService> gBleServices = <BluetoothService>[].obs;
  BluetoothCharacteristic? charRep;
  RxBool gIsDeviceConnected = false.obs;
  bool showProgressDialog = true;

  RxList<BluetoothDevice> connectedDevice = <BluetoothDevice>[].obs;

  StreamSubscription? streamSubscription;

  /// Keys used to persist the last successfully connected device.
  static const String _lastDeviceIdKey = 'last_connected_device_id';
  static const String _lastDeviceNameKey = 'last_connected_device_name';

  /// Remote id / name of the last device we successfully connected to.
  /// These are empty when no device has been connected before.
  final RxString lastDeviceId = ''.obs;
  final RxString lastDeviceName = ''.obs;

  /// Whether an auto-connect attempt is currently running.
  final RxBool isAutoConnecting = false.obs;

  /// Whether a previously connected device is remembered.
  bool get hasLastDevice => lastDeviceId.value.isNotEmpty;

  /// Loads the last connected device info from persistent storage.
  Future<void> loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    lastDeviceId.value = prefs.getString(_lastDeviceIdKey) ?? '';
    lastDeviceName.value = prefs.getString(_lastDeviceNameKey) ?? '';
    debugPrint(
      "Loaded last device: ${lastDeviceName.value} (${lastDeviceId.value})",
    );
  }

  /// Clears the persisted last-connected device so the app will NOT
  /// auto-connect to it on the next launch.
  Future<void> clearLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastDeviceIdKey);
    await prefs.remove(_lastDeviceNameKey);
    lastDeviceId.value = '';
    lastDeviceName.value = '';
    debugPrint("Cleared last device");
  }

  /// Disconnects the currently connected device (if any) and resets the
  /// in-memory connection state.
  Future<void> disconnectDevice() async {
    final device = gBleDevice;
    if (device != null) {
      try {
        if (device.isConnected) {
          await device.disconnect();
        }
      } catch (e) {
        debugPrint("Disconnect failed: $e");
      }
    }
    gIsDeviceConnected.value = false;
    connectedDevice.clear();
  }

  /// Persists the given device so it can be auto-connected to next time.
  Future<void> _saveLastDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final String id = device.remoteId.str;
    final String name = device.platformName.isNotEmpty
        ? device.platformName
        : id;
    await prefs.setString(_lastDeviceIdKey, id);
    await prefs.setString(_lastDeviceNameKey, name);
    lastDeviceId.value = id;
    lastDeviceName.value = name;
    debugPrint("Saved last device: $name ($id)");
  }

  /// Attempts to reconnect to the most recently connected device without
  /// requiring a fresh scan. Returns true if the connection succeeded.
  Future<bool> autoConnectToLastDevice() async {
    await loadLastDevice();
    if (!hasLastDevice) {
      showToast('No previously connected device');
      return false;
    }

    isAutoConnecting.value = true;
    try {
      final device = BluetoothDevice.fromId(lastDeviceId.value);
      gBleDevice = device;
      gIsDeviceConnected.value = false;

      final connected = await connectToDevice();
      gIsDeviceConnected.value = connected;
      if (connected) {
        connectedDevice.value = [device];
      }
      return connected;
    } catch (e) {
      debugPrint("Auto-connect failed: $e");
      showToast('Auto-connect failed');
      return false;
    } finally {
      isAutoConnecting.value = false;
    }
  }

  Future<void> scanningMethod() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    scannedDevicesList.clear();
    await streamSubscription?.cancel();

    streamSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final ScanResult result in results) {
        final device = result.device;
        if (device.advName.isEmpty || scannedDevicesList.contains(device)) {
          continue;
        }

        scannedDevicesList.add(device);
        device.connectionState.listen((connectionState) {
          if (connectionState == BluetoothConnectionState.connected) {
            scannedDevicesList.remove(device);
          }
        });
      }
    });

    await FlutterBluePlus.startScan();
  }

  Future<bool> connectToDevice() async {
    await FlutterBluePlus.stopScan();

    final device = gBleDevice;
    if (device == null) {
      showToast('No device selected');
      return false;
    }

    try {
      // Start clean so a stale connection can't break discovery.
      if (device.isConnected) {
        await device.disconnect();
      }

      await device.connect(autoConnect: false, license: License.nonprofit);

      // Negotiate a larger MTU before discovering services (Android only).
      if (Platform.isAndroid) {
        await device.requestMtu(200);
      }

      gBleServices.assignAll(await device.discoverServices());
      gIsDeviceConnected.value = true;
      await _saveLastDevice(device);
      showToast('Connected');
      return true;
    } catch (e) {
      debugPrint('Connection failed: $e');
      gIsDeviceConnected.value = false;
      try {
        await device.disconnect();
      } catch (_) {
        // Ignore: device may already be disconnected.
      }
      showToast('Connection failed');
      return false;
    }
  }
}
