import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ota/src/esp32_ota_package.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/models/firmware_type.dart';
import 'package:flutter_ota/src/models/update_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Esp32OtaPackage.updateFirmware re-entrancy', () {
    late HttpServer hungServer;
    late String hungFirmwareUri;
    late Esp32OtaPackage package;
    late BluetoothDevice device;

    setUp(() async {
      hungServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      hungServer.listen((HttpRequest request) {
        // Leave the response open so the first updateFirmware call stays
        // in-flight across the await before _activeClient would historically
        // have been assigned — and while firmware is loading.
      });
      hungFirmwareUri =
          'http://${hungServer.address.address}:${hungServer.port}/firmware.bin';

      final DeviceIdentifier remoteId = DeviceIdentifier('00:11:22:33:44:55');
      final Guid serviceUuid = Guid('0000ffff-0000-1000-8000-00805f9b34fb');
      final BluetoothCharacteristic notify = BluetoothCharacteristic(
        remoteId: remoteId,
        serviceUuid: serviceUuid,
        characteristicUuid: Guid('0000ff01-0000-1000-8000-00805f9b34fb'),
      );
      final BluetoothCharacteristic write = BluetoothCharacteristic(
        remoteId: remoteId,
        serviceUuid: serviceUuid,
        characteristicUuid: Guid('0000ff02-0000-1000-8000-00805f9b34fb'),
      );

      package = Esp32OtaPackage(notify, write);
      device = BluetoothDevice(remoteId: remoteId);
    });

    tearDown(() async {
      await package.dispose();
      try {
        await hungServer.close(force: true);
      } on StateError {
        // Already closed by the test body after asserting re-entrancy.
      }
    });

    test('rejects two concurrent updateFirmware calls', () async {
      // Start both without awaiting: the first runs until its first `await`
      // (holding `_updateInFlight`); the second must then hit the guard.
      final Future<void> first = package.updateFirmware(
        device,
        UpdateType.espidf,
        FirmwareType.url,
        uri: hungFirmwareUri,
      );
      final Future<void> second = package.updateFirmware(
        device,
        UpdateType.espidf,
        FirmwareType.url,
        uri: hungFirmwareUri,
      );

      expect(package.isUpdating, isTrue);
      await expectLater(
        second,
        throwsA(
          isA<OtaException>().having(
            (OtaException e) => e.message,
            'message',
            contains('already in progress'),
          ),
        ),
      );

      await hungServer.close(force: true);
      await first;
    });
  });
}
