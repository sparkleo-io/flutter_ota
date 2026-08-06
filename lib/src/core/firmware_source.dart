import 'dart:typed_data';

/// Contract for loading raw firmware bytes from a single source.
///
/// Implementations return the complete binary as a [Uint8List]. An empty list
/// signals that no firmware is available (for example when the user cancels the
/// file picker); callers should treat that as an error before starting OTA.
abstract class FirmwareSource {
  /// Loads raw firmware bytes from this source.
  Future<Uint8List> load();
}
