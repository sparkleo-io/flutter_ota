import 'dart:typed_data';

import 'package:flutter_ota/src/protocol/arduino_ota_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  Uint8List firmware(int length) =>
      Uint8List.fromList(List<int>.generate(length, (i) => i % 256));

  group('ArduinoOtaProtocol.performUpdate', () {
    test('sends handshake and completes on the 0x0F done opcode', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol();

      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: firmware(2048),
        mtuSize: 256,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      // Handshake opcodes 0xFD, 0xFE, 0xFF are the first three data writes.
      expect(transport.dataWrites[0].first, 0xFD);
      expect(transport.dataWrites[1].first, 0xFE);
      expect(transport.dataWrites[2].first, 0xFF);

      transport.emitInbound(<int>[0x0F]);
      expect(await result, isTrue);
    });

    test('fails on a short segment request notification', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol();

      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: firmware(1024),
        mtuSize: 256,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      transport.emitInbound(<int>[0xF1, 0x00]);

      expect(await result, isFalse);
    });

    test('fails on an out-of-range segment index', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol();

      // 1024 bytes < firmwareSegmentSize, so there is exactly one segment (0).
      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: firmware(1024),
        mtuSize: 256,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      transport.emitInbound(<int>[0xF1, 0x00, 0x05]);

      expect(await result, isFalse);
    });

    test('fails on an unknown opcode', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol();

      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: firmware(1024),
        mtuSize: 256,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      transport.emitInbound(<int>[0x33, 0x00, 0x00]);

      expect(await result, isFalse);
    });

    test('ignores 0xF2 and later completes on 0x0F', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol();

      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: firmware(1024),
        mtuSize: 256,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      transport.emitInbound(<int>[0xF2]);
      await Future<void>.delayed(Duration.zero);
      transport.emitInbound(<int>[0x0F]);

      expect(await result, isTrue);
    });
  });
}
