# flutter_ota

### Ship firmware. Skip the cable.

Reliable Over-The-Air updates for ESP32-class devices , from a Flutter app,
over Bluetooth Low Energy.

**Current version:** `1.0.0` · **Publisher:** [sparkleo.io](https://pub.dev/publishers/sparkleo.io)

---

**flutter_ota** is a Flutter library for Over-The-Air (OTA) firmware updates on
ESP32-class Bluetooth Low Energy (BLE) devices. It targets Espressif SoCs and
compatible modules , including **ESP32**, **ESP32-S2/S3**, and **ESP32-C3** ,
that implement **ESP-IDF** or **Arduino** OTA firmware on the device side.

Use it when your mobile or desktop Flutter app needs to push a new firmware
image to a nearby ESP32 without a wired flash tool: the package loads the
binary, runs the protocol handshake, streams progress, and completes (or fails)
with typed errors your UI can handle cleanly.

- 📡 **Transport** — Bluetooth Low Energy (BLE)
- 🧩 **Protocols** — ESP-IDF and Arduino OTA handshakes
- 📦 **Firmware sources** — Bundled assets, local file picker, or remote URL
- 🔒 **Integrity** — Optional SHA-256 before transfer and after flash
- 📈 **Progress** — Live percentage stream with clear terminal states
- 📝 **Session logs** — Optional in-memory capture via `saveOtaLogs` for debug UIs
- 🛠️ **Roadmap** — Additional channels planned: **MQTT** and **Wi-Fi (HTTP/HTTPS)**

Support for **MQTT** and **Wi-Fi (HTTP/HTTPS)** delivery is planned for future
releases, extending the same OTA workflow beyond BLE.

---

**Features**

- Supports firmware updates from bundled assets, a file picker, and URLs.
- Implements a progress stream to track update progress.
- Compatible with both ESP-IDF and Arduino firmware.
- Handles communication with ESP32 devices using Bluetooth Low Energy (BLE).
- Typed errors (`OtaException` and friends) and early validation of empty
  firmware, so failures surface clearly instead of corrupting an update.
- Optional firmware integrity: SHA-256 before transfer and post-flash SHA-256
  , enable any combination your device supports (or none).
- Optional session log capture (`saveOtaLogs`) for in-app debug screens.
- Self-disposing: resources are released automatically when an update reaches a
  terminal state.

**Requirements**

- Flutter `>=3.32.0`
- Dart `>=3.8.0 <4.0.0`

**What's new in 1.0.0**

See [CHANGELOG.md](CHANGELOG.md) for the full release notes. Highlights:

- Typed OTA exceptions and early empty-firmware validation
- Optional SHA-256 integrity (`shaBeforeTransfer`, `shaAfterFlash`)
- Configurable `mtuSize` with protocol-aware limits
- Session log capture via `saveOtaLogs` (default on) for in-app debug UIs
- Automatic resource disposal when an update ends

Upgrading from `0.x`? Follow the breaking-API steps in
[MIGRATION.md](MIGRATION.md). Common questions: [FAQ.md](FAQ.md). Want to
contribute? See [CONTRIBUTING.md](CONTRIBUTING.md).

**Installation**

1. Add the following line to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ota: ^1.0.0
```

2. Run the following command to install the package:

```bash
flutter pub get
```

**Platform setup**

Because the package communicates over Bluetooth Low Energy, each platform needs
the appropriate permissions and a minimum OS version configured before an update
will run.

### iOS

- Set the iOS deployment target to **13.0** or higher (required by
  `flutter_blue_plus`). In `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

- Add the Bluetooth usage descriptions to `ios/Runner/Info.plist` so the system
  permission prompt has a reason to show the user:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to and update the firmware of nearby ESP32 devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to and update the firmware of nearby ESP32 devices.</string>
```

### Android

Add the BLE permissions to `android/app/src/main/AndroidManifest.xml`. The
`BLUETOOTH`/`BLUETOOTH_ADMIN` permissions cover Android 11 and below, while
`BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` cover Android 12 (API 31) and above:

```xml
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>

<!-- Android 11 (API 30) and below -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

<!-- Android 12 (API 31) and above -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>

<!-- Required when downloading firmware from a URL -->
<uses-permission android:name="android.permission.INTERNET"/>
```

Request the runtime permissions (Bluetooth and, on older Android versions,
location) before starting an update. See the example app for a complete
permission-handling flow.

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
BluetoothCharacteristic writeCharacteristic = ...;
BluetoothCharacteristic notifyCharacteristic = ...;

// Constructor order is (notifyCharacteristic, writeCharacteristic).
Esp32OtaPackage otaPackage = Esp32OtaPackage(notifyCharacteristic, writeCharacteristic);
```

4. Choose the firmware update type (`updateType`) and firmware type (`firmwareType`):

- `updateType` (`UpdateType` enum):
  - `UpdateType.espidf`: ESP-IDF/Espressif Firmware Update
    Indicates that the firmware update follows the ESP-IDF/Espressif framework. In this case, you'll typically perform OTA updates using binary files and utilize the NimBLE Bluetooth stack.

  - `UpdateType.arduino`: Arduino IDE-Based Firmware Update
    Suggests that the firmware update is based on the Arduino framework for ESP32. This could involve custom OTA update logic implemented on the ESP32 side, possibly using specific GATT services and characteristics for communication.
    By checking the updateType parameter, you can adapt your OTA update logic to the specific requirements of the firmware implementation. This ensures compatibility and seamless OTA updates for different types of ESP32 firmware.

- `firmwareType` (`FirmwareType` enum):
  - `FirmwareType.assets`: For binary firmware files stored in your Flutter project assets (path must end with `.bin` or `.img`).
  - `FirmwareType.filepicker`: To select a `.bin` or `.img` file from device storage.
  - `FirmwareType.url`: For downloading firmware from a URL (raw binary after download; see [URL firmware](#url-firmware) under Error handling).

5. Call `updateFirmware` with the parameters that apply to your chosen
   `firmwareType` (`uri` is required for every type except
   `FirmwareType.filepicker`):

```dart
// ESP-IDF , firmware from assets
await otaPackage.updateFirmware(
  device,
  UpdateType.espidf,
  FirmwareType.assets,
  uri: 'assets/firmware.bin',
  mtuSize: 500, // optional (default 500)
);

// Arduino , firmware from URL
await otaPackage.updateFirmware(
  device,
  UpdateType.arduino,
  FirmwareType.url,
  uri: 'https://example.com/firmware.ino.bin',
  mtuSize: 500, // optional (default 500)
);

// Arduino , firmware from file picker (no uri needed)
await otaPackage.updateFirmware(
  device,
  UpdateType.arduino,
  FirmwareType.filepicker,
);

// Optional integrity , enable only what your firmware supports:
await otaPackage.updateFirmware(
  device,
  UpdateType.arduino,
  FirmwareType.url,
  uri: 'https://example.com/firmware.bin',
  integrity: FirmwareIntegrityConfig(
    features: {
      IntegrityFeature.shaBeforeTransfer, // app vs server hash
      IntegrityFeature.shaAfterFlash,     // device verifies flash, then reboot
    },
    expectedSha256Hex: serverProvidedSha256Hex, // 64 hex chars
  ),
);
```

| Parameter     | Applies to                                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------------ |
| `uri`         | Required for every `FirmwareType` except `FirmwareType.filepicker`                                                 |
| `mtuSize`     | Both update types (default `500`); see [Chunk size and BLE MTU](#chunk-size-mtusize-and-ble-mtu-negotiation) below |
| `integrity`   | Optional; defaults to no integrity checks. See [Firmware integrity](#firmware-integrity-optional)                  |
| `saveOtaLogs` | Optional (default `true`); capture this run’s logs for an in-app logger. See [Session logs](#session-logs-saveotalogs) |

### Chunk size (`mtuSize`) and BLE MTU negotiation

`mtuSize` is the number of **firmware payload bytes** per BLE transfer unit. It is
**not** the same as the ATT MTU negotiated by
`BluetoothDevice.requestMtu()` , the package does **not** call `requestMtu()`
for you. Your app must negotiate BLE MTU before starting an update, and the
`mtuSize` you pass to `updateFirmware` must fit within what was actually
negotiated.

| Protocol    | How `mtuSize` is used                                                                                                                                                                                                            |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ESP-IDF** | Splits firmware into chunks at load time (assets, file picker, URL); sends the value to the device in the handshake MTU packet; each chunk written must be ≤ `mtuSize`.                                                          |
| **Arduino** | Loads the full binary for file picker (chunk size is not used at load time); splits each 16 KB segment into `0xFB` BLE packets of `mtuSize` bytes during transfer; sends the value to the device in the `0xFF` handshake packet. |

**Aligning `requestMtu()` with `mtuSize`:**

- **ESP-IDF:** each characteristic write is one firmware chunk, so `mtuSize`
  must fit the negotiated ATT MTU (hard cap 512).
- **Arduino:** each write is `mtuSize + 2` bytes on the wire (2-byte `0xFB`
  header), so ensure the wire size fits within the negotiated ATT MTU.

```dart
// Arduino example: request enough ATT MTU for payload + 2-byte header.
await device.requestMtu(512);

await otaPackage.updateFirmware(
  device,
  UpdateType.arduino,
  FirmwareType.filepicker,
  mtuSize: 510, // 510 + 2 = 512 on the wire
);
```

If `requestMtu()` and `mtuSize` are misaligned (for example, negotiating `500`
but passing `mtuSize: 509` for Arduino), up-front validation may still pass
while GATT writes fail at runtime.

`mtuSize` is validated before any data is sent and must be:

- **`UpdateType.espidf`:** between `1` and `512` (`maxMtuSize`).
- **`UpdateType.arduino`:** between `1` and `510` (`maxMtuSize - arduinoHeaderSize`).
  The Arduino protocol prepends a 2-byte header to every packet.

An out-of-range value throws an `OtaException` before any BLE writes begin.

### Session logs (`saveOtaLogs`)

By default, `updateFirmware` captures detailed OTA log lines in memory for the
current run (`saveOtaLogs: true`). Host apps can show them on a debug / logger
screen (the example app has a **View OTA Logs** button when this is enabled).

```dart
await otaPackage.updateFirmware(
  device,
  UpdateType.espidf,
  FirmwareType.filepicker,
  saveOtaLogs: true, // default — set false to skip capture
);

// After (or during) the update:
final List<String> lines = otaSessionLogs;
final String text = otaSessionLogText; // newline-joined
clearOtaSessionLogs();                 // wipe the buffer
```

| API                    | Meaning                                                          |
| ---------------------- | ---------------------------------------------------------------- |
| `saveOtaLogs`          | Named param on `updateFirmware` (default `true`)                 |
| `otaSessionLogs`       | Unmodifiable list of captured lines for the latest enabled run   |
| `otaSessionLogText`    | Same content as a single string                                  |
| `clearOtaSessionLogs`  | Clears the in-memory buffer                                      |
| `otaLogCaptureEnabled` | Whether capture is currently on                                  |
| `otaVerboseLogging`    | Extra packet/progress traces (default `false`; noisy, no firmware dumps) |

Capture starts (and the buffer is cleared) when a run begins with
`saveOtaLogs: true`. Firmware payloads and other oversized dumps are never
stored — only status / handshake / progress / error lines. Console
pretty-printing still follows normal development filters.

### Firmware integrity (optional)

Integrity is **off by default**. Turn features on only when you have an expected
SHA-256 for the image (and, for post-flash verify, device firmware that
understands the hash opcodes). Features are independent — enable one, both, or
neither.

| Feature             | What it does                                                                                            | Device support? |
| ------------------- | ------------------------------------------------------------------------------------------------------- | --------------- |
| `shaBeforeTransfer` | After the binary is loaded (asset / file / URL), Flutter hashes it and compares to your expected digest **before any BLE write**. Stops a wrong or corrupted download early. | No              |
| `shaAfterFlash`     | After the image is sent, the app sends the expected SHA-256 to the device; the device hashes what it flashed and ACKs success only if it matches. Catches transfer/flash corruption. | Yes             |

Provide the digest with `expectedSha256Hex` (64 hex characters) or
`expectedSha256Bytes` (32 bytes). Use the same value for both features when both
are enabled. Compute it once from the known-good `.bin` / `.img` (e.g. on your
server or with `shasum -a 256 firmware.bin`).

```dart
// Phone-only: reject a bad download before BLE starts
FirmwareIntegrityConfig(
  features: {IntegrityFeature.shaBeforeTransfer},
  expectedSha256Hex: '...', // 64 hex chars
)

// Device verifies flash (requires matching firmware support)
FirmwareIntegrityConfig(
  features: {IntegrityFeature.shaAfterFlash},
  expectedSha256Hex: '...',
)

// Both
FirmwareIntegrityConfig(
  features: {
    IntegrityFeature.shaBeforeTransfer,
    IntegrityFeature.shaAfterFlash,
  },
  expectedSha256Hex: '...',
)
```

Pass the config as `integrity:` on `updateFirmware`. Mismatches throw
`FirmwareHashMismatchException` (pre-transfer) or `DeviceHashMismatchException`
(post-flash) after emitting `failedValue` on the progress stream.

**Wire notes (when `shaAfterFlash` is on):** After the full image is written,
both protocols send the expected digest, then wait for device verify:
ESP-IDF — control `0x07` (`SET_HASH`) + 32-byte digest on data, read `0x02`
ACK, then `0x04` DONE (do not send `0x02` as SET_HASH; status `6` = mismatch).
Arduino — `0xF9` flags, then `0xFA` + 32-byte digest; mismatch `0x0E`, success
`0x0F`.

6. Listen to the `percentageStream` of the `otaPackage` to track the update progress:

```dart
StreamSubscription subscription = otaPackage.percentageStream.listen((progress) {
  print('OTA update progress: $progress%');
});

// ... (update your UI based on the progress)

await subscription.cancel();
```

7. Check the `firmwareUpdate` property of the `otaPackage` to determine if the update was successful:

```dart
if (otaPackage.firmwareUpdate) {
  print('OTA update successful');
} else {
  print('OTA update failed');
}
```

## Cancelling an update

Call `cancelUpdate()` to stop an in-progress OTA. When this happens, the package
emits `cancelledValue` (`-1`) on `percentageStream`. If the update instead fails
because of a BLE error (the device disconnects mid-transfer, a write fails with a
GATT 133 error, etc.), the package emits `failedValue` (`-2`) on
`percentageStream` rather than throwing, so the failure does not crash your app.

```dart
otaPackage.percentageStream.listen((progress) {
  if (progress == cancelledValue) {
    // Update was cancelled by the user.
  } else if (progress == failedValue) {
    // Update failed because of a BLE error.
  } else if (progress == 100) {
    // Device acknowledged a successful update.
  } else {
    // Transfer progress (0–99). 100 is reserved for post-ACK success.
  }
});
```

> **Important:** Cancelling only stops the app from sending data. It does **not**
> reset the OTA state machine on the ESP32, which is left mid-update. The caller
> **must disconnect and reconnect** (re-discovering services) before starting a
> new OTA on the same device. Starting another OTA on the same connection leaves
> the two sides out of sync and typically results in a BLE disconnect / GATT
> error. See the example app for how it disconnects after a cancel and prompts
> the user to reconnect.

## Error handling

The package distinguishes two kinds of failures:

- **BLE / transport errors during an in-progress update** (device disconnects, a
  write fails with a GATT error, etc.) are reported on `percentageStream` as
  `failedValue` (`-2`) rather than thrown, so a mid-transfer drop does not crash
  your app. Handle these via the stream as shown above.

- **Setup / integrity errors** (empty firmware, download failure, pre-transfer
  SHA mismatch, or device-reported post-flash SHA mismatch) are thrown as typed
  exceptions. These also emit `failedValue` first so UI listeners still update,
  then rethrow so you can branch on type. Wrap `updateFirmware` in a
  `try/catch`:

```dart
try {
  await otaPackage.updateFirmware(
    device,
    UpdateType.espidf,
    FirmwareType.url,
    uri: url,
    mtuSize: 500,
  );
} on EmptyFirmwareException catch (e) {
  // Firmware source was empty (no bytes to flash).
  print(e.message);
} on FirmwareHashMismatchException catch (e) {
  // Pre-transfer SHA-256 did not match the expected digest.
  print(e.message);
} on DeviceHashMismatchException catch (e) {
  // Device rejected the flash after post-flash SHA-256 verification.
  print(e.message);
} on FirmwareDownloadException catch (e) {
  // HTTP download failed, or the response was HTML instead of a binary.
  print('Download failed (${e.statusCode}): ${e.message}');
} on UnsupportedFirmwareImageException catch (e) {
  // Path/URL/file was not .bin or .img.
  print(e.message);
} on OtaException catch (e) {
  // Any other OTA error.
  print(e.message);
}
```

### URL firmware

`FirmwareType.url` downloads first, then validates the payload (rejects HTML;
checks `.bin` / `.img` when a filename is known via `Content-Disposition` or
the URL path). Pre-check without starting OTA:

```dart
await validateFirmwareSource(FirmwareType.url, uri: url);
```

Share/view pages (e.g. Google Drive `/file/d/.../view`) return HTML and fail
this check — use a direct-download or CDN URL. Details:
[FAQ.md](FAQ.md#why-does-the-sha-256-change-every-time-i-download-from-google-drive).

The exception types are:

| Exception                       | When it is thrown                                                                                      |
| ------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `OtaException`                  | Base class for all OTA errors thrown by the package.                                                   |
| `EmptyFirmwareException`        | The firmware source yields no data (empty asset/file, empty download, or no file selected).            |
| `FirmwareDownloadException`     | The HTTP download fails (non-200 status, timeout, network error, or HTML instead of a binary).         |
| `UnsupportedFirmwareImageException` | Path/URL/file is not `.bin` or `.img`.                                                              |
| `FirmwareIntegrityException`    | Base class for integrity verification failures.                                                        |
| `FirmwareHashMismatchException` | App-side SHA-256 mismatch (`shaBeforeTransfer`).                                                       |
| `DeviceHashMismatchException`   | Device reported post-flash SHA-256 mismatch (`shaAfterFlash`; Arduino `0x0E` / ESP-IDF status `6`).    |

## Releasing resources

The package disposes itself automatically once an update finishes, fails, or is
cancelled, so you normally do **not** need to do anything. To abandon an update
that has not finished (for example, on app shutdown), call `dispose()`:

```dart
await otaPackage.dispose();
```

## Example Application

The example application code is available in the example folder of this repository.

### ESP-IDF OTA Firmware

The article (https://michaelangerer.dev/esp32/ble/ota/2021/06/08/esp32-ota-part-2.html) provides insights into the core logic for executing an Over-The-Air (OTA) update using ESP-IDF framework. This firmware update method leverages the capabilities of ESP32 devices to wirelessly update their firmware via Bluetooth Low Energy (BLE).

### Arduino IDE OTA Firmware

The GitHub repository (https://github.com/fbiego/ESP32_BLE_OTA_Arduino) provides firmware suitable for integration utilizing the Arduino IDE framework.

## Contributors

We thank [fugidev](https://github.com/fugidev) for contributions to the `updateFirmware` API, including typed update and firmware options, a unified `uri` parameter, and MTU-aware packet transfer.

## Conclusion

The `flutter_ota` package provides a streamlined approach to performing OTA firmware updates for ESP32 devices using Flutter applications. It simplifies communication with ESP32 devices over Bluetooth Low Energy (BLE) and streamlines the OTA update process. This package offers several key features:

- Support for various firmware update scenarios (binary files, URLs)
- Progress tracking through a stream for updating UI elements
- Compatibility with different firmware types
- Asynchronous programming for efficient BLE communication

By integrating `flutter_ota` into your Flutter project, you can seamlessly deliver firmware updates to your ESP32 devices wirelessly, enhancing user experience and ensuring your devices stay up-to-date.
This comprehensive explanation effectively covers the `flutter_ota` package, its functionalities, and its usage within a Flutter application for OTA updates on ESP32 devices. It provides valuable insights for developers seeking to implement wireless firmware updates in their projects.
