import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_ota/src/core/firmware_hash.dart';
import 'package:flutter_ota/src/core/ota_client.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/models/constants.dart';
import 'package:flutter_ota/src/models/firmware_integrity.dart';
import 'package:flutter_ota/src/protocol/arduino_ota_protocol.dart';
import 'package:flutter_ota/src/protocol/espidf_ota_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('FirmwareIntegrityConfig', () {
    test('none disables all features', () {
      expect(FirmwareIntegrityConfig.none.features, isEmpty);
      expect(FirmwareIntegrityConfig.none.verifyBeforeTransfer, isFalse);
      expect(FirmwareIntegrityConfig.none.verifyAfterFlash, isFalse);
    });

    test('validate requires a digest when any SHA feature is set', () {
      expect(
        () => FirmwareIntegrityConfig(
          features: {IntegrityFeature.shaBeforeTransfer},
        ).validate(),
        throwsA(isA<OtaException>()),
      );
    });

    test('parses hex digest and supports independent feature combos', () {
      final String hex = List<String>.generate(
        32,
        (i) => i.toRadixString(16).padLeft(2, '0'),
      ).join();

      final FirmwareIntegrityConfig shaStartOnly = FirmwareIntegrityConfig(
        features: {IntegrityFeature.shaBeforeTransfer},
        expectedSha256Hex: hex,
      );
      shaStartOnly.validate();
      expect(shaStartOnly.requiresExpectedSha256, isTrue);
      expect(shaStartOnly.requiresDeviceSupport, isFalse);

      final FirmwareIntegrityConfig shaEndOnly = FirmwareIntegrityConfig(
        features: {IntegrityFeature.shaAfterFlash},
        expectedSha256Hex: hex,
      );
      shaEndOnly.validate();
      expect(shaEndOnly.requiresDeviceSupport, isTrue);

      final FirmwareIntegrityConfig all = FirmwareIntegrityConfig(
        features: {
          IntegrityFeature.shaBeforeTransfer,
          IntegrityFeature.shaAfterFlash,
        },
        expectedSha256Hex: hex,
      );
      all.validate();
      expect(all.resolvedExpectedSha256, hasLength(sha256DigestSize));
      expect(all.verifyAfterFlash, isTrue);
    });

    test('rejects malformed hex', () {
      expect(
        () => FirmwareIntegrityConfig(
          features: {IntegrityFeature.shaAfterFlash},
          expectedSha256Hex: 'deadbeef',
        ).validate(),
        throwsA(isA<OtaException>()),
      );
    });
  });

  group('OtaClient pre-transfer SHA-256', () {
    test('throws FirmwareHashMismatchException on bad digest', () async {
      final Uint8List firmware = Uint8List.fromList(
        List<int>.generate(32, (i) => i),
      );
      final String wrongHex = List<String>.filled(64, '0').join();

      final OtaClient client = OtaClient(
        transport: FakeOtaTransport(),
        protocol: FakeProtocol(),
        source: FakeFirmwareSource(firmware),
      );

      final Future<List<int>> events = client.percentageStream.toList();

      await expectLater(
        client.run(
          mtuSize: 128,
          integrity: FirmwareIntegrityConfig(
            features: {IntegrityFeature.shaBeforeTransfer},
            expectedSha256Hex: wrongHex,
          ),
        ),
        throwsA(isA<FirmwareHashMismatchException>()),
      );

      expect(await events, contains(failedValue));
    });

    test('proceeds when digest matches', () async {
      final Uint8List firmware = Uint8List.fromList(
        List<int>.generate(32, (i) => i),
      );
      final String hex = sha256.convert(firmware).toString();

      final FakeProtocol protocol = FakeProtocol(result: true);
      final OtaClient client = OtaClient(
        transport: FakeOtaTransport(),
        protocol: protocol,
        source: FakeFirmwareSource(firmware),
      );

      await client.run(
        mtuSize: 128,
        integrity: FirmwareIntegrityConfig(
          features: {IntegrityFeature.shaBeforeTransfer},
          expectedSha256Hex: hex,
        ),
      );

      expect(protocol.performCalled, isTrue);
      expect(client.firmwareUpdate, isTrue);
    });
  });

  group('ArduinoOtaProtocol integrity', () {
    test('default wire format has no integrity prelude', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol();

      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: Uint8List.fromList(List<int>.generate(64, (i) => i)),
        mtuSize: 32,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      // Handshake only — no 0xF9 / 0xFA
      expect(transport.dataWrites.take(3).map((w) => w.first), <int>[
        0xFD,
        0xFE,
        0xFF,
      ]);
      expect(
        transport.dataWrites.where(
          (w) => w.first == arduinoIntegrityFlagsOpcode,
        ),
        isEmpty,
      );

      transport.emitInbound(<int>[0x0F]);
      expect(await result, isTrue);
    });

    test(
      'sends integrity flags and hash after the image when post-flash SHA is enabled',
      () async {
        final Uint8List firmware = Uint8List.fromList(
          List<int>.generate(40, (i) => i),
        );
        final String hex = sha256.convert(firmware).toString();
        final FakeOtaTransport transport = FakeOtaTransport();
        final ArduinoOtaProtocol protocol = ArduinoOtaProtocol(
          integrity: FirmwareIntegrityConfig(
            features: {IntegrityFeature.shaAfterFlash},
            expectedSha256Hex: hex,
          ),
        );

        expect(protocol.maxWriteSize, maxMtuSize - arduinoHeaderSize);

        final Future<bool> result = protocol.performUpdate(
          transport: transport,
          firmware: firmware,
          mtuSize: 20,
          isCancelRequested: () => false,
          onProgress: (_) {},
        );

        await Future<void>.delayed(Duration.zero);

        // Handshake first — integrity comes after the image (ESP-IDF-aligned).
        expect(transport.dataWrites.take(3).map((w) => w.first), <int>[
          0xFD,
          0xFE,
          0xFF,
        ]);

        final Uint8List firstDataPacket = transport.dataWrites.firstWhere(
          (w) => w.isNotEmpty && w.first == 0xFB,
        );
        // header(2) + payload(20)
        expect(firstDataPacket.length, 22);

        final int lastFcIndex = transport.dataWrites.lastIndexWhere(
          (w) => w.isNotEmpty && w.first == 0xFC,
        );
        expect(lastFcIndex, greaterThanOrEqualTo(0));

        final int flagsIndex = transport.dataWrites.indexWhere(
          (w) => w.isNotEmpty && w.first == arduinoIntegrityFlagsOpcode,
        );
        final int hashIndex = transport.dataWrites.indexWhere(
          (w) => w.isNotEmpty && w.first == arduinoExpectedHashOpcode,
        );
        expect(flagsIndex, greaterThan(lastFcIndex));
        expect(hashIndex, flagsIndex + 1);
        expect(transport.dataWrites[flagsIndex][1], integrityFlagShaAfterFlash);
        expect(transport.dataWrites[hashIndex].length, 1 + sha256DigestSize);

        transport.emitInbound(<int>[0x0F]);
        expect(await result, isTrue);
      },
    );

    test(
      'sends post-flash hash only after the last segment on multi-segment images',
      () async {
        // Two segments: firmwareSegmentSize is 16000.
        final Uint8List firmware = Uint8List.fromList(
          List<int>.generate(16001, (i) => i % 256),
        );
        final String hex = sha256.convert(firmware).toString();
        final FakeOtaTransport transport = FakeOtaTransport();
        final ArduinoOtaProtocol protocol = ArduinoOtaProtocol(
          integrity: FirmwareIntegrityConfig(
            features: {IntegrityFeature.shaAfterFlash},
            expectedSha256Hex: hex,
          ),
        );

        final Future<bool> result = protocol.performUpdate(
          transport: transport,
          firmware: firmware,
          mtuSize: 500,
          isCancelRequested: () => false,
          onProgress: (_) {},
        );

        await Future<void>.delayed(Duration.zero);

        // After segment 0 only — no integrity yet.
        expect(
          transport.dataWrites.where(
            (w) => w.isNotEmpty && w.first == arduinoIntegrityFlagsOpcode,
          ),
          isEmpty,
        );

        transport.emitInbound(<int>[0xF1, 0x00, 0x01]); // request segment 1
        await Future<void>.delayed(Duration.zero);

        final int flagsIndex = transport.dataWrites.indexWhere(
          (w) => w.isNotEmpty && w.first == arduinoIntegrityFlagsOpcode,
        );
        expect(flagsIndex, greaterThan(0));
        expect(
          transport.dataWrites[flagsIndex + 1].first,
          arduinoExpectedHashOpcode,
        );

        transport.emitInbound(<int>[0x0F]);
        expect(await result, isTrue);
      },
    );

    test('throws DeviceHashMismatchException on post-flash hash mismatch',
        () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final ArduinoOtaProtocol protocol = ArduinoOtaProtocol(
        integrity: FirmwareIntegrityConfig(
          features: {IntegrityFeature.shaAfterFlash},
          expectedSha256Bytes: List<int>.filled(32, 1),
        ),
      );

      final Future<bool> result = protocol.performUpdate(
        transport: transport,
        firmware: Uint8List.fromList(<int>[1, 2, 3]),
        mtuSize: 32,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      await Future<void>.delayed(Duration.zero);
      transport.emitInbound(<int>[arduinoHashMismatchOpcode]);
      await expectLater(result, throwsA(isA<DeviceHashMismatchException>()));
    });

    test(
      'OtaClient rethrows DeviceHashMismatchException after failedValue',
      () async {
        final FakeOtaTransport transport = FakeOtaTransport();
        final ArduinoOtaProtocol protocol = ArduinoOtaProtocol(
          integrity: FirmwareIntegrityConfig(
            features: {IntegrityFeature.shaAfterFlash},
            expectedSha256Bytes: List<int>.filled(32, 1),
          ),
        );
        final OtaClient client = OtaClient(
          transport: transport,
          protocol: protocol,
          source: FakeFirmwareSource(Uint8List.fromList(<int>[1, 2, 3])),
        );

        final Future<List<int>> events = client.percentageStream.toList();

        // Drive the Arduino notify path after performUpdate starts listening.
        unawaited(
          Future<void>.delayed(Duration.zero, () {
            transport.emitInbound(<int>[arduinoHashMismatchOpcode]);
          }),
        );

        await expectLater(
          client.run(
            mtuSize: 32,
            integrity: FirmwareIntegrityConfig(
              features: {IntegrityFeature.shaAfterFlash},
              expectedSha256Bytes: List<int>.filled(32, 1),
            ),
          ),
          throwsA(isA<DeviceHashMismatchException>()),
        );

        expect(await events, contains(failedValue));
      },
    );
  });

  group('EspIdfOtaProtocol integrity', () {
    test('sends expected hash when post-flash SHA is enabled', () async {
      final Uint8List firmware = Uint8List.fromList(
        List<int>.generate(10, (i) => i),
      );
      final String hex = sha256.convert(firmware).toString();
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[
          <int>[espIdfControlAck], // BEGIN ack
          <int>[espIdfControlAck], // SET_HASH digest ack
          <int>[espIdfStatusSuccess],
        ],
      );

      final bool ok =
          await EspIdfOtaProtocol(
            integrity: FirmwareIntegrityConfig(
              features: {IntegrityFeature.shaAfterFlash},
              expectedSha256Hex: hex,
            ),
          ).performUpdate(
            transport: transport,
            firmware: firmware,
            mtuSize: 4,
            isCancelRequested: () => false,
            onProgress: (_) {},
          );

      expect(ok, isTrue);
      expect(transport.controlWrites.map((c) => c.first), <int>[
        espIdfControlBegin,
        espIdfControlExpectedHash,
        espIdfControlFinish,
      ]);
      expect(espIdfControlExpectedHash, 7);
      // data: MTU packet, firmware chunks, then 32-byte digest (PostSHA)
      expect(transport.dataWrites.first.length, 2); // MTU
      expect(transport.dataWrites[1].length, 4);
      expect(transport.dataWrites.last.length, sha256DigestSize);
    });

    test('sends expected hash after firmware chunks (PostSHA)', () async {
      final Uint8List firmware = Uint8List.fromList(<int>[0xE9, 2, 3, 4, 5, 6]);
      final String hex = sha256.convert(firmware).toString();
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[
          <int>[espIdfControlAck],
          <int>[espIdfControlAck],
          <int>[espIdfStatusSuccess],
        ],
      );

      await EspIdfOtaProtocol(
        integrity: FirmwareIntegrityConfig(
          features: {IntegrityFeature.shaAfterFlash},
          expectedSha256Hex: hex,
        ),
      ).performUpdate(
        transport: transport,
        firmware: firmware,
        mtuSize: 4,
        isCancelRequested: () => false,
        onProgress: (_) {},
      );

      // [0]=MTU, [1]=first image chunk must be 0xE9 (not digest)
      expect(transport.dataWrites[1].first, 0xE9);
      expect(
        transport.dataWrites.last,
        Uint8List.fromList(sha256.convert(firmware).bytes),
      );
      expect(transport.controlWrites.map((c) => c.first).toList(), <int>[
        espIdfControlBegin,
        espIdfControlExpectedHash, // 0x07 SET_HASH
        espIdfControlFinish,
      ]);
    });

    test('throws DeviceHashMismatchException on post-flash hash mismatch',
        () async {
      final FakeOtaTransport transport = FakeOtaTransport(
        controlReads: <List<int>>[
          <int>[espIdfControlAck],
          <int>[espIdfControlAck],
          <int>[espIdfStatusHashMismatch],
        ],
      );

      await expectLater(
        EspIdfOtaProtocol(
          integrity: FirmwareIntegrityConfig(
            features: {IntegrityFeature.shaAfterFlash},
            expectedSha256Bytes: List<int>.filled(32, 7),
          ),
        ).performUpdate(
          transport: transport,
          firmware: Uint8List.fromList(<int>[1, 2, 3, 4]),
          mtuSize: 4,
          isCancelRequested: () => false,
          onProgress: (_) {},
        ),
        throwsA(isA<DeviceHashMismatchException>()),
      );
    });

    test(
      'OtaClient rethrows DeviceHashMismatchException after failedValue',
      () async {
        final FakeOtaTransport transport = FakeOtaTransport(
          controlReads: <List<int>>[
            <int>[espIdfControlAck],
            <int>[espIdfControlAck],
            <int>[espIdfStatusHashMismatch],
          ],
        );
        final OtaClient client = OtaClient(
          transport: transport,
          protocol: EspIdfOtaProtocol(
            integrity: FirmwareIntegrityConfig(
              features: {IntegrityFeature.shaAfterFlash},
              expectedSha256Bytes: List<int>.filled(32, 7),
            ),
          ),
          source: FakeFirmwareSource(Uint8List.fromList(<int>[1, 2, 3, 4])),
        );

        final Future<List<int>> events = client.percentageStream.toList();

        await expectLater(
          client.run(
            mtuSize: 4,
            integrity: FirmwareIntegrityConfig(
              features: {IntegrityFeature.shaAfterFlash},
              expectedSha256Bytes: List<int>.filled(32, 7),
            ),
          ),
          throwsA(isA<DeviceHashMismatchException>()),
        );

        expect(await events, contains(failedValue));
      },
    );
  });

  group('firmware hash helpers', () {
    test('assertSha256Matches throws typed mismatch', () {
      expect(
        () => assertSha256Matches(
          actual: Uint8List.fromList(List<int>.filled(32, 1)),
          expected: List<int>.filled(32, 2),
          phase: 'before-transfer',
        ),
        throwsA(isA<FirmwareHashMismatchException>()),
      );
    });
  });
}
