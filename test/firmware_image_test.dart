import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/firmware/firmware_image.dart';
import 'package:flutter_ota/src/models/firmware_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firmwareImageExtension', () {
    test('parses asset paths and URLs', () {
      expect(firmwareImageExtension('assets/fw.bin'), 'bin');
      expect(firmwareImageExtension('firmware.IMG'), 'img');
      expect(
        firmwareImageExtension('https://cdn.example/a/app.bin?token=1'),
        'bin',
      );
      expect(firmwareImageExtension('noext'), isNull);
      expect(firmwareImageExtension(''), isNull);
    });
  });

  group('validateFirmwareImage', () {
    test('accepts .bin and .img', () {
      expect(() => validateFirmwareImage('fw.bin'), returnsNormally);
      expect(() => validateFirmwareImage('disk.img'), returnsNormally);
    });

    test('rejects other extensions and missing extension', () {
      expect(
        () => validateFirmwareImage('fw.hex'),
        throwsA(isA<UnsupportedFirmwareImageException>()),
      );
      expect(
        () => validateFirmwareImage(
          'https://drive.google.com/uc?export=download&id=abc',
        ),
        throwsA(isA<UnsupportedFirmwareImageException>()),
      );
    });
  });

  group('validateFirmwareSource', () {
    test('validates asset paths without downloading', () async {
      expect(
        await validateFirmwareSource(
          FirmwareType.assets,
          uri: 'assets/app.img',
        ),
        isTrue,
      );
      await expectLater(
        validateFirmwareSource(FirmwareType.assets, uri: ''),
        throwsA(isA<UnsupportedFirmwareImageException>()),
      );
      await expectLater(
        validateFirmwareSource(FirmwareType.assets, uri: 'assets/app.hex'),
        throwsA(isA<UnsupportedFirmwareImageException>()),
      );
      await expectLater(
        validateFirmwareSource(FirmwareType.url, uri: ''),
        throwsA(isA<UnsupportedFirmwareImageException>()),
      );
    });
  });
}
