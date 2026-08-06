import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/core/ota_client.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/models/constants.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  Uint8List firmware() => Uint8List.fromList(List<int>.generate(32, (i) => i));

  group('OtaClient.run', () {
    test('rejects an out-of-range mtuSize before starting', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final FakeProtocol protocol = FakeProtocol(maxWrite: 512);
      final OtaClient client = OtaClient(
        transport: transport,
        protocol: protocol,
        source: FakeFirmwareSource(firmware()),
      );

      await expectLater(client.run(mtuSize: 0), throwsA(isA<OtaException>()));
      await expectLater(client.run(mtuSize: 513), throwsA(isA<OtaException>()));
      expect(protocol.performCalled, isFalse);
    });

    test('rejects two concurrent run() calls', () async {
      final Completer<Uint8List> loadGate = Completer<Uint8List>();
      final FakeProtocol protocol = FakeProtocol(result: true);
      final OtaClient client = OtaClient(
        transport: FakeOtaTransport(),
        protocol: protocol,
        source: _DeferredFirmwareSource(loadGate.future),
      );

      // First run stays in-flight at source.load(); second must hit the guard.
      final Future<void> first = client.run(mtuSize: 128);
      final Future<void> second = client.run(mtuSize: 128);

      expect(client.isUpdating, isTrue);
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

      loadGate.complete(firmware());
      await first;
      expect(protocol.performCalled, isTrue);
      expect(client.isUpdating, isFalse);
    });

    test('emits 100 and reports success on a successful update', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final FakeProtocol protocol = FakeProtocol(
        result: true,
        emitProgress: <int>[25, 50, 75],
      );
      final OtaClient client = OtaClient(
        transport: transport,
        protocol: protocol,
        source: FakeFirmwareSource(firmware()),
      );

      final Future<List<int>> events = client.percentageStream.toList();

      await client.run(mtuSize: 128);

      expect(await events, <int>[25, 50, 75, 100]);
      expect(client.firmwareUpdate, isTrue);
      expect(client.isUpdating, isFalse);
      expect(transport.prepareCalls, 1);
      expect(transport.startInboundCalls, 1);
      expect(transport.disposeCalls, 1);
    });

    test('emits failedValue when the protocol reports failure', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final OtaClient client = OtaClient(
        transport: transport,
        protocol: FakeProtocol(result: false),
        source: FakeFirmwareSource(firmware()),
      );

      final Future<List<int>> events = client.percentageStream.toList();

      await client.run(mtuSize: 128);

      expect(await events, contains(failedValue));
      expect(client.firmwareUpdate, isFalse);
    });

    test('emits failedValue and rethrows when firmware is empty', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final FakeProtocol protocol = FakeProtocol();
      final OtaClient client = OtaClient(
        transport: transport,
        protocol: protocol,
        source: FakeFirmwareSource(Uint8List(0)),
      );

      final Future<List<int>> events = client.percentageStream.toList();

      await expectLater(
        client.run(mtuSize: 128),
        throwsA(isA<EmptyFirmwareException>()),
      );

      expect(await events, <int>[failedValue]);
      expect(protocol.performCalled, isFalse);
      expect(transport.disposeCalls, 1);
    });

    test('emits failedValue and rethrows on download failure', () async {
      final FakeOtaTransport transport = FakeOtaTransport();
      final FakeProtocol protocol = FakeProtocol();
      final OtaClient client = OtaClient(
        transport: transport,
        protocol: protocol,
        source: _ThrowingFirmwareSource(
          FirmwareDownloadException(
            'URL returned HTML instead of a firmware binary.',
            statusCode: 200,
          ),
        ),
      );

      final Future<List<int>> events = client.percentageStream.toList();

      await expectLater(
        client.run(mtuSize: 128),
        throwsA(
          isA<FirmwareDownloadException>().having(
            (e) => e.message,
            'message',
            contains('HTML instead of a firmware binary'),
          ),
        ),
      );

      expect(await events, <int>[failedValue]);
      expect(protocol.performCalled, isFalse);
    });
  });

  group('OtaClient.cancel', () {
    test('is a no-op when no update is running', () async {
      final OtaClient client = OtaClient(
        transport: FakeOtaTransport(),
        protocol: FakeProtocol(),
        source: FakeFirmwareSource(firmware()),
      );

      await client.cancel();
      expect(client.isUpdating, isFalse);
    });
  });
}

/// [FirmwareSource] that waits on [future] so concurrent [OtaClient.run] calls
/// can be asserted while the first update is still in flight.
class _DeferredFirmwareSource implements FirmwareSource {
  _DeferredFirmwareSource(this._future);

  final Future<Uint8List> _future;

  @override
  Future<Uint8List> load() => _future;
}

class _ThrowingFirmwareSource implements FirmwareSource {
  _ThrowingFirmwareSource(this.error);

  final Object error;

  @override
  Future<Uint8List> load() => Future<Uint8List>.error(error);
}
