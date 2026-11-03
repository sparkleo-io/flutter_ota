import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ota/flutter_ota.dart';
import 'package:get/get.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/controller/scanning_connection_controller.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/ota_ble_constants.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/ota_ble_helpers.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/ota_integrity_mode.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/view/widgets/ota_progress_dialog.dart';
import 'package:ota_new_protocol/routing/routes.dart';

import '../../../../common/toast/show_toast.dart';

class OtaUpdateController extends GetxController {
  OtaUpdateController({HomePageController? home})
    : home = home ?? Get.find<HomePageController>();

  final HomePageController home;

  static const String _genericFailureToast =
      'OTA Update Failed. Reconnect to the device before retrying.';

  final Rx<UpdateType> updateType = UpdateType.espidf.obs;
  final Rx<FirmwareType> firmwareType = FirmwareType.filepicker.obs;
  final Rx<OtaIntegrityMode> integrityMode = OtaIntegrityMode.none.obs;

  /// Mirrors [Esp32OtaPackage.updateFirmware]'s `saveOtaLogs` flag.
  /// When true, the OTA page shows a button that opens the logger screen.
  final RxBool saveOtaLogs = true.obs;

  late final TextEditingController urlController;
  late final TextEditingController shaController;
  late final TextEditingController mtuController;

  Esp32OtaPackage? activePackage;
  bool showProgressDialog = false;

  bool _otaInProgress = false;
  bool _leavingOnDisconnect = false;
  /// Set when the progress stream reports failure; replaced by a typed
  /// [OtaException] message when one is thrown after [failedValue].
  String? _pendingFailureMessage;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  BluetoothDevice? get device => home.gBleDevice;

  String get deviceName {
    final BluetoothDevice? current = device;
    if (current == null || current.platformName.isEmpty) return 'Unknown';
    return current.platformName;
  }

  String get deviceMac => device?.remoteId.str ?? 'Unknown';

