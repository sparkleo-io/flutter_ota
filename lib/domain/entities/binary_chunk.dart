//domain/entites/binary_chunk.dart
import 'package:flutter/services.dart';

class BinaryChunk {
  final int packageNumber;
  final Uint8List chunkData;

  BinaryChunk(this.packageNumber, this.chunkData);
}
