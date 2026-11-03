/// Value emitted on [OtaPackage.percentageStream] when an update is cancelled.
const int cancelledValue = -1;

/// Value emitted on [OtaPackage.percentageStream] when an update fails because
/// of a BLE error (e.g. the device disconnects or a write fails with a GATT
/// error). The package emits this instead of throwing so the app does not crash.
const int failedValue = -2;

/// Maximum size, in bytes, of a single BLE characteristic write.
///
/// BLE caps a single characteristic write at 512 bytes — the maximum attribute
/// length defined in the Bluetooth spec, which `flutter_blue_plus` also enforces
/// on both Android and iOS. Writes larger than this fail at runtime, so
/// [Esp32OtaPackage.updateFirmware] rejects any chunk that would exceed it.
const int maxMtuSize = 512;

/// Number of header bytes the Arduino OTA protocol prepends to every BLE data
/// packet (`0xFB` marker + packet index — see [ArduinoOtaProtocol]).
///
/// Because of this overhead an Arduino packet on the wire is `mtuSize + 2`
/// bytes, so the largest usable `mtuSize` for the Arduino path is
/// [maxMtuSize] - [arduinoHeaderSize].
const int arduinoHeaderSize = 2;

/// Size in bytes of a SHA-256 digest.
const int sha256DigestSize = 32;

/// Arduino: app announces which optional integrity features are active.
/// Payload: `[0xF9, flags]` where bit1 = shaAfterFlash.
/// Sent after all firmware segments (same timing as ESP-IDF PostSHA).
const int arduinoIntegrityFlagsOpcode = 0xF9;

/// Arduino: app sends the expected SHA-256 digest for post-flash verification.
/// Payload: `[0xFA, …32 digest bytes]`. Sent after [arduinoIntegrityFlagsOpcode].
const int arduinoExpectedHashOpcode = 0xFA;

/// Arduino: device reports post-flash SHA-256 mismatch.
const int arduinoHashMismatchOpcode = 0x0E;

/// Integrity flags byte bit: post-flash SHA-256 verification enabled.
const int integrityFlagShaAfterFlash = 0x02;

/// ESP-IDF control status: final success (including post-flash SHA when used).
const int espIdfStatusSuccess = 5;

/// ESP-IDF control status: post-flash SHA-256 mismatch.
const int espIdfStatusHashMismatch = 6;

/// ESP-IDF control command: begin OTA (phone → device).
const int espIdfControlBegin = 1;

/// ESP-IDF control status: request accepted (device → phone).
const int espIdfControlAck = 2;

/// ESP-IDF control status: request rejected (device → phone).
const int espIdfControlNak = 3;

/// ESP-IDF control command: finish / verify (phone → device).
const int espIdfControlFinish = 4;

/// ESP-IDF control command: next data write is the expected SHA-256 digest
/// (phone → device). PostSHA: send after all firmware chunks, before finish.
/// Value is `7` — do **not** reuse `2` (`ACK`).
const int espIdfControlExpectedHash = 7;
