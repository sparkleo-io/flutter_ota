import 'dart:typed_data';

/// Contract for the physical link used during an OTA transfer.
///
/// Protocols interact with the device through this interface rather than
/// transport-specific APIs (for example BLE characteristics). Not every
/// transport needs to support every operation — pair a protocol with a
/// compatible transport. Unused operations may throw [UnsupportedError].
abstract class OtaTransport {
  /// Prepares the link for transfer (for example requesting a larger BLE MTU).
  Future<void> prepare({required int mtuSize});

  /// Writes firmware payload bytes on the bulk data channel.
  Future<void> writeData(Uint8List data);

  /// Writes control/command bytes on the control channel.
  Future<void> writeControl(Uint8List data);

  /// Performs a blocking read on the control channel.
  Future<Uint8List> readControl();

  /// Enables inbound messages from the device (for example BLE notifications).
  Future<void> startInbound();

  /// Stream of inbound messages from the device.
  Stream<Uint8List> get inbound;

  /// Releases transport resources.
  Future<void> dispose();
}
