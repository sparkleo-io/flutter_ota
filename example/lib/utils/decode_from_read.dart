import 'dart:convert';
import 'dart:typed_data';

import '../common/toast/show_toast.dart';

class DecodeRead {
  List<int> uInt8(List<int> values) {
    List<int> converted = [];
    converted = values;
    return converted;
  }

  List<int> uInt16L(List<int> values) {
    // uint-16 little endian method
    List<int> converted = [];
    List firstNo = [];
    List lastNo = [];
    List temp = values;

    if (temp.length >= 2) {
      try {
        for (int i = 0; i < temp.length; i = i + 2) {
          firstNo.add(temp[i]);
        }
        for (int j = 1; j < temp.length; j = j + 2) {
          lastNo.add(temp[j]);
        }
        for (int x = 0; x < firstNo.length; x++) {
          converted.add((firstNo[x] + (lastNo[x] << 8)));
        }
      } catch (e) {
        showToast('Error! wrong data type selected');
      }
    } else {
      showToast('For a Uint16, at least 2 bytes are required.');
    }
    return converted;
  }

  List<int> uInt16B(List<int> values) {
    // uint-16 method big endian
    List<int> converted = [];
    List<int> temp = values;
    // temp.add(values[i]);
    // if (values.length % 4 != 0) {
    //   temp.removeLast();
    // }
    if (temp.length >= 2) {
      try {
        Uint8List toUint8 = Uint8List.fromList(temp);
        int size = temp.length ~/ 2;
        for (int i = 0; i < size; i++) {
          var sample =
          toUint8.buffer.asByteData(0).getUint16(i * 2, Endian.big);
          converted.add(sample);
        }
      } catch (e) {
        showToast('Error! wrong data type selected');
      }
    } else {
      showToast('For a Uint16, at least 2 bytes are required.');
    }

    return converted;
  }

  List uInt32B(List<int> values) {
    // uint 32 method big endian
    List converted = [];
    List<int> temp = values;
    // for (int i = 0; i < values.length; i++) {
    //   temp.add(values[i]);
    // if (values.length % 4 != 0) {
    //   temp.removeLast();
    // }
    // }
    if (temp.length >= 4) {
      try {
        Uint8List toUint8 = Uint8List.fromList(temp);
        int size = temp.length ~/ 4;
        for (int i = 0; i < size; i++) {
          var sample =
          toUint8.buffer.asByteData(0).getUint32(i * 4, Endian.big);
          converted.add(sample);
        }
      } catch (e) {
        showToast('Error! wrong data type selected');
      }
    } else {
      showToast('For a Uint32, at least 4 bytes are required.');
    }
    return converted;
  }

  List uInt32L(List<int> values) {
    // uint 32 method little endian
    List converted = [];
    List<int> temp = values;
    // for (int i = 0; i < values.length; i++) {
    //   temp.add(values[i]);
    // if (values.length % 4 != 0) {
    //   temp.removeLast();
    // }
    // }

    if (temp.length >= 4) {
      try {
        Uint8List toUint8 = Uint8List.fromList(temp);
        converted = toUint8.buffer.asUint32List(0);
      } catch (e) {
        showToast('Error! wrong data type selected');
      }
    } else {
      showToast('For a Uint32, at least 4 bytes are required.');
    }
    return converted;
  }

  String string(List<int> values) {
    String converted = '';
    try {
      converted = utf8.decode(values);
      return converted;
    } catch (e) {
      showToast('Error! undefined data');
      return '';
    }
  }

  String hex(List<int> values) {
    String converted = '';
    try {
      for (int i = 0; i < values.length; i++) {
        String toR = values[i].toRadixString(16);
        if (toR.length == 1) {
          toR = '0$toR';
        }
        converted = converted + toR;
        if (values.length - 1 > i) {
          converted = '$converted-';
        }
      }
    } catch (e) {
      showToast('Error! wrong data type selected');
    }
    return converted;
  }

  List<int> byteArray(List<int> values) {
    List<int> converted = [];
    converted = values;
    return converted;
  }
}
