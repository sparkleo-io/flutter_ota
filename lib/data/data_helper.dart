//data/data_helper.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

List<int> uint8ListToIntList(Uint8List uint8List) {
  return uint8List.toList();
}

Future<List<Uint8List>> readBinaryFile(String filePath) async {
  final ByteData data = await rootBundle.load(filePath);
  final List<int> bytes = data.buffer.asUint8List();
  const chunkSize = 512;
  List<Uint8List> chunks = [];
  for (int i = 0; i < bytes.length; i += chunkSize) {
    int end = i + chunkSize;
    if (end > bytes.length) {
      end = bytes.length;
    }
    Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
    chunks.add(chunk);
  }
  return chunks;
}
