import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/controller/scanning_connection_controller.dart';
import 'package:ota_new_protocol/routing/routes.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'app/app.dart';
import 'app/di.dart';
import 'common/custom_button/primary_action_button.dart';
import 'common/toast/show_toast.dart';
import 'core/permissions/bluetooth_adapter.dart';
import 'core/permissions/check_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di();

  // Listen to adapter state before the first permission check so
  // `BluetoothAdapter.isBluetoothOn` is not stuck on the stale default.
  BluetoothAdapter.initBleStateStream();

  final permissions = <ph.Permission>[
    ph.Permission.bluetooth,
    if (Platform.isAndroid) ...[ph.Permission.location, ph.Permission.storage],
  ];
  await permissions.request();
  await PermissionEnable().check();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use GetMaterialApp as the single root navigator. Nesting MaterialApp
    // above it makes Get.dialog push on the outer navigator while Get.back()
    // pops the inner GetX route, leaving dialogs stuck open.
    return const OTANewApp();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final HomePageController _controller = Get.find();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptAutoConnect();
    });
  }

  Future<void> _attemptAutoConnect() async {
    await _controller.loadLastDevice();
    if (!_controller.hasLastDevice) return;

    final connected = await _controller.autoConnectToLastDevice();
    if (!mounted) return;
    if (connected) {
      _controller.connectedDevice.value = [_controller.gBleDevice!];
      Get.toNamed(AppRoutes.newOtaUpdate);
    }
  }

  Future<void> _startScanning() async {
    if (!await PermissionEnable().check()) {
      showToast('Bluetooth/location permission required');
      return;
    }

    _controller.scannedDevicesList.clear();
    Get.toNamed(AppRoutes.scanning);
    await _controller.scanningMethod();
  }

  Future<void> _reconnectToLastDevice() async {
    final connected = await _controller.autoConnectToLastDevice();
    if (!mounted) return;
    if (connected) {
      Get.toNamed(AppRoutes.newOtaUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PrimaryActionButton(
                label: 'Start Scanning',
                onTap: _startScanning,
              ),
              Obx(() {
                if (!_controller.hasLastDevice) {
                  return const SizedBox.shrink();
                }

                final bool busy = _controller.isAutoConnecting.value;
                final String name = _controller.lastDeviceName.value;

                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _reconnectToLastDevice,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.history),
                    label: Text(
                      busy ? 'Connecting to $name...' : 'Reconnect to $name',
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
