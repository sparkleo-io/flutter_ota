import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/controller/ota_update_controller.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/view/widgets/ota_options_form.dart';
import 'package:ota_new_protocol/utils/colors.dart';

import '../../../../common/custom_button/primary_action_button.dart';

class NewOTAUpdatePage extends GetView<OtaUpdateController> {
  const NewOTAUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await controller.disconnectAndLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('OTA Update')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Connected Device Name: ${controller.deviceName}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connected Device Mac: ${controller.deviceMac}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Obx(
                  () => OtaOptionsForm(
                    updateType: controller.updateType.value,
                    firmwareType: controller.firmwareType.value,
                    integrityMode: controller.integrityMode.value,
                    urlController: controller.urlController,
                    shaController: controller.shaController,
                    mtuController: controller.mtuController,
                    onUpdateTypeChanged: controller.setUpdateType,
                    onFirmwareTypeChanged: controller.setFirmwareType,
                    onIntegrityModeChanged: controller.setIntegrityMode,
                    onValidateImage: () {
                      controller.validateSelectedFirmwareImage();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save OTA logs'),
                    subtitle: const Text(
                      'Capture detailed package logs for this update',
                    ),
                    activeColor: secondaryColor,
                    inactiveTrackColor: Colors.white,
                    inactiveThumbColor: secondaryColor,
                    value: controller.saveOtaLogs.value,
                    onChanged: controller.setSaveOtaLogs,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: 'Start OTA',
                  onTap: controller.startOta,
                ),
                Obx(() {
                  if (!controller.saveOtaLogs.value) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: PrimaryActionButton(
                      label: 'View OTA Logs',
                      outlined: true,
                      onTap: controller.openOtaLogs,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
