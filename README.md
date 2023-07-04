# flutter_ota

The `flutter_ota` package provides a convenient and straightforward way to perform over-the-air (OTA) firmware updates for ESP32 devices via Bluetooth Low Energy (BLE). This package allows you to wirelessly update the firmware of ESP32 devices, eliminating the need for physical connections.

## Features

- Establish a Bluetooth Low Energy (BLE) connection with an ESP32 device.
- Request and set the Maximum Transmission Unit (MTU) size for optimized data transfer.
- Perform firmware updates by sending binary data to the ESP32 device in chunks.
- Monitor the OTA update process and receive progress updates.

## Getting Started

To use the `flutter_ota` package in your Flutter project, follow these steps:

1. Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ota: ^x.x.x # Replace 'x.x.x' with the latest version from pub.dev
```

2. Run `flutter pub get` to fetch the package.

3. Import the package in your Dart code:

```dart
import 'package:flutter_ota/flutter_ota.dart';
```

## Usage

### 1. Establish a Bluetooth Connection

The first step is to establish a Bluetooth Low Energy connection with the ESP32 device:

```dart
final FlutterOta flutterOta = FlutterOta();
final BluetoothDevice device = ...; // Get the BluetoothDevice instance of your ESP32

await flutterOta.connectToDevice(device);
```

### 2. Request and Set MTU Size

You can request and set the Maximum Transmission Unit (MTU) size for optimized data transfer:

```dart
final int mtuSize = 300; // Set the desired MTU size
await flutterOta.requestMtu(device, mtuSize);
```

### 3. Perform OTA Firmware Update

To perform the OTA firmware update, you need to send binary data in chunks to the ESP32 device:

```dart
// Read binary data from a file or source
final List<Uint8List> binaryChunks = ...; // Read binary data in chunks

for (int packageNumber = 0; packageNumber < binaryChunks.length; packageNumber++) {
  final Uint8List chunk = binaryChunks[packageNumber];

  // Send the chunk to the ESP32 device
  await flutterOta.sendFirmwareChunk(chunk);

  // Update the progress (optional)
  final double progress = (packageNumber + 1) / binaryChunks.length;
  print('OTA Update Progress: ${(progress * 100).toStringAsFixed(2)}%');
}
```

### 4. Monitor OTA Update Status

You can listen to the OTA update status to get notifications on completion:

```dart
flutterOta.onUpdateComplete.listen((success) {
  if (success) {
    print('OTA Update Completed Successfully!');
  } else {
    print('OTA Update Failed.');
  }
});
```

### 5. Disconnect from Device

After the OTA update is complete or in case of an error, make sure to disconnect from the ESP32 device:

```dart
await flutterOta.disconnectFromDevice();
```

## Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ota/flutter_ota.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTA Update Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final FlutterOta flutterOta = FlutterOta();
  final BluetoothDevice device = ...; // Replace with your ESP32 device

  @override
 

 Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OTA Update Demo'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              await flutterOta.connectToDevice(device);
              await flutterOta.requestMtu(device, 300);

              final List<Uint8List> binaryChunks = ...; // Replace with your binary data
              for (int packageNumber = 0; packageNumber < binaryChunks.length; packageNumber++) {
                final Uint8List chunk = binaryChunks[packageNumber];
                await flutterOta.sendFirmwareChunk(chunk);
                final double progress = (packageNumber + 1) / binaryChunks.length;
                print('OTA Update Progress: ${(progress * 100).toStringAsFixed(2)}%');
              }

              flutterOta.onUpdateComplete.listen((success) {
                if (success) {
                  print('OTA Update Completed Successfully!');
                } else {
                  print('OTA Update Failed.');
                }
              });

              await flutterOta.disconnectFromDevice();
            } catch (e) {
              print('Error during OTA update: $e');
            }
          },
          child: Text('Start OTA Update'),
        ),
      ),
    );
  }
}
```

## Notes

- Make sure your ESP32 device is compatible with OTA updates via Bluetooth Low Energy (BLE).
- Always handle errors and disconnections appropriately to provide a smooth user experience.

## Conclusion

The `flutter_ota` package simplifies the process of performing over-the-air (OTA) firmware updates for ESP32 devices using Bluetooth Low Energy (BLE). You can now wirelessly update the firmware of your ESP32 devices with ease. If you encounter any issues or have suggestions for improvement, feel free to report them on the [GitHub repository](https://github.com/example/flutter_ota). Happy updating!
