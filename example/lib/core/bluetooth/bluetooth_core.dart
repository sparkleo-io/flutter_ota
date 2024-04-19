import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothCore {

  Stream<ScanResult> scan() => FlutterBluePlus.scan();

  Future connect(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
  }

  Future<List<BluetoothService>> getServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }

  Future disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }

  Future stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}