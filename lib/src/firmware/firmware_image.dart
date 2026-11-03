import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_ota/src/exceptions/ota_exceptions.dart';
import 'package:flutter_ota/src/models/firmware_type.dart';

/// Supported firmware image filename extensions (lowercase, no dot).
const Set<String> supportedFirmwareExtensions = <String>{'bin', 'img'};

/// Returns the lowercase extension of [pathOrUri] without the leading dot,
/// or `null` when there is no usable filename extension.
///
/// Query strings and fragments are ignored (e.g. Drive `?usp=sharing`).
String? firmwareImageExtension(String pathOrUri) {
  final String trimmed = pathOrUri.trim();
  if (trimmed.isEmpty) return null;

  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } on FormatException {
    uri = null;
  }

  final String path = uri != null && uri.path.isNotEmpty
      ? uri.path
      : trimmed.split('?').first.split('#').first;

  final List<String> segments =
      path.split('/').where((String s) => s.isNotEmpty).toList();
  final String filename = segments.isEmpty ? path : segments.last;
  final int dot = filename.lastIndexOf('.');
  if (dot <= 0 || dot == filename.length - 1) return null;
  return filename.substring(dot + 1).toLowerCase();
}

/// Whether [pathOrUri] ends with a supported firmware extension (`.bin` / `.img`).
bool isSupportedFirmwareImage(String pathOrUri) {
  final String? ext = firmwareImageExtension(pathOrUri);
  return ext != null && supportedFirmwareExtensions.contains(ext);
}

/// Throws [UnsupportedFirmwareImageException] when [pathOrUri] is not a
/// `.bin` or `.img` firmware image path/URL/filename.
void validateFirmwareImage(String pathOrUri) {
  final String trimmed = pathOrUri.trim();
  if (trimmed.isEmpty) {
    throw UnsupportedFirmwareImageException(
      'Firmware path/URL is empty. Provide a .bin or .img file.',
    );
  }
  if (isSupportedFirmwareImage(trimmed)) return;

  final String? ext = firmwareImageExtension(trimmed);
  throw UnsupportedFirmwareImageException(
    ext == null
        ? 'Firmware must be a .bin or .img file (got no file extension in '
              '"$trimmed").'
        : 'Firmware must be a .bin or .img file (got .$ext).',
  );
}

/// Whether [bytes] look like an HTML document (viewer / error page).
bool firmwarePayloadLooksLikeHtml(Uint8List bytes) {
  int offset = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    offset = 3;
  }
  while (offset < bytes.length &&
      (bytes[offset] == 0x20 ||
          bytes[offset] == 0x09 ||
          bytes[offset] == 0x0A ||
          bytes[offset] == 0x0D)) {
    offset++;
  }
  if (bytes.length - offset < 5) return false;
  final String head = String.fromCharCodes(
    bytes.sublist(offset, offset + (bytes.length - offset).clamp(0, 15)),
  ).toLowerCase();
  return head.startsWith('<!doctype') || head.startsWith('<html');
}

/// Parses a `Content-Disposition` header value for a filename, if present.
String? filenameFromContentDisposition(String? header) {
  if (header == null || header.isEmpty) return null;

  final RegExpMatch? starred = RegExp(
    r"filename\*\s*=\s*[^']*''([^;]+)",
    caseSensitive: false,
  ).firstMatch(header);
  if (starred != null) {
    return Uri.decodeFull(starred.group(1)!.trim().replaceAll('"', ''));
  }

  final RegExpMatch? plain = RegExp(
    r'filename\s*=\s*"?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(header);
  return plain?.group(1)?.trim();
}

/// Validates downloaded firmware bytes.
///
/// Rejects empty payloads and HTML responses. When [fileName] (from
/// `Content-Disposition` or the URL path) has an extension, it must be
/// `.bin` or `.img`.
void validateFirmwarePayload(
  Uint8List bytes, {
  String? contentType,
  String? fileName,
  int? statusCode,
}) {
  if (bytes.isEmpty) {
    throw EmptyFirmwareException('Downloaded firmware is empty (0 bytes).');
  }

  final String? type = contentType?.toLowerCase();
  final bool looksLikeHtml =
      (type != null && type.contains('text/html')) ||
      firmwarePayloadLooksLikeHtml(bytes);
  if (looksLikeHtml) {
    throw FirmwareDownloadException(
      'Downloaded content is HTML, not a firmware binary (.bin / .img). '
      'Use a URL that returns the raw file, not a viewer or login page.',
      statusCode: statusCode,
    );
  }

  final String? name = fileName?.trim();
  if (name != null && name.isNotEmpty && firmwareImageExtension(name) != null) {
    validateFirmwareImage(name);
  }
}

/// Downloads [url] and returns the response body after [validateFirmwarePayload].
Future<Uint8List> downloadAndValidateFirmware(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    throw UnsupportedFirmwareImageException(
      'Firmware URL is empty. Provide a download URL.',
    );
  }

  try {
    final http.Response response = await http
        .get(Uri.parse(trimmed))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw FirmwareDownloadException(
        'HTTP Error: ${response.statusCode} - ${response.reasonPhrase}',
        statusCode: response.statusCode,
      );
    }

    final Uint8List bytes = Uint8List.fromList(response.bodyBytes);
    final String? dispositionName = filenameFromContentDisposition(
      response.headers['content-disposition'],
    );
    final String? pathName = () {
      final String? ext = firmwareImageExtension(trimmed);
      if (ext == null) return null;
      final List<String> segments = Uri.parse(trimmed).path
          .split('/')
          .where((String s) => s.isNotEmpty)
          .toList();
      return segments.isEmpty ? null : segments.last;
    }();

    validateFirmwarePayload(
      bytes,
      contentType: response.headers['content-type'],
      fileName: dispositionName ?? pathName,
      statusCode: response.statusCode,
    );
    return bytes;
  } on OtaException {
    rethrow;
  } catch (e) {
    throw FirmwareDownloadException(
      'Error fetching firmware from URL',
      cause: e,
    );
  }
}

/// Validates a firmware source without starting BLE OTA.
///
/// * [FirmwareType.url] — downloads the file, then checks it is a binary
///   (not HTML) and that any known filename ends with `.bin` / `.img`.
/// * [FirmwareType.assets] — requires [uri]; checks the asset path extension.
/// * [FirmwareType.filepicker] — opens the picker and validates the file name.
///
/// Returns `true` when validation succeeds, `false` when the user cancels the
/// file picker.
Future<bool> validateFirmwareSource(
  FirmwareType firmwareType, {
  String? uri,
}) async {
  switch (firmwareType) {
    case FirmwareType.url:
      final String trimmed = uri?.trim() ?? '';
      if (trimmed.isEmpty) {
        throw UnsupportedFirmwareImageException(
          'Firmware URL is empty. Provide a download URL.',
        );
      }
      await downloadAndValidateFirmware(trimmed);
      return true;
    case FirmwareType.assets:
      final String trimmed = uri?.trim() ?? '';
      if (trimmed.isEmpty) {
        throw UnsupportedFirmwareImageException(
          'Firmware asset path is empty. Provide a .bin or .img asset.',
        );
      }
      validateFirmwareImage(trimmed);
      return true;
    case FirmwareType.filepicker:
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedFirmwareExtensions.toList(),
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return false;
      }
      validateFirmwareImage(result.files.first.name);
      return true;
  }
}