  @override
  void onInit() {
    super.onInit();
    urlController = TextEditingController();
    shaController = TextEditingController(
      text: '5e00d6e700e91e3598277b5b78fb32036d4098bbcad25ee566752a43a7f38f62',
    );
    mtuController = TextEditingController(
      text: '${OtaBleConstants.defaultMtuSize}',
    );
    _connectionSubscription = device?.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        returnToHomeOnDisconnect();
      }
    });
  }

  @override
  void onClose() {
    _connectionSubscription?.cancel();
    urlController.dispose();
    shaController.dispose();
    mtuController.dispose();
    activePackage = null;
    super.onClose();
  }

  void setUpdateType(UpdateType type) => updateType.value = type;

  void setFirmwareType(FirmwareType type) => firmwareType.value = type;

  void setIntegrityMode(OtaIntegrityMode mode) => integrityMode.value = mode;

  void setSaveOtaLogs(bool value) => saveOtaLogs.value = value;

  void openOtaLogs() => Get.toNamed(AppRoutes.otaLogs);

  void returnToHomeOnDisconnect() {
    if (_leavingOnDisconnect) return;
    _leavingOnDisconnect = true;
    home.gIsDeviceConnected.value = false;
    showProgressDialog = false;
    Get.offAllNamed(AppRoutes.splash);
    showToast('Device disconnected. Reconnect to start OTA again.');
  }

  Future<void> disconnectAndLeave() async {
    if (_leavingOnDisconnect) return;
    _leavingOnDisconnect = true;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    showProgressDialog = false;
    await home.clearLastDevice();
    await home.disconnectDevice();
    Get.offAllNamed(AppRoutes.splash);
  }

  void dismissProgressDialog({String? toast, bool force = false}) {
    if (!showProgressDialog && !force) return;
    showProgressDialog = false;
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
    if (toast != null) {
      showToast(toast, duration: _toastDurationFor(toast));
    }
  }

  void onProgressOutcome(OtaProgressOutcome outcome) {
    switch (outcome) {
      case OtaProgressOutcome.complete:
        _pendingFailureMessage = null;
        dismissProgressDialog(toast: 'OTA Update Complete');
      case OtaProgressOutcome.cancelled:
        _pendingFailureMessage = null;
        dismissProgressDialog(toast: 'OTA Update Cancelled');
      case OtaProgressOutcome.failed:
        // Close the dialog now; toast after updateFirmware returns so a
        // rethrown / logged BLE error can replace this generic text.
        _pendingFailureMessage ??= _genericFailureToast;
        dismissProgressDialog();
    }
  }

  Future<void> cancelOta() async {
    final Esp32OtaPackage? package = activePackage;
    final bool wasInProgress = package?.isUpdating ?? false;
    _pendingFailureMessage = null;
    dismissProgressDialog(
      toast: wasInProgress ? 'OTA Update Cancelled' : null,
      force: true,
    );
    try {
      await package?.cancelUpdate();
    } catch (e) {
      debugPrint('Error cancelling OTA: $e');
    }
  }

  /// Pre-checks that the configured firmware source is a `.bin` / `.img`
  /// image without starting BLE OTA (URL, asset path, or file picker).
  Future<void> validateSelectedFirmwareImage() async {
    try {
      final String? uri = switch (firmwareType.value) {
        FirmwareType.url || FirmwareType.assets => urlController.text,
        FirmwareType.filepicker => null,
      };
      final bool validated = await validateFirmwareSource(
        firmwareType.value,
        uri: uri,
      );
      if (!validated) {
        showToast('No firmware file selected');
        return;
      }
      showToast('Firmware image looks valid (.bin / .img)');
    } on UnsupportedFirmwareImageException catch (e) {
      showToast(e.message, duration: const Duration(seconds: 4));
    } on FirmwareDownloadException catch (e) {
      showToast(e.message, duration: _toastDurationFor(e.message));
    } on EmptyFirmwareException catch (e) {
      showToast(e.message, duration: const Duration(seconds: 4));
    } catch (e) {
      showToast('Validation failed: $e', duration: const Duration(seconds: 4));
    }
  }

  Future<void> startOta() async {
    if (_otaInProgress) return;

    final String? validationError = validateOtaForm(
      firmwareType: firmwareType.value,
      url: urlController.text,
      integrityMode: integrityMode.value,
      sha256Hex: shaController.text,
      updateType: updateType.value,
      mtuSizeText: mtuController.text,
    );
    if (validationError != null) {
      showToast(validationError);
      return;
    }

    final int mtuSize = parseMtuSize(mtuController.text)!;

    final BluetoothDevice? currentDevice = device;
    final List<BluetoothService> services = home.gBleServices;
    if (currentDevice == null || services.isEmpty) {
      showToast('Connect to device first');
      return;
    }

    final characteristics = findOtaCharacteristics(services);
    if (characteristics == null) {
      await _showIncompatibleDeviceDialog();
      return;
    }

    _otaInProgress = true;
    _pendingFailureMessage = null;
    try {
      await prepareOtaMtu(currentDevice);
      final Esp32OtaPackage otaPackage = Esp32OtaPackage(
        characteristics.notify,
        characteristics.write,
      );
      activePackage = otaPackage;

      showProgressDialog = true;
      Get.dialog<void>(
        OtaProgressDialog(
          otaPackage: otaPackage,
          isShowing: () => showProgressDialog,
          onOutcome: onProgressOutcome,
          onCancel: cancelOta,
        ),
        barrierDismissible: false,
      );

      otaVerboseLogging = true;
      await otaPackage.updateFirmware(
        currentDevice,
        updateType.value,
        firmwareType.value,
        uri: firmwareType.value == FirmwareType.filepicker
            ? null
            : urlController.text.trim(),
        mtuSize: mtuSize,
        integrity: integrityMode.value.toConfig(shaController.text),
        saveOtaLogs: saveOtaLogs.value,
      );
      // Fallback if the progress stream did not already dismiss the dialog:
      // success requires device ACK (firmwareUpdate), not transfer progress alone.
      if (showProgressDialog) {
        onProgressOutcome(
          otaPackage.firmwareUpdate
              ? OtaProgressOutcome.complete
              : OtaProgressOutcome.failed,
        );
      }
    } on OtaException catch (e) {
      debugPrint('OTA failed: $e');
      _pendingFailureMessage = e.message;
      dismissProgressDialog(force: true);
    } on PlatformException catch (e) {
      debugPrint('OTA BLE platform error: $e');
      _pendingFailureMessage = _toastForPlatformException(e);
      dismissProgressDialog(force: true);
    } catch (e) {
      debugPrint('Unexpected OTA error: $e');
      _pendingFailureMessage = 'OTA update failed: $e';
      dismissProgressDialog(force: true);
    } finally {
      final String? failure = _pendingFailureMessage;
      _pendingFailureMessage = null;
      if (failure != null) {
        final String toast = _resolveFailureToast(failure);
        showToast(toast, duration: _toastDurationFor(toast));
      }
      _otaInProgress = false;
    }
  }

  /// Prefers a logged PlatformException / GATT write error when the package
  /// only reported stream `failedValue` without rethrowing.
  String _resolveFailureToast(String fallback) {
    final String? fromLogs = _bleFailureMessageFromSessionLogs();
    if (fromLogs == null) return fallback;
    if (fallback == _genericFailureToast) return fromLogs;
    return fallback;
  }

  static String? _bleFailureMessageFromSessionLogs() {
    for (final String line in otaSessionLogs.reversed) {
      const String marker = '| error:';
      final int index = line.indexOf(marker);
      if (index == -1) continue;
      final String error = line.substring(index + marker.length).trim();
      if (error.isEmpty) continue;
      return _humanizeBleWriteError(error);
    }
    return null;
  }

  static String _toastForPlatformException(PlatformException e) {
    final String raw = e.message?.trim().isNotEmpty == true
        ? '${e.code}: ${e.message}'
        : e.toString();
    return _humanizeBleWriteError(raw);
  }

  static String _humanizeBleWriteError(String error) {
    final RegExpMatch? match = RegExp(
      r'data longer than allowed[.\s]*(dataLen:\s*\d+\s*>\s*max:\s*\d+)',
      caseSensitive: false,
    ).firstMatch(error);
    if (match != null) {
      return 'BLE write too large (${match.group(1)}). Lower chunk size '
          '(ESP-IDF ≤ ${OtaBleConstants.maxEspIdfMtuSize}, '
          'Arduino ≤ ${OtaBleConstants.maxArduinoMtuSize}).';
    }
    if (error.contains('PlatformException')) {
      final RegExpMatch? pe = RegExp(
        r'PlatformException\(([^,]+),\s*([^,]+)',
      ).firstMatch(error);
      if (pe != null) {
        return '${pe.group(1)!.trim()}: ${pe.group(2)!.trim()}';
      }
    }
    return error;
  }

  static Duration _toastDurationFor(String message) {
    if (message.length > 80) return const Duration(seconds: 6);
    if (message.length > 40) return const Duration(seconds: 4);
    return const Duration(seconds: 2);
  }

  Future<void> _showIncompatibleDeviceDialog() async {
    await Get.dialog<void>(
      AlertDialog(
        title: const Text('Device Not Compatible'),
        content: const Text(
          'The device does not have the required characteristics for OTA firmware update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
