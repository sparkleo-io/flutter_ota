import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_source.dart';
import 'package:flutter_ota/src/core/ota_protocol.dart';
import 'package:flutter_ota/src/core/ota_transport.dart';

/// In-memory [OtaTransport] used to drive protocol/client tests without BLE.
class FakeOtaTransport implements OtaTransport {
  FakeOtaTransport({List<List<int>>? controlReads})
    : _controlReads = <Uint8List>[
        for (final read in controlReads ?? const <List<int>>[])
          Uint8List.fromList(read),
      ];

  final List<Uint8List> dataWrites = <Uint8List>[];
  final List<Uint8List> controlWrites = <Uint8List>[];
  final List<Uint8List> _controlReads;
  final StreamController<Uint8List> _inbound =
      StreamController<Uint8List>.broadcast();

  int prepareCalls = 0;
  int startInboundCalls = 0;
  int disposeCalls = 0;

  /// Pushes a device-to-host message to any active [inbound] listener.
  void emitInbound(List<int> bytes) {
    _inbound.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> prepare({required int mtuSize}) async {
    prepareCalls++;
  }

  @override
  Future<void> writeData(Uint8List data) async {
    dataWrites.add(data);
  }

  @override
  Future<void> writeControl(Uint8List data) async {
    controlWrites.add(data);
  }

  @override
  Future<Uint8List> readControl() async {
    if (_controlReads.isEmpty) return Uint8List(0);
    return _controlReads.removeAt(0);
  }

  @override
  Future<void> startInbound() async {
    startInboundCalls++;
  }

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (!_inbound.isClosed) {
      await _inbound.close();
    }
  }
}

/// [FirmwareSource] that returns a fixed byte buffer.
class FakeFirmwareSource implements FirmwareSource {
  FakeFirmwareSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> load() async => bytes;
}

/// [OtaProtocol] with configurable result and captured invocation state.
class FakeProtocol implements OtaProtocol {
  FakeProtocol({
    this.result = true,
    this.maxWrite = 512,
    this.emitProgress = const <int>[],
  });

  final bool result;
  final int maxWrite;
  final List<int> emitProgress;

  bool performCalled = false;
  bool cancelCalled = false;
  Uint8List? receivedFirmware;

  @override
  int get maxWriteSize => maxWrite;

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }

  @override
  Future<bool> performUpdate({
    required OtaTransport transport,
    required Uint8List firmware,
    required int mtuSize,
    required bool Function() isCancelRequested,
    required void Function(int percent) onProgress,
  }) async {
    performCalled = true;
    receivedFirmware = firmware;
    for (final int p in emitProgress) {
      onProgress(p);
    }
    return result;
  }
}
