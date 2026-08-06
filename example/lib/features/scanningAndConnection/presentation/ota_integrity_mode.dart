import 'package:flutter_ota/flutter_ota.dart';

import 'ota_ble_constants.dart';

/// Integrity preset shown in the example UI.
enum OtaIntegrityMode { none, preSha, postSha, both }

extension OtaIntegrityModeX on OtaIntegrityMode {
  bool get needsSha => this != OtaIntegrityMode.none;

  FirmwareIntegrityConfig toConfig(String expectedSha256Hex) {
    final String hex = expectedSha256Hex.trim();
    return switch (this) {
      OtaIntegrityMode.none => FirmwareIntegrityConfig.none,
      OtaIntegrityMode.preSha => FirmwareIntegrityConfig(
        features: {IntegrityFeature.shaBeforeTransfer},
        expectedSha256Hex: hex,
      ),
      OtaIntegrityMode.postSha => FirmwareIntegrityConfig(
        features: {IntegrityFeature.shaAfterFlash},
        expectedSha256Hex: hex,
      ),
      OtaIntegrityMode.both => FirmwareIntegrityConfig(
        features: {
          IntegrityFeature.shaBeforeTransfer,
          IntegrityFeature.shaAfterFlash,
        },
        expectedSha256Hex: hex,
      ),
    };
  }
}

/// Parses the OTA form MTU field. Returns `null` when [raw] is not an int.
int? parseMtuSize(String raw) => int.tryParse(raw.trim());

/// Practical max `mtuSize` for [updateType] when ATT MTU is 512.
///
/// ESP-IDF: ≤ 509 (`ATT_MTU - 3`). Arduino: ≤ 507 (also reserves the 2-byte
/// packet header). Package hard caps are slightly higher (512 / 510) but those
/// values fail at the BLE write layer on typical devices.
int maxMtuForUpdateType(UpdateType updateType) {
  return updateType == UpdateType.arduino
      ? OtaBleConstants.maxArduinoMtuSize
      : OtaBleConstants.maxEspIdfMtuSize;
}

/// Returns a user-facing error, or `null` when the form is valid.
String? validateOtaForm({
  required FirmwareType firmwareType,
  required String url,
  required OtaIntegrityMode integrityMode,
  required String sha256Hex,
  required UpdateType updateType,
  required String mtuSizeText,
}) {
  if (firmwareType == FirmwareType.url) {
    if (url.trim().isEmpty) return 'Enter a firmware URL';
  } else if (firmwareType == FirmwareType.assets) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return 'Enter an asset path';
    if (!isSupportedFirmwareImage(trimmed)) {
      return 'Asset path must end with .bin or .img';
    }
  }
  if (integrityMode.needsSha && sha256Hex.trim().isEmpty) {
    return 'Enter the expected SHA-256 hex digest';
  }

  final int? mtuSize = parseMtuSize(mtuSizeText);
  final int maxAllowed = maxMtuForUpdateType(updateType);
  if (mtuSize == null) {
    return 'Enter a valid MTU / chunk size (integer)';
  }
  if (mtuSize < 1 || mtuSize > maxAllowed) {
    return 'MTU must be between 1 and $maxAllowed for ${updateType.name}';
  }
  return null;
}
