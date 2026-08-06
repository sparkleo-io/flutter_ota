# flutter_ota FAQ

Short answers to questions that come up when integrating or upgrading the
package. For a full walkthrough see [DOCUMENTATION.md](DOCUMENTATION.md); for
the `0.x` → `1.0.0` API break see [MIGRATION.md](MIGRATION.md).

## Which `UpdateType` should I use?

| Firmware on the ESP32               | Use                  |
| ----------------------------------- | -------------------- |
| ESP-IDF / Espressif NimBLE OTA      | `UpdateType.espidf`  |
| Arduino BLE OTA (e.g. fbiego-style) | `UpdateType.arduino` |

The enums only select the **phone-side** protocol. Your device must expose the
matching GATT service and speak the matching opcodes. Sequence diagrams:
[DOCUMENTATION.md §4](DOCUMENTATION.md#4-protocol-handshake-sequences).

## Why did my call break after upgrading to 1.0.0?

`updateFirmware` no longer takes integer codes or the extra
`service` / characteristic positional arguments. Map `1`/`2`/`3` to
`UpdateType` / `FirmwareType` and pass a single `uri` where needed — see
[MIGRATION.md](MIGRATION.md).

## Do I need firmware integrity?

No. `FirmwareIntegrityConfig` defaults to none; the wire format is unchanged.
Turn on `shaBeforeTransfer` / `shaAfterFlash` only if your device firmware
implements those features.

## Why does the SHA-256 change every time I download from Google Drive?

You used a **shareable / view** link. That opens Drive’s HTML viewer in a browser;
`FirmwareType.url` downloads that same HTML (often with a new nonce each time),
not the `.bin`. The package then SHA-256s the HTML, so the digest looks random
and pre-transfer integrity fails.

### How to make a usable firmware URL

1. Upload the firmware `.bin` / `.img` to Google Drive (or preferably your CDN).
2. Open **Share** → “Anyone with the link”, copy the share URL, extract `FILE_ID`.
3. Prefer a **direct download** URL:

   ```text
   https://drive.google.com/uc?export=download&id=FILE_ID
   ```

   URL validation/load **downloads first**, then checks:
   - the body is not HTML
   - if a filename is present (`Content-Disposition` or a `.bin`/`.img` path),
     it must use a supported extension

4. Best option: host at `https://your.cdn/firmware/app.bin` (clear path + raw bytes).

5. Compute SHA-256 of the binary once and pass it as `expectedSha256Hex` if you
   enable integrity.

**Do not** paste the `/file/d/.../view` share page into `uri` — that returns HTML
and fails post-download validation.

### Pre-check before OTA

```dart
// URL: downloads, then validates payload (not just the URL string)
final bool ok = await validateFirmwareSource(
  FirmwareType.url,
  uri: downloadUrl,
);
// assets / filepicker still check the .bin/.img name/path
```

## How do I capture OTA logs for a debug / logger screen?

Pass `saveOtaLogs: true` to `updateFirmware` (this is the **default**). The
package stores plain log lines for that run in memory. Read them with
`otaSessionLogs` or `otaSessionLogText`, and clear with `clearOtaSessionLogs()`.

```dart
await otaPackage.updateFirmware(
  device,
  UpdateType.arduino,
  FirmwareType.filepicker,
  saveOtaLogs: true, // omit to use the default
);

// Show in your own logger UI, or copy/share:
final String dump = otaSessionLogText;
```

Set `saveOtaLogs: false` if you do not want capture for a run. For noisier
packet/progress traces (still no firmware binaries), also set
`otaVerboseLogging = true` (off by default).
The example app wires this to a **Save OTA logs** switch and a **View OTA Logs**
screen — see [example/README.md](example/README.md) and
[README § Session logs](README.md#session-logs-saveotalogs).

## `mtuSize` vs `requestMtu()` — what's the difference?

- `BluetoothDevice.requestMtu()` negotiates the BLE ATT MTU (your app must call
  this; the package does not).
- `mtuSize` is how many **firmware payload bytes** the package puts in each
  write (default `500`).

For Arduino, each write is `mtuSize + 2` bytes on the wire (header). Keep
`mtuSize` within what the negotiated ATT MTU allows, and within protocol caps
(512 ESP-IDF / 510 Arduino).

## Progress stuck after cancel — can I start again immediately?

No. `cancelUpdate()` only stops the app from sending. The ESP32 OTA state
machine is usually left mid-update. **Disconnect, reconnect, and rediscover
services** before starting another OTA on that device.

## Progress shows `-1` or `-2` — is that an error code?

They are intentional stream sentinels:

| Value | Constant         | Meaning                                              |
| ----- | ---------------- | ---------------------------------------------------- |
| `-1`  | `cancelledValue` | Caller cancelled                                     |
| `-2`  | `failedValue`    | BLE / transfer failure (emitted instead of crashing) |

Integrity mismatches (`FirmwareHashMismatchException`,
`DeviceHashMismatchException`), empty firmware, and download failures also emit
`failedValue`, then rethrow so you can catch them by type after
`await updateFirmware(...)`.

## Which platforms are supported?

BLE OTA is aimed at **Android** and **iOS**. The package may analyze on other
desktop targets via dependencies, but real updates need a BLE stack and the
permissions described in the [README](README.md#platform-setup).

## Where is the example app?

[`example/`](example/README.md) — scan, connect, and flash with the Arduino
default UUIDs (replace them for your firmware). It also demonstrates
`saveOtaLogs` with a **View OTA Logs** screen.

## How do I contribute?

See [CONTRIBUTING.md](CONTRIBUTING.md).
