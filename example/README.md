# flutter_ota example

Sample Flutter app that demonstrates [flutter_ota](../README.md): scan for a
nearby ESP32 over BLE, connect, and flash firmware Over-The-Air.

## What it shows

- BLE scan and connect (via `flutter_blue_plus`)
- Runtime Bluetooth / location permission handling
- Reconnect to the last connected device
- OTA with `Esp32OtaPackage` (Arduino service UUIDs by default)
- Live progress via `percentageStream`, including cancel (`-1`) and BLE failure
  (`-2`) sentinels
- **Save OTA logs** (`saveOtaLogs` on `updateFirmware`, default on) and a
  **View OTA Logs** screen that displays `otaSessionLogs`
- Disconnect / reconnect guidance after cancel or device reboot

Firmware can be loaded from a URL, the file picker, or bundled assets, depending
on how you call `updateFirmware` in the OTA screen.

## Requirements

- Flutter `>=3.32.0`
- Dart `>=3.8.0 <4.0.0`
- A physical Android or iOS device (BLE is not available on most simulators)
- An ESP32 running firmware that exposes the OTA BLE service used by this app

Default Arduino OTA UUIDs (see `lib/features/scanningAndConnection/presentation/ota_ble_constants.dart`):

| Role | UUID |
| --- | --- |
| Service | `d6f1d96d-594c-4c53-b1c6-144a1dfde6d8` |
| Notify | `7ad671aa-21c0-46a4-b722-270e3ae3d830` |
| Write | `23408888-1f40-4cd8-9b89-ca8d45f8a5b0` |

Replace these if your firmware uses different UUIDs (for example ESP-IDF).

## Run

From the repository root:

```bash
cd example
flutter pub get
flutter run
```

Platform permissions and the iOS 13+ deployment target are already configured in
this example. For integrating `flutter_ota` into your own app, see the
[package README](../README.md) **Platform setup** section.

## Layout

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry, permission bootstrap |
| `lib/features/scanningAndConnection/` | Scan, connect, and OTA UI |
| `…/view/ota_logger_page.dart` | In-app viewer for `otaSessionLogs` |
| `lib/core/permissions/` | Bluetooth / location helpers |
| `lib/core/bluetooth/` | BLE adapter helpers |

Package usage details and API docs: [../DOCUMENTATION.md](../DOCUMENTATION.md).
