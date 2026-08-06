import 'dart:typed_data';

/// Shared firmware chunking used by every OTA protocol.
///
/// Splitting is lazy and allocation-free: each yielded [Uint8List] is a
/// [Uint8List.sublistView] over the original buffer, so iterating never copies
/// the firmware or materializes a full `List<Uint8List>`. This keeps peak
/// memory to roughly one copy of the firmware regardless of protocol.
Iterable<Uint8List> chunkFirmware(Uint8List bytes, int chunkSize) sync* {
  assert(chunkSize > 0, 'chunkSize must be greater than zero');
  for (int offset = 0; offset < bytes.length; offset += chunkSize) {
    final int end = offset + chunkSize < bytes.length
        ? offset + chunkSize
        : bytes.length;
    yield Uint8List.sublistView(bytes, offset, end);
  }
}

/// Number of [chunkSize]-byte chunks required to cover [byteLength].
int chunkCount(int byteLength, int chunkSize) {
  if (chunkSize <= 0 || byteLength <= 0) return 0;
  return (byteLength / chunkSize).ceil();
}
