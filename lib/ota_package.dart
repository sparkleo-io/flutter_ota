

//ota_package.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

abstract class OtaPackage {
  Future<void> updateFirmware(
    BluetoothDevice device,
    int firmwareType,
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID,
    {String? binFilePath, String? url}

  );
  bool Firmwareupdate = false;
  Stream<int> get percentageStream;
  Future<List<Uint8List>> _getFirmwareFromPicker(int mtuSize);
 
}

class BleRepository {
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  Future<void> writeDataCharacteristic(BluetoothCharacteristic characteristic, Uint8List data) async {
    await characteristic.write(data);
  }

  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }
}

class Esp32OtaPackage implements OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;
  bool Firmwareupdate = false;
  StreamController<int> _percentageController = StreamController<int>.broadcast();
  Stream<int> get percentageStream => _percentageController.stream;

  Esp32OtaPackage(this.dataCharacteristic, this.controlCharacteristic);

  @override
  Future<void> updateFirmware(
    BluetoothDevice device,
    int firmwareType,
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID,
    {String? binFilePath, String? url}
  ) async {
    final bleRepo = BleRepository();

    int mtuSize = await device.mtu.first;
    Uint8List byteList = Uint8List(2);
    byteList[0] = mtuSize & 0xFF;
    byteList[1] = (mtuSize >> 8) & 0xFF;

    List<Uint8List> binaryChunks;
    if (firmwareType == 1 && binFilePath != null && binFilePath.isNotEmpty) {
      binaryChunks = await getFirmware(firmwareType, mtuSize, binFilePath: binFilePath);
    } else if (firmwareType == 2) {
      binaryChunks = await _getFirmwareFromPicker(mtuSize);
    } else if (firmwareType == 3 && url != null && url.isNotEmpty) {
      binaryChunks = await _getFirmwareFromUrl(url, mtuSize);
    } else {
      binaryChunks = [];
    }

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(dataCharacteristic, byteList);
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([1]));

    List<int> value = await bleRepo.readCharacteristic(controlCharacteristic).timeout(Duration(seconds: 10));
    print('value returned is this ------- ${value[0]}');
    int packageNumber = 0;
    for (Uint8List chunk in binaryChunks) {
      await bleRepo.writeDataCharacteristic(dataCharacteristic, chunk);
      packageNumber++;

      double progress = (packageNumber / binaryChunks.length) * 100;
      int roundedProgress = progress.round(); // Rounded off progress value
      print('Writing package number $packageNumber of ${binaryChunks.length} to ESP32');
      print('Progress: $roundedProgress%');
      _percentageController.add(roundedProgress);
    }

    // Write x04 to the controlCharacteristic to finish the update process
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([4]));

    // Check if controlCharacteristic reads 0x05, indicating OTA update finished
    value = await bleRepo.readCharacteristic(controlCharacteristic).timeout(Duration(seconds: 600));
    print('value returned is this ------- ${value[0]}');
    if (value[0] == 5) {
      print('OTA update finished');
      Firmwareupdate = true; // Firmware update was successful
    } else {
      print('OTA update failed');
      Firmwareupdate = false; // Firmware update failed
    }
  }

  List<int> uint8ListToIntList(Uint8List uint8List) {
    return uint8List.toList();
  }

  Future<List<Uint8List>> _readBinaryFile(String filePath, int mtuSize) async {
    final ByteData data = await rootBundle.load(filePath);
    final List<int> bytes = data.buffer.asUint8List();
    final int chunkSize = mtuSize;
    List<Uint8List> chunks = [];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = i + chunkSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
      chunks.add(chunk);
    }
    return chunks;
  }

  Future<List<Uint8List>> getFirmware(int firmwareType, int mtuSize, {String? binFilePath}) {
    if (firmwareType == 2) {
      return _getFirmwareFromPicker(mtuSize);
    } else if (firmwareType == 1 && binFilePath != null && binFilePath.isNotEmpty) {
      return _readBinaryFile(binFilePath, mtuSize);
    } else {
      return Future.value([]);
    }
  }
   @override
    Future<List<Uint8List>> _getFirmwareFromPicker(int mtuSize) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result == null || result.files.isEmpty) {
      return []; // Return an empty list when no file is picked
    }

    final file = result.files.first;
    print(file.path);
    try {
      final firmwareData = await _openFileAndGetFirmwareData(file, mtuSize);

      if (firmwareData.isEmpty) {
        throw 'Empty firmware data. Please select a valid firmware file.';
      }

      return firmwareData;
    } catch (e) {
      throw 'Error getting firmware data: $e';
    }
  }

  Future<List<Uint8List>> _openFileAndGetFirmwareData(PlatformFile file, int mtuSize) async {
    final bytes = await File(file.path!).readAsBytes();
    List<Uint8List> firmwareData = [];

    for (int i = 0; i < bytes.length; i += mtuSize) {
      int end = i + mtuSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      firmwareData.add(Uint8List.fromList(bytes.sublist(i, end)));
    }

    print('Imported');
    return firmwareData;
  }
  
  Future<List<Uint8List>> _getFirmwareFromUrl(String url, int mtuSize) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(Duration(seconds:10 ));

    // Check if the HTTP request was successful (status code 200)
    if (response.statusCode == 200) {
      final List<int> bytes = response.bodyBytes;
      final int chunkSize = mtuSize;
      List<Uint8List> chunks = [];
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = i + chunkSize;
        if (end > bytes.length) {
          end = bytes.length;
        }
        Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
        chunks.add(chunk);
      }
      return chunks;
    } else {
      // Handle HTTP error (e.g., status code is not 200)
      throw 'HTTP Error: ${response.statusCode} - ${response.reasonPhrase}';
    }
  } catch (e) {
    // Handle other errors (e.g., timeout, network connectivity issues)
    throw 'Error fetching firmware from URL: $e';
  }
}

}




  


