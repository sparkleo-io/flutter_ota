//    data/ble_repository.dart
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleRepository {
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  Future<void> writeDataCharacteristic(BluetoothCharacteristic characteristic, Uint8List data) async {
    await characteristic.write(data);
  }

  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  Stream<List<BluetoothDevice>> scanDevices() {
    return flutterBlue.scanResults.map((results) => results.map((result) => result.device).toList());
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
  }

  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }

  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }
}
