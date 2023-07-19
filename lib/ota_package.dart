/*import 'dart:typed_data';
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


*/
///
/*
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ota_package/data/ble_repository.dart';
import 'package:file_picker/file_picker.dart';

abstract class OtaPackage {
  Future<void> updateFirmware(BluetoothDevice device, int firmwareType);
  

}

class Esp32OtaPackage extends OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;
   bool Firmwareupdate = false;


  Esp32OtaPackage(this.dataCharacteristic, this.controlCharacteristic);

  @override
Future<void> updateFirmware(BluetoothDevice device, int firmwareType) async {
  final bleRepo = BleRepository();

  try {
    // Connect to the ESP32 device
    await bleRepo.connectToDevice(device);

    // Write packet size data on the dataCharacteristic
    int mtuSize = await device.mtu.first;
    Uint8List byteList = Uint8List(2);
    byteList[0] = mtuSize & 0xFF;
    byteList[1] = (mtuSize >> 8) & 0xFF;
    await bleRepo.writeDataCharacteristic(dataCharacteristic, byteList);

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([1]));
    List<int> value = await bleRepo.readCharacteristic(controlCharacteristic);
    print('value returned is this ------- ${value[0]}');



// Func 
Future<List<Uint8List>> getFirmware(int firmwareType, int mtuSize) {
    if (firmwareType == 2) {
    // Prompt the user to select the firmware BIN file using file picker
    return _getFirmwareFromPicker(mtuSize);
  } else if (firmwareType == 1) {
    // Provide the absolute file path for the firmware BIN file
    String binFilePath = '/path/to/firmware.bin';
    return _readBinaryFile(binFilePath, mtuSize);
  } else {
    // If the firmwareType is neither 1 nor 2, return an empty list.
     return Future.value([]);
  }
  }

    // Check if controlCharacteristic reads 0x02
    if (value[0] == 2) {
      // Get the firmware chunks
      List<Uint8List> binaryChunks = await getFirmware(firmwareType, mtuSize);
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
      Firmwareupdate = true; // Firmware update was successful
    } else {
      print('OTA update failed');
      Firmwareupdate = false; // Firmware update failed
    }
  } catch (e) {
    print('Error during OTA update: $e');
    Firmwareupdate = false; // Return false on any error during the update process
  }
  
  

}


  
 

  Future<List<Uint8List>>_getFirmwareFromPicker(int mtuSize) async {
     // Prompt the user to select the firmware BIN file
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

  if (result != null && result.files.isNotEmpty) {
    PlatformFile file = result.files.first;
   String binFilePath = file.path ?? '';

    // Read and return firmware chunks from the selected BIN file
    return _readBinaryFile(binFilePath, mtuSize);
  } else {
    // Return an empty list if the user canceled the file picker
    return [];
  }
  }

 Future<List<Uint8List>> _readBinaryFile(String binFilePath, int mtuSize) async {
     final fileData = await rootBundle.load(binFilePath);
    final bytes = fileData.buffer.asUint8List();
    final chunkSize = mtuSize;
    List<Uint8List> chunks = [];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      chunks.add(Uint8List.fromList(bytes.sublist(i, end)));
    }
    return chunks;
  }

  
  
}
*/
//ota_package.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';


abstract class OtaPackage {
  
  Future<void> updateFirmware(BluetoothDevice device, int firmwareType,BluetoothService service, BluetoothCharacteristic dataUUID, BluetoothCharacteristic controlUUID,{String? binFilePath}); 
  bool Firmwareupdate = false;
  Stream<int> get percentageStream;
  
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
Future<void> updateFirmware(BluetoothDevice device, int firmwareType, BluetoothService service,BluetoothCharacteristic dataUUID, BluetoothCharacteristic controlUUID, {String? binFilePath}) async {
  final bleRepo = BleRepository();

  // Write packet size data on the dataCharacteristic
  int mtuSize = await device.mtu.first;
  Uint8List byteList = Uint8List(2);
  byteList[0] = mtuSize & 0xFF;
  byteList[1] = (mtuSize >> 8) & 0xFF;

  // Get the firmware chunks
  List<Uint8List> binaryChunks;
  if (firmwareType == 1 && binFilePath != null && binFilePath.isNotEmpty) {
    binaryChunks = await getFirmware(firmwareType, mtuSize, binFilePath: binFilePath);
  } else if (firmwareType == 2) {
    binaryChunks = await _getFirmwareFromPicker(mtuSize);
  } else {
    binaryChunks = [];
  }
  print("After selection of firmware type");
  

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(dataCharacteristic, byteList);
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([1]));
    print('Inside update firmware, after writing characteristic');

    List<int> value = await bleRepo.readCharacteristic(controlCharacteristic);
    print('Value returned is: ${value[0]}');

    print('This is the length of binary chunks: ${binaryChunks.length}');
    int packageNumber = 0;
    for (Uint8List chunk in binaryChunks) {
      await bleRepo.writeDataCharacteristic(dataCharacteristic, chunk);
      packageNumber++;

      double progress = (packageNumber / binaryChunks.length) * 100;
      int roundedProgress = progress.round(); // Rounded off progress value
      print('Writing package number $packageNumber of ${binaryChunks.length} to ESP32');
      print('Progress: $roundedProgress%');
      _percentageController.add(roundedProgress);

      // Print the stream value
  _percentageController.stream.listen((value) {
    print('Stream value in pkg: $value');
  });
   
    }

    // Write x04 to the controlCharacteristic to finish the update process
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([4]));

    // Check if controlCharacteristic reads 0x05, indicating OTA update finished
    value = await bleRepo.readCharacteristic(controlCharacteristic);
    if (value[0] == 5) {
      print('OTA update finished');
      Firmwareupdate = true; // Firmware update was successful
    } else {
      print('OTA update failed');
      Firmwareupdate = false; // Firmware update failed
    }
    
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
    // Prompt the user to select the firmware BIN file using file picker
    return _getFirmwareFromPicker(mtuSize);
  } else if (firmwareType == 1 && binFilePath != null && binFilePath.isNotEmpty) {
    return _readBinaryFile(binFilePath, mtuSize);
  } else {
    // If the firmwareType is neither 1 nor 2, or binFilePath is not provided, return an empty list.
    return Future.value([]);
  }
}

Future<List<Uint8List>> _getFirmwareFromPicker(int mtuSize) async {
  final result = await FilePicker.platform.pickFiles();

  if (result == null) {
    throw 'No file selected.';
  }

  final file = result.files.first;
  print(file.path);
  return _openFileAndGetFirmwareData(file, mtuSize);
}

Future<List<Uint8List>> _openFileAndGetFirmwareData(PlatformFile file, int mtuSize) async {
  final bytes = await File(file.path!).readAsBytes();
  List<Uint8List> firmwareData = [];

  for (int i = 0; i < bytes.length; i += mtuSize) {
    int end = i + mtuSize;
    if (end > bytes.length) {
      end = bytes.length;
    }
    firmwareData.add(bytes.sublist(i, end));
  }

  print('Imported');
  return firmwareData;
}






  


