import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/models/constants.dart';

/// Computes the SHA-256 digest of [data].
Uint8List sha256Of(Uint8List data) {
  return Uint8List.fromList(sha256.convert(data).bytes);
}

/// Returns a lowercase hex string for [digest].
String sha256ToHex(List<int> digest) {
  final StringBuffer buffer = StringBuffer();
  for (final int byte in digest) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Compares [actual] to [expected] and throws [FirmwareHashMismatchException]
/// when they differ.
void assertSha256Matches({
  required Uint8List actual,
  required List<int> expected,
  required String phase,
}) {
  if (actual.length != sha256DigestSize ||
      expected.length != sha256DigestSize) {
    throw FirmwareHashMismatchException(
      phase: phase,
      expectedHex: expected.length == sha256DigestSize
          ? sha256ToHex(expected)
          : '(invalid length ${expected.length})',
      actualHex: actual.length == sha256DigestSize
          ? sha256ToHex(actual)
          : '(invalid length ${actual.length})',
    );
  }

  for (int i = 0; i < sha256DigestSize; i++) {
    if (actual[i] != expected[i]) {
      throw FirmwareHashMismatchException(
        phase: phase,
        expectedHex: sha256ToHex(expected),
        actualHex: sha256ToHex(actual),
      );
    }
  }
}
