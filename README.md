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
  flutter_ota: ^1.0.0
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
    * 1: For traditional OTA updates using a binary file or URL.
    * 2: For custom OTA updates implemented on the ESP32 side.
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

**Important Notes**

* Ensure the ESP32 device is configured for OTA updates with compatible firmware.
* The `updateType` and `firmwareType` values should match the implementation on the ESP32 side.
* Adjust the UUIDs of the BLE service and characteristics according to your ESP32 firmware.

## Example

The following code demonstrates how to initiate an OTA update using the `flutter_ota` package:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_new_protocol/features/new_ota_functionality/new_ota_protocol_impl.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/controller/scanning_connection_controller.dart';
import 'package:get/get.dart';
import '../../../../common/custom_button/feedback_enabled_button.dart';
import '../../../../common/toast/show_toast.dart';
import '../../../../utils/colors.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
class NewOTAUpdatePage extends StatefulWidget {
  const NewOTAUpdatePage({Key? key}) : super(key: key);


  @override
  State<NewOTAUpdatePage> createState() => _NewOTAUpdatePageState();
}

class _NewOTAUpdatePageState extends State<NewOTAUpdatePage> {

  HomePageController homePageController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("OTA Update"),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Connected Device Name: ${homePageController.gBleDevice!.platformName}"),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Connected Device Mac: ${homePageController.gBleDevice!.remoteId}"),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: FeedbackEnabledButton(
                  scaleFactor: 1.0,
                  translationFactorX: 0.0,
                  childWidget: Container(
                    //height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      border: Border.all(
                        color: Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          secondaryColor,
                          secondaryColor,
                        ],
                      ),
                    ),
                    //margin: const EdgeInsets.only(top: 10.0),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Start OTA",
                            style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onTap: () async {
                    print("OTA Update tapped");
                    // Call the OTA update logic here
                    BluetoothDevice? device = homePageController.gBleDevice;
                    List<BluetoothService> services = homePageController.gBleServices;

                    if (device == null || services.isEmpty) {
                      showToast("Connect to device first");
                      print("Device or services not available for OTA update");
                      return;
                    }

                    bool characteristicsFound = false;

                    for (BluetoothService service in services) {
                      print("In services loop and services lenght is ${services.length}");
                      if (service.uuid.toString() ==//'d6f1d96d-594c-4c53-b1c6-144a1dfde6d8') {
                          'fb1e4001-54ae-4a28-9f74-dfccb248601d') { //arduino uuid
                        print("service found");
                        final characteristics = service.characteristics;
                        BluetoothCharacteristic? notifyUuid;
                        BluetoothCharacteristic? writeUuid;

                        for (BluetoothCharacteristic c in characteristics) {
                          if (c.uuid.toString() ==  //'7ad671aa-21c0-46a4-b722-270e3ae3d830') {
                              'fb1e4003-54ae-4a28-9f74-dfccb248601d') { // arduino
                            notifyUuid = c;
                          }
                          if (c.uuid.toString() == //'23408888-1f40-4cd8-9b89-ca8d45f8a5b0') {
                              'fb1e4002-54ae-4a28-9f74-dfccb248601d') {//arduino
                            writeUuid = c;
                          }
                        }

                        if (notifyUuid != null && writeUuid != null) {
                          if (Platform.isAndroid) {
                            print("Plateform is andriod");
                            // Request a new MTU size for Android
                            const newMtu = 500;
                            await device.requestMtu(newMtu);

                            // The MTU request was successful, print the new MTU size
                            print('New MTU size (Android): $newMtu');
                          } else if (Platform.isIOS) {
                            // Use fixed MTU size of 185 for iOS
                            const newMtu = 185;
                            print('New MTU size (iOS): $newMtu');
                          }

                          Esp32OtaPackage esp32otaPackage =
                          Esp32OtaPackage(notifyUuid, writeUuid);

                          print("After package data set");

                          // Show the progress dialog
                          // ignore_for_file: use_build_context_synchronously
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => AlertDialog(
                              title: const Text('OTA Update in Progress'),
                              content: StreamBuilder<int>(
                                stream: esp32otaPackage!.percentageStream,
                                initialData: 0,
                                builder: (BuildContext context,
                                    AsyncSnapshot<int> snapshot) {
                                  double progress =
                                      snapshot.data! / 100.toDouble();
                                  if (progress >= 1.0 && homePageController.showProgressDialog) {
                                    // Dismiss the progress dialog when the OTA update is complete
                                    WidgetsBinding.instance
                                        ?.addPostFrameCallback((_) {
                                      homePageController.showProgressDialog =
                                      false; // Set showProgressDialog to false here
                                      Navigator.pop(context);
                                      // Show a snackbar to indicate OTA update completion
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('OTA Update Complete'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    });
                                  }
                                  return LinearProgressIndicator(
                                    value: progress,
                                    valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.blue),
                                    backgroundColor: Colors.grey[300],
                                  );
                                },
                              ),
                            ),
                          );

                          // Perform the OTA update with the picked binfile
                          await esp32otaPackage!.updateFirmware(
                            device,
                            2,//Update Type
                            2,
                            service,
                            notifyUuid,
                            writeUuid,
                            binFilePath: "assets/helllo.ino.bin",
                          );
                          /*if (binfile != null) {
                              await esp32otaPackage.updateFirmware(
                                device,
                                1,
                                service,
                                dataUuid,
                                controlUuid,
                                binFilePath: "assets/helllo.ino.bin",
                              );
                            }*/

                          // Initialize BleUartController before sending a command
                          // bleUartController.init();

                          characteristicsFound =
                          true; // Set the flag to true since characteristics were found
                          break; // Exit the loop since characteristics were found
                        }
                      }
                    }

                    if (!characteristicsFound) {

                      // Display a dialog indicating that the device isn't compatible for the firmware update
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Device Not Compatible'),
                          content: const Text(
                            'The device does not have the required characteristics for OTA firmware update.',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }

                  },
                ),
              ),
            ),
          ],
        )
    );
  }
}
```

## Purpose

The `flutter_ota` simplifies the OTA firmware update process for ESP32 devices through Bluetooth Low Energy. It allows developers to wirelessly update the firmware and provides a user-friendly experience. This package lets you easily keep your ESP32 devices up-to-date with the latest firmware.

## Ota firmware [ https://michaelangerer.dev/esp32/ble/ota/2021/06/08/esp32-ota-part-2.html ]

**Main Features of ESP32 OTA Firmware with OTA Package**

1. **Over-the-Air (OTA) Update Capability:** The firmware for ESP32 devices is designed to support Over-the-Air updates via Bluetooth

Low Energy (BLE). This allows developers to wirelessly update the firmware of ESP32 devices without the need for physical connections.

2. **NimBLE Bluetooth Stack:** The OTA firmware implementation uses the `NimBLE Bluetooth` stack provided by the ESP-IDF. NimBLE is known for using less flash space and RAM compared to the Bluedroid stack, making it suitable for projects focused on BLE.

3. **Partition Table Setup:** The ESP32's flash storage is divided into multiple partitions, including factory, `ota_0, and ota_1`. When updating the firmware, the new firmware is written to either ota_0 or ota_1 while the factory partition remains unchanged. This allows easy rollback to previous versions if needed.

4. **GATT Services and Characteristics:** The OTA firmware implements two services: Device Information Service (mandatory) and OTA Service. The OTA Service has two characteristics - OTA Control and OTA Data. The OTA Control characteristic is used to initiate and control the OTA update process, while the OTA Data characteristic is used to transfer the firmware from the app to the ESP32.

5. **Asynchronous Programming:** The Flutter package uses asynchronous programming with asyncio to handle BLE communication and notifications efficiently.

6. **OTA Process Sequencing:** The OTA process follows a specific sequence - the app requests OTA, the ESP32 acknowledges the request, the app sends firmware packets to the ESP32, and finally, the ESP32 acknowledges the completion of OTA.

7. **OTA Verification:** After receiving the firmware packets, the ESP32 verifies the integrity of the new firmware before selecting the updated partition for the next boot.

8. **OTA Rollback:** In case of any errors during the OTA update or firmware verification, the ESP32 can roll back to the previous version or the factory partition, ensuring a safe update process.

9. **User-friendly Logging:** The firmware code includes logging statements to provide detailed information about the OTA process, including acknowledgment status and packet transmission status.

10. **Automatic Reboot:** After successfully updating the firmware, the ESP32 automatically reboots to apply the new firmware.

11. **OTA Control Characteristic:**

    a. **Request OTA Update (Write Operation):** When the app wants to initiate an OTA update, it writes a specific value to the OTA Control characteristic. This value serves as a request from the app to start the update process on the ESP32.

    b. **OTA Request Acknowledgment (Notification):** After receiving the OTA update request from the package, the ESP32 acknowledges the request by sending a notification back to the package. This notification indicates that the OTA update process has been acknowledged and is ready to proceed.

    c. **OTA Done Acknowledgment (Notification):** Once the ESP32 has successfully received all the firmware packets from the app and completed the OTA update process, it sends another notification to the package. This notification indicates that the OTA update process has been completed successfully.

    d. **OTA Request Not Acknowledged (Notification):** If, for some reason, the ESP32 cannot proceed with the OTA update, it sends a notification to the package indicating that the OTA request has not been acknowledged. This could happen, for example, if there is an issue with the received firmware or the update process fails the verification.

    e. **OTA Done Not Acknowledged (Notification):** If the ESP32 encounters an error during the verification process after receiving all the firmware packets, it sends a notification to the package indicating that the OTA process has been completed but not acknowledged due to verification failure.

12. **OTA Data Characteristic:**

    a. **Firmware Packets (Write Operation):** The package splits the firmware binary into smaller packets, each of which fits within the MTU (Maximum Transmission Unit) size negotiated during the BLE connection process. It then writes these packets to the OTA Data characteristic on the ESP32. These packets are used to transfer the firmware from the app to the ESP32 for the OTA update.

In summary, the values exchanged between the firmware running on the ESP32 and the app during the OTA update process are:

From App to ESP32:

a. OTA Control Characteristic:

Request OTA Update

From ESP32 to App:

a. OTA Control Characteristic:

- **Request OTA Update (Write Operation):** Value: `1` or `0x01`
- **OTA Request Acknowledgment (Notification):** Value: `2` or `0x02`
- **OTA Done Acknowledgment (Notification):** Value: `3` or `0x03`
- **OTA Request Not Acknowledged (Notification):** Value: `4` or `0x04`
- **OTA Done Not Acknowledged (Notification):** Value: `5` or `0x05`

Both Ways (during firmware transfer):

b. OTA Data Characteristic:

Firmware Packets

By using these specific values, the ESP32 and the app can effectively communicate and coordinate the OTA update process over BLE. This ensures a controlled and reliable update mechanism, allowing the ESP32 to seamlessly receive and apply new firmware wirelessly.


## Ota Firmware [https://github.com/fbiego/ESP32_BLE_OTA_Arduino]

This code segment outlines the core logic for performing an OTA update using the `flutter_ota` package. It can be integrated into the `updateFirmware` method of the `Esp32OtaPackage` class or a similar function within your Flutter application. Here's a detailed breakdown:

1. **Retrieving MTU Size:**
    - `int mtuSize = await device.mtu.first;`
    - Fetches the Maximum Transmission Unit (MTU) supported by the connected ESP32 device. This value determines the maximum data size that can be sent in a single packet for efficient communication.

2. **Preparing Firmware Data (Based on `firmwareType`):**
    - The code checks the `firmwareType` to determine how the firmware data is obtained:
        - **`firmwareType == 1` (Binary File from Assets):**
            - Loads the binary file from the specified `binFilePath` using `rootBundle.load` and converts it into a `Uint8List` (list of unsigned 8-bit integers). This list represents the firmware data to be sent to the ESP32.
        - **`firmwareType == 2` (File Picker):**
            - Calls the `_getFirmwareFromPicker_arduino` function (not shown in the provided code) to prompt the user to select a binary file from the device storage. The selected file is converted into a `Uint8List` for processing.
        - **`firmwareType == 3` (URL):**
            - Calls the `_getFirmwareFromUrl` function (not shown) to download the firmware from the provided URL. This function likely parses the downloaded data into a list of `Uint8List` chunks, ensuring efficient transfer over BLE.
    - In all cases, the resulting `binFile` variable holds the firmware data to be transmitted.

3. **Calculating File Information:**
    - **`int fileLen = binFile!.length;`**
    - Determines the total length of the firmware data (binary file) in bytes.
    - **`int fileParts = (fileLen / part).ceil();`**
    - Calculates the number of data packets (parts) required to transmit the entire firmware file. This is based on the MTU size (`part`) and the total file length.

4. **Starting Notification Stream (Listening for Updates):**
    - **`await notifyCharacteristic.setNotifyValue(true);`**
    - Enables notifications on the `notifyCharacteristic`. This characteristic will be used by the ESP32 to send progress updates and status information back to the Flutter app.
    - **`subscription = notifyCharacteristic.onValueReceived.listen((value) async {...});`**
    - Creates a subscription to the `onValueReceived` stream of the `notifyCharacteristic`. This stream receives data from the ESP32 whenever it sends notifications. The code within the `listen` callback processes these notifications:
        - **`print("received value is $value");`** - Logs the received notification data for debugging purposes.
        - **`double progress = (value[2] / fileParts) * 100;`** - Calculates the current progress percentage based on the received acknowledgment byte (`value[2]`). This byte typically indicates the received part number of the firmware data.
        - **`print('Writing part number ${value[2]} of $fileParts to ESP32');`** - Logs the part number being written to the ESP32.
        - **`print('Progress: $roundedProgress%');`** - Logs the calculated progress percentage.
        - **`_percentageController.add(roundedProgress);`** - Updates a progress controller (likely a StreamController) with the progress value. This can be used to update a progress bar or UI element in your Flutter app.
        - **`if (value[0] == 0xF1) { ... }`** - Checks if the first byte of the notification is `0xF1`. This might indicate a request from the ESP32 to send the next part of the firmware data:
            - **`Uint8List bytes = Uint8List.fromList([value[1], value[2]]);`** - Creates a `Uint8List` from the received acknowledgment byte(s).
            - **`ByteData byteData = ByteData.sublistView(bytes);`** - Wraps the `Uint8List` in a `ByteData` object for easier data manipulation.
            - **`int nxt = byteData.getUint16(0);`** - Extracts the next expected part number from the `ByteData Give a proper ending to this readme file
              The flutter_ota package provides a streamlined approach to performing OTA firmware updates for ESP32 devices using Flutter applications. It simplifies communication with ESP32 devices over Bluetooth Low Energy (BLE) and streamlines the OTA update process. This package offers several key features:

## Conclusion

The `flutter_ota` package provides a streamlined approach to performing OTA firmware updates for ESP32 devices using Flutter applications. It simplifies communication with ESP32 devices over Bluetooth Low Energy (BLE) and streamlines the OTA update process. This package offers several key features:

* Support for various firmware update scenarios (binary files, URLs)
* Progress tracking through a stream for updating UI elements
* Compatibility with different firmware types
* Asynchronous programming for efficient BLE communication

By integrating `flutter_ota` into your Flutter project, you can seamlessly deliver firmware updates to your ESP32 devices wirelessly, enhancing user experience and ensuring your devices stay up-to-date.

## Additional Notes

* Refer to the official documentation of the `flutter_ota` package for detailed installation and usage instructions.
* Explore the provided code example to understand how to integrate the package into your Flutter application.
* Ensure compatibility between the `flutter_ota` package version and the BLE library you're using (`flutter_blue_plus` in this case).
* For more advanced OTA update functionalities, consider exploring custom implementations on both the ESP32 side and the Flutter app.

This comprehensive explanation effectively covers the `flutter_ota` package, its functionalities, and its usage within a Flutter application for OTA updates on ESP32 devices. It provides valuable insights for developers seeking to implement wireless firmware updates in their projects.