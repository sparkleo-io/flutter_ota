import 'dart:typed_data';

import 'package:flutter_ota/src/core/ota_transport.dart';

/// Contract for an OTA wire-format / state-machine implementation.
///
/// Each protocol receives raw firmware bytes and performs its own
/// protocol-specific chunking and transfer sequencing.
abstract class OtaProtocol {
  /// Largest usable per-write payload size for this protocol.
  ///
  /// The [OtaClient] validates `mtuSize` against this value before transfer.
  int get maxWriteSize;

  /// Runs the full firmware transfer over [transport].
  ///
  /// Returns `true` when the device acknowledges a successful update.
  /// Returns `false` for generic transfer failures.
  ///
  /// Throws `DeviceHashMismatchException` when the device reports a post-flash
  /// SHA-256 mismatch so the client can rethrow it after emitting `failedValue`.
  Future<bool> performUpdate({
    required OtaTransport transport,
    required Uint8List firmware,
    required int mtuSize,
    required bool Function() isCancelRequested,
    required void Function(int percent) onProgress,
  });

  /// Aborts an in-flight update (tears down subscriptions, unblocks waits).
  Future<void> cancel();
}
