# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-31

### Added

- Optional `saveOtaLogs` parameter on `updateFirmware` (default `true`) to
  capture the current OTA run’s log lines in memory for host-app debug UIs.
  Oversized / firmware-payload dumps are never stored — status, handshake,
  progress, and error lines only.
- Exported session-log helpers: `otaSessionLogs`, `otaSessionLogText`,
  `clearOtaSessionLogs`, and `otaLogCaptureEnabled`.
- Example app: **Save OTA logs** toggle, **View OTA Logs** screen with
  copy/clear, and route `/ota_logs`.
- `validateFirmwareImage` / `isSupportedFirmwareImage` — pre-check that a path,
  URL, or filename is `.bin` or `.img` before starting OTA.
- `validateFirmwareSource` — for URLs, downloads then validates the payload
  (rejects HTML; checks `.bin`/`.img` when a filename is known). Assets and
  file picker still validate the path/name up front.
- Shared `downloadAndValidateFirmware` / `validateFirmwarePayload` replace the
  URL-only Google Drive HTML helper.
- `UnsupportedFirmwareImageException` when the image type is not supported.
- File picker restricted to `.bin` / `.img` (`FileType.custom`).
- GitHub Actions CI workflow that runs `dart format`, `flutter analyze`, and
  `flutter test` (package + example) on pushes and pull requests.
- Optional, composable firmware integrity via `FirmwareIntegrityConfig` /
  `IntegrityFeature`:
  - `shaBeforeTransfer` — Flutter SHA-256 of the loaded binary vs a
    server-provided digest before any BLE write.
  - `shaAfterFlash` — expected digest sent to the device **after** the image
    (ESP-IDF PostSHA: `SET_HASH`/`0x07` + 32 bytes, then `DONE`; Arduino:
    `0xF9` flags + `0xFA` + 32 bytes after the last segment); success only
    after post-flash verification (Arduino `0x0F` / ESP-IDF status `5`;
    mismatch Arduino `0x0E` / ESP-IDF status `6`).
- Features combine freely so firmware may support SHA-start only, SHA-end only,
  both, or neither. Default remains no integrity (unchanged wire format).
- Typed integrity exceptions: `FirmwareIntegrityException`,
  `FirmwareHashMismatchException`, `DeviceHashMismatchException`.
  Pre-transfer and device post-flash mismatches both emit `failedValue` on
  `percentageStream` and then rethrow so callers can catch by type.
- Unit tests for config validation, pre-transfer SHA, and protocol
  integrity paths.
- Typed exception hierarchy for OTA failures — `OtaException` (base),
  `EmptyFirmwareException`, and `FirmwareDownloadException` (which carries the
  HTTP `statusCode`) — so callers can handle errors by type instead of matching
  on raw strings.
- Validation that rejects an empty downloaded firmware body (HTTP 200 with
  0 bytes) before chunking.
- Early-fail guard that aborts the update when the firmware is empty, before any
  BLE handshake or writes are sent, so the device is never left mid-update with
  nothing to flash.
- `dispose()` method on `OtaPackage` for resource management; the package also
  disposes itself when an update reaches a terminal state.
- Optional `mtuSize` parameter on `updateFirmware` to control the chunk
  (packet) size used during transfer, honoured by both the ESP-IDF and Arduino
  paths.
- `maxMtuSize` (512) and `arduinoHeaderSize` (2) constants, plus up-front,
  protocol-aware validation of `mtuSize`: it must be between 1 and 512 for
  ESP-IDF, or 1 and 510 for Arduino (which prepends a 2-byte packet header).
  Out-of-range values throw `OtaException` before any BLE writes, instead of
  failing mid-transfer with a GATT error.
- Structured `logger`-based logging, replacing `print` statements.
- README section on aligning `BluetoothDevice.requestMtu()` with the `mtuSize`
  passed to `updateFirmware`, including per-protocol wire-size notes for
  ESP-IDF and Arduino.

### Fixed

