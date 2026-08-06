/// The type of update protocol used to flash the firmware.
///
/// * [UpdateType.espidf]: Firmware update following the ESP-IDF/Espressif
///   framework (formerly represented by the integer `1`).
/// * [UpdateType.arduino]: Firmware update based on the Arduino framework for
///   ESP32 (formerly represented by the integer `2`).
enum UpdateType { espidf, arduino }
