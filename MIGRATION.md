# Migrating to flutter_ota 1.0.0

`1.0.0` is a **breaking** major release. The biggest call-site change is
replacing magic integers with `UpdateType` / `FirmwareType` enums. Several
other API cleanups landed in the same version — this guide covers all of them.

If you are already on `^1.0.0`, you can skip this file.

## Dependency bump

```yaml
dependencies:
  flutter_ota: ^1.0.0
```

Then:

```bash
flutter pub get
```

## Integer codes → enums

### Mapping

| Old (`int`) | New |
| --- | --- |
| `updateType: 1` | `UpdateType.espidf` |
| `updateType: 2` | `UpdateType.arduino` |
| `firmwareType: 1` | `FirmwareType.assets` |
| `firmwareType: 2` | `FirmwareType.filepicker` |
| `firmwareType: 3` | `FirmwareType.url` |

### Before (`≤ 0.1.x`)

```dart
await otaPackage.updateFirmware(
  device,
  1, // ESP-IDF
  3, // URL
  service,
  dataCharacteristic,
  controlCharacteristic,
  url: 'https://example.com/firmware.bin',
);
```

### After (`1.0.0`)

```dart
await otaPackage.updateFirmware(
  device,
  UpdateType.espidf,
  FirmwareType.url,
  uri: 'https://example.com/firmware.bin',
);
```

Constructor order is unchanged: `(notifyCharacteristic, writeCharacteristic)`.
Discover and pass those characteristics yourself; they are no longer duplicated
as `updateFirmware` arguments.

## Other breaking call-site changes

| Before | After |
| --- | --- |
| Positional `service`, `dataUUID`, `controlUUID` on `updateFirmware` | **Removed** — use the characteristics already passed to `Esp32OtaPackage(...)` |
| Named `binFilePath` / `url` | Single named `uri` (asset path or URL) |
| Errors thrown as raw `String`s | Typed `OtaException` hierarchy (`EmptyFirmwareException`, `FirmwareDownloadException`, …) |
| No `dispose()` | Prefer listening until a terminal progress value; call `dispose()` only to abandon an in-flight update |

`mtuSize` is now an optional named parameter (default `500`) and is validated
up front against the protocol limit (512 for ESP-IDF, 510 for Arduino).

### Error handling migration

```dart
// Before
try {
  await otaPackage.updateFirmware(/* … */);
} catch (e) {
  print(e); // often a String
}

// After
try {
  await otaPackage.updateFirmware(/* … */);
} on EmptyFirmwareException catch (e) {
  // empty asset / download / picker result
} on FirmwareDownloadException catch (e) {
  // HTTP failure — see e.statusCode
} on OtaException catch (e) {
  // invalid mtuSize, missing uri, concurrent update, …
}
```

Mid-transfer BLE failures still surface on `percentageStream` as `failedValue`
(`-2`), not as thrown exceptions.

## Optional: session log capture (`saveOtaLogs`)

Included in **1.0.0**, additive and **on by default** — no migration required.
Each `updateFirmware` call with `saveOtaLogs: true` clears and fills an
in-memory buffer you can show in a logger screen:

```dart
await otaPackage.updateFirmware(
  device,
  UpdateType.espidf,
  FirmwareType.filepicker,
  saveOtaLogs: true, // default; set false to disable
);

final logs = otaSessionLogText;
```

See [README § Session logs](README.md#session-logs-saveotalogs).

## Optional: firmware integrity

New in 1.0.0 and **off by default** — existing device firmware keeps working
without changes:

```dart
await otaPackage.updateFirmware(
  device,
  UpdateType.arduino,
  FirmwareType.url,
  uri: firmwareUrl,
  integrity: FirmwareIntegrityConfig(
    features: {
      IntegrityFeature.shaBeforeTransfer,
      IntegrityFeature.shaAfterFlash,
    },
    expectedSha256Hex: serverSha256Hex,
  ),
);
```

Enable only the features your ESP32 firmware implements. See the
[README](README.md#firmware-integrity-optional) and
[DOCUMENTATION.md](DOCUMENTATION.md) for details.

## Checklist

1. Replace `1` / `2` / `3` with `UpdateType` / `FirmwareType` values.
2. Drop `service` / characteristic arguments from `updateFirmware`.
3. Rename `binFilePath` / `url` → `uri`.
4. Catch `OtaException` (and subclasses) instead of assuming `String` errors.
5. Re-run your OTA flow on a device; confirm progress, cancel, and reconnect
   behavior still match your UX (cancel still requires disconnect/reconnect).

## Further reading

- [CHANGELOG.md](CHANGELOG.md) — full 1.0.0 notes
- [FAQ.md](FAQ.md) — common post-upgrade questions
- [DOCUMENTATION.md §4](DOCUMENTATION.md#4-protocol-handshake-sequences) —
  ESP-IDF / Arduino wire sequences
