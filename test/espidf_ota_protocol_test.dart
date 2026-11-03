import 'dart:typed_data';

import 'package:flutter_ota/src/protocol/espidf_ota_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  Uint8List firmware(int length) =>
      Uint8List.fromList(List<int>.generate(length, (i) => i % 256));

  group('EspIdfOtaProtocol.performUpdate', () {
    test('returns true and streams chunks when device acknowledges', () async {
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[
          <int>[1],
          <int>[5],
        ],
      );
      final EspIdfOtaProtocol protocol = EspIdfOtaProtocol();
      final List<int> progress = <int>[];

      final bool ok = await protocol.performUpdate(
        transport: transport,
        firmware: firmware(10),
        mtuSize: 4,
        isCancelRequested: () => false,
        onProgress: progress.add,
      );

      expect(ok, isTrue);
      // First data write is the 2-byte MTU packet, then 3 firmware chunks.
      expect(transport.dataWrites.first.length, 2);
      expect(transport.dataWrites.length, 1 + 3);
      expect(transport.dataWrites.sublist(1).map((c) => c.length), <int>[
        4,
        4,
        2,
      ]);
      // Control channel: begin (1) then finish (4).
      expect(transport.controlWrites.map((c) => c.first), <int>[1, 4]);
      // Transfer progress caps at 99; terminal 100 comes from OtaClient after ACK.
      expect(progress.last, 99);
      expect(progress.every((p) => p < 100), isTrue);
    });

    test('returns false on an unexpected final status', () async {
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[
          <int>[1],
          <int>[9],
        ],
      );

      final bool ok = await EspIdfOtaProtocol().performUpdate(
        transport: transport,
        firmware: firmware(8),
        mtuSize: 4,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      expect(ok, isFalse);
    });

    test('returns false when the initial control read is empty', () async {
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[<int>[]],
      );

      final bool ok = await EspIdfOtaProtocol().performUpdate(
        transport: transport,
        firmware: firmware(8),
        mtuSize: 4,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      expect(ok, isFalse);
    });

    test('stops and returns false when cancellation is requested', () async {
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[
          <int>[1],
        ],
      );

      final bool ok = await EspIdfOtaProtocol().performUpdate(
        transport: transport,
        firmware: firmware(64),
        mtuSize: 4,
        isCancelRequested: () => true,
        onProgress: (_) {},
      );

      expect(ok, isFalse);
      // Only the MTU packet was written; no firmware chunks were sent.
      expect(transport.dataWrites, hasLength(1));
    });
  });
}
