# OTA Package for ESP32 Firmware Updates

The OTA Package is a Flutter library that provides functionality to update ESP32 firmware over-the-air (OTA) using Bluetooth Low Energy (BLE) communication. This package is particularly useful when you want to remotely update the firmware of an ESP32 device without requiring physical access to it.

## Installation

To use the OTA Package in your Flutter project, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_blue_plus: ^{latest_version}  # Replace {latest_version} with the latest version of the flutter_blue_plus package
```

Please note that the OTA Package relies on the `flutter_blue_plus` package for Bluetooth communication. Make sure to check for the latest version of `flutter_blue_plus` on [pub.dev](https://pub.dev/packages/flutter_blue_plus).

## Usage

To perform a firmware update on your ESP32 device using the OTA Package, follow these steps:

1. Import the required packages and classes:

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ota_package/data/ble_repository.dart';
import 'package:ota_package/ota_package.dart';
```

2. Create an instance of the `Esp32OtaPackage` class, providing the required `BluetoothCharacteristic` objects for data transfer and control:

```dart
BluetoothCharacteristic dataCharacteristic; // Replace with your actual data characteristic
BluetoothCharacteristic controlCharacteristic; // Replace with your actual control characteristic

Esp32OtaPackage otaPackage = Esp32OtaPackage(dataCharacteristic, controlCharacteristic);
```

3. Call the `updateFirmware` method with the path to your firmware BIN file and the `BluetoothDevice` object representing your ESP32 device:

```dart
final String binFilePath = "path/to/your/firmware.bin"; // Replace with the path to your firmware BIN file
BluetoothDevice device; // Replace with your actual BluetoothDevice instance

await otaPackage.updateFirmware(binFilePath, device);
```

**Note**: Before calling the `updateFirmware` method, make sure you have successfully connected to your ESP32 device using the `flutter_blue_plus` package.

## Example

Here's an example of how to perform a firmware update using the OTA Package:

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ota_package/data/ble_repository.dart';
import 'package:ota_package/ota_package.dart';

void main() async {
  final String deviceId = "ESP32_DEVICE_ID"; // Replace with your ESP32 device ID
  final String binFilePath = "path/to/your/firmware.bin"; // Replace with the path to your firmware BIN file

  // Create a BluetoothDevice object from the deviceId
  BluetoothDevice device = await FlutterBlue.instance
      .scan(timeout: Duration(seconds: 4), scanMode: ScanMode.balanced)
      .where((scanResult) => scanResult.device.id.id == deviceId)
      .map((scanResult) => scanResult.device)
      .first;

  // Get the dataCharacteristic and controlCharacteristic from the BluetoothDevice
  BluetoothService service = await device.discoverServices()
      .then((services) => services.firstWhere((service) => service.uuid.toString() == "SERVICE_UUID"));
  BluetoothCharacteristic dataCharacteristic = service.characteristics.firstWhere((characteristic) => characteristic.uuid.toString() == "DATA_CHARACTERISTIC_UUID");
  BluetoothCharacteristic controlCharacteristic = service.characteristics.firstWhere((characteristic) => characteristic.uuid.toString() == "CONTROL_CHARACTERISTIC_UUID");

  // Create an object of Esp32OtaPackage and call the update

Firmware method
  Esp32OtaPackage otaPackage = Esp32OtaPackage(dataCharacteristic, controlCharacteristic);
  await otaPackage.updateFirmware(binFilePath, device);
}
```

Make sure to replace `"ESP32_DEVICE_ID"`, `"path/to/your/firmware.bin"`, `"SERVICE_UUID"`, and `"CONTROL_CHARACTERISTIC_UUID"` with the actual values for your ESP32 device and characteristics UUIDs.

## Contribution

Contributions to this project are welcome! If you find any issues or have suggestions for improvements, feel free to open an issue or submit a pull request.

## License

The OTA Package is released under the [MIT License](LICENSE). Feel free to use it in your own projects.