- ESP-IDF transfer progress no longer reaches `100` before the device ACKs
  FINISH (status `5`). Mid-transfer progress is capped at `99`; terminal `100`
  is emitted only after a successful device acknowledgement. The example app
  also treats success as `firmwareUpdate` after ACK, not progress alone.
- URL firmware downloads that return HTML (e.g. a Google Drive `/view` share
  page) are rejected with a clear error instead of being hashed as firmware.
- `FirmwareDownloadException` and `EmptyFirmwareException` are rethrown after
  emitting `failedValue`, so UIs can show the real failure reason (not only a
  generic “OTA failed” toast).
- `OtaClient.run()` now rejects concurrent calls with `OtaException` (same
  re-entrancy guard as `Esp32OtaPackage.updateFirmware`), so custom
  transport/protocol users cannot interleave writes on a shared transport.
- `DeviceHashMismatchException` is now thrown (and rethrown by `OtaClient`
  after `failedValue`) when the device reports a post-flash SHA-256 mismatch
  (Arduino `0x0E` / ESP-IDF status `6`), matching pre-transfer
  `FirmwareHashMismatchException` handling. Previously the exception was only
  constructed for logging on the Arduino path, and the ESP-IDF path returned
  `false` with no typed error.
- Arduino updates now use the caller-supplied `mtuSize`. Previously it was
  ignored in favour of the device-negotiated MTU and hardcoded values (`200`,
  `400`), so the requested chunk size never reached the device.
- Arduino OTA progress for firmware with more than 255 segments: progress now
  uses the full 16-bit segment index from device notifications instead of the
  low byte only, which previously caused progress to wrap above ~4 MB.
- Arduino notification handler no longer throws `RangeError` on empty or short
  device notifications; `0x0F` (complete) and `0xF2` (install start) messages
  are handled safely using only the opcode byte.
- Short or invalid Arduino `0xF1` segment requests (truncated payload or
  out-of-range segment index) now fail the OTA update instead of being silently
  ignored, which could leave the transfer stuck without a terminal
  `failedValue`.
- Unknown Arduino opcodes no longer decode `value[1]`/`value[2]` as a segment
  index or emit misleading progress.
- ESP-IDF control-characteristic reads are guarded against empty responses
  before indexing `value[0]`.

### Changed

- Refactored the OTA API to use the `UpdateType` and `FirmwareType` enums in
  place of integer codes.
- Firmware loaders now throw the typed exceptions above instead of plain
  `String`s, and rethrow existing `OtaException`s without re-wrapping them.
- Generalised the failure log message from "BLE error" to "OTA update aborted"
  to reflect that it now also covers validation failures.
- Removed the unused `mtuSize` parameter from internal Arduino raw file-picker
  loading; Arduino chunking still happens in `ArduinoOtaProtocol` during
  transfer.
- ESP-IDF transfer loop now validates that each pre-chunked payload is ≤
  `mtuSize` before writing, catching internal chunk/handshake mismatches early.

### Removed

- The unused `service` and UUID parameters from `updateFirmware`.
- Unused helper methods (`getFirmware`, `uint8ListToIntList`) from
  `Esp32OtaPackage`.
- The hardcoded `mtu` field (`400`) on `Esp32OtaPackage`; `sendPart` now takes
  the chunk size as a parameter sourced from `mtuSize`.

## [0.1.15] - 2024-04-18

### Changed

- Updated dependencies to the latest versions.

## [0.0.5] - 2023-08-08

### Added

- First public release of the `flutter_ota` package on pub.dev.
- Firmware update over Bluetooth Low Energy (BLE) for ESP32.

[1.0.0]: https://github.com/sparkleo-io/flutter_ota/compare/v0.1.15...v1.0.0
[0.1.15]: https://github.com/sparkleo-io/flutter_ota/compare/v0.0.5...v0.1.15
[0.0.5]: https://github.com/sparkleo-io/flutter_ota/releases/tag/v0.0.5
