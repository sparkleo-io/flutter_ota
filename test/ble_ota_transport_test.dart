import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ota/src/transport/ble_ota_transport.dart';
import 'package:flutter_ota/src/transport/ble_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBleRepository extends BleRepository {
  final List<bool> notifyValues = <bool>[];
  Object? disableError;

  @override
  Future<void> setNotifyValue(
    BluetoothCharacteristic characteristic,
    bool enabled,
  ) async {
    if (!enabled && disableError != null) {
      throw disableError!;
    }
    notifyValues.add(enabled);
  }
}

void main() {
  group('BleOtaTransport.dispose', () {
    late BluetoothCharacteristic notify;
    late BluetoothCharacteristic write;
    late BluetoothDevice device;

    setUp(() {
      final DeviceIdentifier remoteId = DeviceIdentifier('00:11:22:33:44:55');
      final Guid serviceUuid = Guid('0000ffff-0000-1000-8000-00805f9b34fb');
      notify = BluetoothCharacteristic(
        remoteId: remoteId,
        serviceUuid: serviceUuid,
        characteristicUuid: Guid('0000ff01-0000-1000-8000-00805f9b34fb'),
      );
      write = BluetoothCharacteristic(
        remoteId: remoteId,
        serviceUuid: serviceUuid,
        characteristicUuid: Guid('0000ff02-0000-1000-8000-00805f9b34fb'),
      );
      device = BluetoothDevice(remoteId: remoteId);
    });

    test('disables notifications it previously enabled', () async {
      final _RecordingBleRepository repository = _RecordingBleRepository();
      final BleOtaTransport transport = BleOtaTransport(
        device: device,
        notifyCharacteristic: notify,
        writeCharacteristic: write,
        bleRepository: repository,
      );

      await transport.startInbound();
      await transport.dispose();

      expect(repository.notifyValues, <bool>[true, false]);
    });

    test('does not disable when startInbound was never called', () async {
      final _RecordingBleRepository repository = _RecordingBleRepository();
      final BleOtaTransport transport = BleOtaTransport(
        device: device,
        notifyCharacteristic: notify,
        writeCharacteristic: write,
        bleRepository: repository,
      );

      await transport.dispose();
      expect(repository.notifyValues, isEmpty);
    });

    test('swallows disable failures during teardown', () async {
      final _RecordingBleRepository repository = _RecordingBleRepository()
        ..disableError = Exception('device disconnected');
      final BleOtaTransport transport = BleOtaTransport(
        device: device,
        notifyCharacteristic: notify,
        writeCharacteristic: write,
        bleRepository: repository,
      );

      await transport.startInbound();
      await expectLater(transport.dispose(), completes);
      expect(repository.notifyValues, <bool>[true]);
    });

    test('dispose is idempotent', () async {
      final _RecordingBleRepository repository = _RecordingBleRepository();
      final BleOtaTransport transport = BleOtaTransport(
        device: device,
        notifyCharacteristic: notify,
        writeCharacteristic: write,
        bleRepository: repository,
      );

      await transport.startInbound();
      await transport.dispose();
      await transport.dispose();

      expect(repository.notifyValues, <bool>[true, false]);
    });
  });
}
