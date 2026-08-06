import 'dart:typed_data';

import 'package:flutter_ota/src/core/firmware_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chunkFirmware', () {
    test('splits into full chunks with a shorter final chunk', () {
      final Uint8List bytes = Uint8List.fromList(
        List<int>.generate(10, (i) => i),
      );

      final List<Uint8List> chunks = chunkFirmware(bytes, 4).toList();

      expect(chunks.map((c) => c.length).toList(), <int>[4, 4, 2]);
      expect(chunks[0], <int>[0, 1, 2, 3]);
      expect(chunks[1], <int>[4, 5, 6, 7]);
      expect(chunks[2], <int>[8, 9]);
    });

    test('yields a single chunk when smaller than the chunk size', () {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

      final List<Uint8List> chunks = chunkFirmware(bytes, 16).toList();

      expect(chunks, hasLength(1));
      expect(chunks.single, <int>[1, 2, 3]);
    });

    test('yields nothing for empty input', () {
      expect(chunkFirmware(Uint8List(0), 8).toList(), isEmpty);
    });

    test('divides evenly when length is a multiple of chunk size', () {
      final Uint8List bytes = Uint8List.fromList(
        List<int>.generate(8, (i) => i),
      );

      final List<Uint8List> chunks = chunkFirmware(bytes, 4).toList();

      expect(chunks.map((c) => c.length).toList(), <int>[4, 4]);
    });

    test('chunk contents concatenate back to the original bytes', () {
      final Uint8List bytes = Uint8List.fromList(
        List<int>.generate(37, (i) => i % 256),
      );

      final List<int> reassembled = <int>[
        for (final Uint8List chunk in chunkFirmware(bytes, 5)) ...chunk,
      ];

      expect(reassembled, bytes);
    });
  });

  group('chunkCount', () {
    test('rounds up partial chunks', () {
      expect(chunkCount(10, 4), 3);
      expect(chunkCount(8, 4), 2);
      expect(chunkCount(1, 4), 1);
    });

    test('returns zero for empty or invalid input', () {
      expect(chunkCount(0, 4), 0);
      expect(chunkCount(10, 0), 0);
    });

    test('matches the number of chunks produced by chunkFirmware', () {
      final Uint8List bytes = Uint8List.fromList(
        List<int>.generate(101, (i) => i % 256),
      );

      expect(chunkCount(bytes.length, 8), chunkFirmware(bytes, 8).length);
    });
  });
}
