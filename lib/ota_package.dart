// ignore_for_file: annotate_overrides, avoid_print, prefer_const_constructors

// Import necessary libraries
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

// Abstract class defining the structure of an OTA package
abstract class OtaPackage {
  // Method to update firmware
  Future<void> updateFirmware(
    BluetoothDevice device,
    int firmwareType,
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID,
    {String? binFilePath, String? url}
  );
  
  // Property to track firmware update status
  bool firmwareupdate = false;

  // Stream to provide progress percentage
  Stream<int> get percentageStream;
}

// Class responsible for handling BLE repository operations
class BleRepository {
  // Write data to a Bluetooth characteristic
  Future<void> writeDataCharacteristic(BluetoothCharacteristic characteristic, Uint8List data) async {
    await characteristic.write(data);
  }

  // Read data from a Bluetooth characteristic
  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  // Request a specific MTU size from a Bluetooth device
  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }
}

// Implementation of OTA package for ESP32
class Esp32OtaPackage implements OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;
  bool firmwareupdate = false;
  final StreamController<int> _percentageController = StreamController<int>.broadcast();
  @override
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

    // Get MTU size from the device
    int mtuSize = await device.mtu.first;

    print("MTU size f current device $mtuSize");
    
    // Prepare a byte list to write MTU size to controlCharacteristic
    Uint8List byteList = Uint8List(2);
    byteList[0] = mtuSize & 0xFF;
    byteList[1] = (mtuSize >> 8) & 0xFF;

    List<Uint8List> binaryChunks;

    // Choose firmware source based on firmwareType
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

    // Read value from controlCharacteristic
    List<int> value = await bleRepo.readCharacteristic(controlCharacteristic).timeout(Duration(seconds: 10));
    print('value returned is this ------- ${value[0]}');
    
    int packageNumber = 0;
    for (Uint8List chunk in binaryChunks) {
      // Write firmware chunks to dataCharacteristic
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
      firmwareupdate = true; // Firmware update was successful
    } else {
      print('OTA update failed');
      firmwareupdate = false; // Firmware update failed
    }
  }

  // Convert Uint8List to List<int>
  List<int> uint8ListToIntList(Uint8List uint8List) {
    return uint8List.toList();
  }

  // Read binary file and split it into chunks
  Future<List<Uint8List>> _readBinaryFile(String filePath, int mtuSize) async {
    final ByteData data = await rootBundle.load(filePath);
    final List<int> bytes = data.buffer.asUint8List();
    final int chunkSize = mtuSize-3;
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

  // Get firmware based on firmwareType
  Future<List<Uint8List>> getFirmware(int firmwareType, int mtuSize, {String? binFilePath}) {
    if (firmwareType == 2) {
      print("in package mtu size is ${mtuSize}");
      return _getFirmwareFromPicker(mtuSize-3);
    } else if (firmwareType == 1 && binFilePath != null && binFilePath.isNotEmpty) {
      return _readBinaryFile(binFilePath, mtuSize);
    } else {
      return Future.value([]);
    }
  }

  // Get firmware chunks from file picker
  Future<List<Uint8List>> _getFirmwareFromPicker(int mtuSize) async {
    print("MtU size in fie pickeer is ${mtuSize}");
    mtuSize = mtuSize -3;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result == null || result.files.isEmpty) {
      return []; // Return an empty list when no file is picked
    }

    final file = result.files.first;

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

  // Open file, read bytes, and split into chunks
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
    return firmwareData;
  }

  // Fetch firmware chunks from a URL
  Future<List<Uint8List>> _getFirmwareFromUrl(String url, int mtuSize) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      // Check if the HTTP request was successful (status code 200)
      if (response.statusCode == 200) {
        final List<int> bytes = response.bodyBytes;
        final int chunkSize = mtuSize-3;
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
