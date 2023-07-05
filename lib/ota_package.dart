import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ota_package/data/ble_repository.dart';


abstract class OtaPackage {
  Future<void> updateFirmware(String binFilePath, BluetoothDevice device);
}

class Esp32OtaPackage extends OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;

  Esp32OtaPackage(this.dataCharacteristic, this.controlCharacteristic);

  @override
  Future<void> updateFirmware(String binFilePath, BluetoothDevice device) async {
    final bleRepo = BleRepository();

    // Connect to the ESP32 device
    await bleRepo.connectToDevice(device);

    // Write packet size data on the dataCharacteristic
    int packetSize = await device.mtu.first;
    Uint8List byteList = Uint8List(2);
    byteList[0] = packetSize & 0xFF;
    byteList[1] = (packetSize >> 8) & 0xFF;
    await bleRepo.writeDataCharacteristic(dataCharacteristic, byteList);

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([1]));
    List<int> value = await bleRepo.readCharacteristic(controlCharacteristic);
    print('value returned is this ------- ${value[0]}');

    // Check if controlCharacteristic reads 0x02
    if (value[0] == 2) {
      // Write firmware until complete
      List<Uint8List> binaryChunks = await _readBinaryFile(binFilePath);
      print('this is length of binary chunks ----- ${binaryChunks.length}');
      int packageNumber = 0;
      for (Uint8List chunk in binaryChunks) {
        await bleRepo.writeDataCharacteristic(dataCharacteristic, chunk);
        packageNumber++;
        print('writing package number ${packageNumber} of ${binaryChunks.length} to ESP32');
      }
    }

    // Write x04 to the controlCharacteristic to finish the update process
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([4]));

    // Check if controlCharacteristic reads 0x05, indicating OTA update finished
    value = await bleRepo.readCharacteristic(controlCharacteristic);
    if (value[0] == 5) {
      print('OTA update finished');
    }
  }

  Future<List<Uint8List>> _readBinaryFile(String binFilePath) async {
    final fileData = await rootBundle.load(binFilePath);
    final bytes = fileData.buffer.asUint8List();
    final chunkSize = 512;
    List<Uint8List> chunks = [];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      chunks.add(Uint8List.fromList(bytes.sublist(i, end)));
    }
    return chunks;
  }
}
