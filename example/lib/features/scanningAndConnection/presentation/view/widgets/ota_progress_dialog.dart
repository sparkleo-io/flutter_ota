import 'package:flutter/material.dart';
import 'package:flutter_ota/flutter_ota.dart';

import '../../../../../common/custom_button/primary_action_button.dart';

enum OtaProgressOutcome { complete, failed, cancelled }

class OtaProgressDialog extends StatelessWidget {
  const OtaProgressDialog({
    super.key,
    required this.otaPackage,
    required this.isShowing,
    required this.onOutcome,
    required this.onCancel,
  });

  final Esp32OtaPackage otaPackage;
  final ValueGetter<bool> isShowing;
  final ValueChanged<OtaProgressOutcome> onOutcome;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('OTA Update in Progress'),
      content: StreamBuilder<int>(
        stream: otaPackage.percentageStream,
        initialData: 0,
        builder: (context, snapshot) {
          final int value = snapshot.data ?? 0;

          if ((value == cancelledValue || value == failedValue) &&
              isShowing()) {
            final OtaProgressOutcome outcome = value == failedValue
                ? OtaProgressOutcome.failed
                : OtaProgressOutcome.cancelled;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onOutcome(outcome);
            });
            return const LinearProgressIndicator(value: 0);
          }

          final double progress = (value.clamp(0, 100)) / 100.0;
          // Terminal 100 is emitted only after the device ACKs success
          // (see EspIdfOtaProtocol / OtaClient). Do not treat mid-transfer
          // progress as complete without firmwareUpdate.
          if (value == 100 && otaPackage.firmwareUpdate && isShowing()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onOutcome(OtaProgressOutcome.complete);
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text('${(progress * 100).round()}%'),
            ],
          );
        },
      ),
      actions: [PrimaryActionButton(label: 'Cancel', onTap: onCancel)],
    );
  }
}
