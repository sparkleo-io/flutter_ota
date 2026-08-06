import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_new_protocol/routing/routes.dart';

import '../../../../common/custom_button/feedback_enabled_button.dart';
import '../../../../common/custom_button/primary_action_button.dart';
import '../../../../common/toast/show_toast.dart';
import '../../../../utils/colors.dart';
import '../controller/scanning_connection_controller.dart';

class ScanningPageView extends StatefulWidget {
  const ScanningPageView({super.key});

  @override
  State<ScanningPageView> createState() => _ScanningPageViewState();
}

class _ScanningPageViewState extends State<ScanningPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  final HomePageController _controller = Get.find();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _onDeviceTapped(int index) async {
    final device = _controller.scannedDevicesList[index];
    _controller.gBleDevice = device;
    _controller.gIsDeviceConnected.value = false;

    final connected = await _controller.connectToDevice();
    if (!mounted) return;

    if (connected) {
      _controller.connectedDevice
        ..clear()
        ..add(device);
      Get.toNamed(AppRoutes.newOtaUpdate);
    } else {
      showToast('Could not connect to Device');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanning')),
      body: SafeArea(
        child: Obx(
          () => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotationController,
                      child: const Icon(
                        Icons.autorenew_rounded,
                        color: Colors.black,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        'Available Devices',
                        style: TextStyle(
                          color: Color(0xFF282828),
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _controller.scannedDevicesList.length,
                  itemBuilder: (context, index) {
                    final device = _controller.scannedDevicesList[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: FeedbackEnabledDeviceTile(
                        name: device.advName,
                        onTap: () => _onDeviceTapped(index),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: PrimaryActionButton(
                  label: 'Cancel',
                  outlined: true,
                  onTap: Get.back,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Device row in the scanning list.
class FeedbackEnabledDeviceTile extends StatelessWidget {
  const FeedbackEnabledDeviceTile({
    super.key,
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FeedbackEnabledButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: secondaryColor, width: 2),
        ),
        padding: const EdgeInsets.all(15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.bluetooth, color: whiteColor, size: 25),
          ],
        ),
      ),
    );
  }
}
