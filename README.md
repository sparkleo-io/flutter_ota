**flutter_ota**

This package provides functionalities for Over-The-Air (OTA) updates for ESP32 devices using Flutter applications.

**Features**

* Supports firmware updates from binary files and URLs.
* Implements a progress stream to track update progress.
* Compatible with different firmware types.
* Handles communication with ESP32 devices using Bluetooth Low Energy (BLE).

**Installation**

1. Add the following line to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ota: ^0.1.15
```

2. Run the following command to install the package:

```bash
pub get
```

**Usage**

1. Import the necessary libraries:

```dart
import 'package:flutter_ota/flutter_ota.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
```

2. Connect to the ESP32 device using the `flutter_blue_plus` package.

3. Create an instance of the `Esp32OtaPackage` class, providing the required characteristics:

```dart
// Replace with the actual UUIDs of your ESP32 BLE service and characteristics
BluetoothService service = ...;
BluetoothCharacteristic dataCharacteristic = ...;
BluetoothCharacteristic notifyCharacteristic = ...;

Esp32OtaPackage otaPackage = Esp32OtaPackage(notifyCharacteristic, dataCharacteristic);
```

4. Choose the firmware update type (`updateType`) and firmware type (`firmwareType`):

* `updateType`:
    * Update Type 1: ESP-IDF/Espressif Firmware Update
      If updateType is set to 1, it indicates that the firmware update follows the ESP-IDF/Espressif framework. In this case, you'll typically perform OTA updates using binary files and utilize the NimBLE Bluetooth stack.

    * Update Type 2: Arduino IDE-Based Firmware Update
      If updateType is set to 2, it suggests that the firmware update is based on the Arduino framework for ESP32. This could involve custom OTA update logic implemented on the ESP32 side, possibly using specific GATT services and characteristics for communication.
      By checking the updateType parameter, you can adapt your OTA update logic to the specific requirements of the firmware implementation. This ensures compatibility and seamless OTA updates for different types of ESP32 firmware.
* `firmwareType`:
    * 1: For binary firmware files stored in your Flutter project assets.
    * 2: To select a binary firmware file from the device storage.
    * 3: For downloading firmware from a URL.

5. (Optional) Provide the path to the binary firmware file (`binFilePath`) if `firmwareType` is set to 1.

6. (Optional) Provide the URL of the firmware file if `firmwareType` is set to 3.

7. Call the `updateFirmware` method of the `otaPackage` instance:

```dart
await otaPackage.updateFirmware(
  device,
  updateType,
  firmwareType,
  service,
  dataCharacteristic,
  notifyCharacteristic,
  binFilePath: binFilePath,
  url: url,
);
```

8. Listen to the `percentageStream` of the `otaPackage` to track the update progress:

```dart
StreamSubscription subscription = otaPackage.percentageStream.listen((progress) {
  print('OTA update progress: $progress%');
});

// ... (update your UI based on the progress)

await subscription.cancel();
```

9. Check the `firmwareUpdate` property of the `otaPackage` to determine if the update was successful:

```dart
if (otaPackage.firmwareUpdate) {
  print('OTA update successful');
} else {
  print('OTA update failed');
}
```

## Example Application

The example application code is available in the example folder of this repository.

### ESP-IDF OTA Firmware

The article (https://michaelangerer.dev/esp32/ble/ota/2021/06/08/esp32-ota-part-2.html) provides insights into the core logic for executing an Over-The-Air (OTA) update using the `flutter_ota` package in conjunction with the ESP-IDF framework. This firmware update method leverages the capabilities of ESP32 devices to wirelessly update their firmware via Bluetooth Low Energy (BLE).

### Arduino IDE OTA Firmware

The GitHub repository (https://github.com/fbiego/ESP32_BLE_OTA_Arduino) hosts code segments suitable for integration into the `updateFirmware` method of the `Esp32OtaPackage` class or similar functions within Flutter applications utilizing the Arduino IDE. This firmware update approach is tailored for ESP32 devices running firmware developed with the Arduino framework.

## Conclusion

The `flutter_ota` package provides a streamlined approach to performing OTA firmware updates for ESP32 devices using Flutter applications. It simplifies communication with ESP32 devices over Bluetooth Low Energy (BLE) and streamlines the OTA update process. This package offers several key features:

* Support for various firmware update scenarios (binary files, URLs)
* Progress tracking through a stream for updating UI elements
* Compatibility with different firmware types
* Asynchronous programming for efficient BLE communication

By integrating `flutter_ota` into your Flutter project, you can seamlessly deliver firmware updates to your ESP32 devices wirelessly, enhancing user experience and ensuring your devices stay up-to-date.
This comprehensive explanation effectively covers the `flutter_ota` package, its functionalities, and its usage within a Flutter application for OTA updates on ESP32 devices. It provides valuable insights for developers seeking to implement wireless firmware updates in their projects. 
