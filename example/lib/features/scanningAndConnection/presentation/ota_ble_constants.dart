/// Arduino ESP32 OTA service/characteristic UUIDs used by the example app.
abstract final class OtaBleConstants {
  static const String serviceUuid = 'd6f1d96d-594c-4c53-b1c6-144a1dfde6d8';
  static const String notifyCharacteristicUuid =
      '7ad671aa-21c0-46a4-b722-270e3ae3d830';
  static const String writeCharacteristicUuid =
      '23408888-1f40-4cd8-9b89-ca8d45f8a5b0';

  /// Default firmware chunk size shown in the OTA form (`mtuSize`).
  ///
  /// Safe for both Arduino (needs room for a 2-byte header on the wire) and
  /// ESP-IDF when ATT MTU negotiates to 512 (max write ≈ 509).
  static const int defaultMtuSize = 500;

  /// Practical max chunk size for ESP-IDF when ATT MTU is 512.
  ///
  /// Characteristic writes are capped at `ATT_MTU - 3` ≈ 509.
  static const int maxEspIdfMtuSize = 509;

  /// Practical max chunk size for Arduino when ATT MTU is 512.
  ///
  /// Wire size is `mtuSize + 2` (protocol header), so keep ≤ `509 - 2`.
  static const int maxArduinoMtuSize = 507;

  /// Preferred ATT MTU negotiation request on Android before OTA.
  ///
  /// Request the BLE max so characteristic writes can be up to ~509 bytes
  /// (`ATT_MTU - 3`). Chunk size is chosen separately via the UI.
  static const int androidRequestedMtu = 512;
}
