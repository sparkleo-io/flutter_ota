import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../common/toast/show_toast.dart';

class HomePageController extends GetxController {
  RxString selectedLeoDevice = "".obs;

  RxList<BluetoothDevice> scannedDevicesList = <BluetoothDevice>[].obs;
  RxDouble screenHeight = 0.0.obs;
  BluetoothDevice? gBleDevice;
  RxList<BluetoothService> gBleServices = <BluetoothService>[].obs;
  BluetoothCharacteristic? charRep;
  RxBool gIsDeviceConnected = false.obs;
  bool showProgressDialog = true;

  RxList<BluetoothDevice> connectedDevice = <BluetoothDevice>[].obs;

  StreamSubscription? streamSubscription;
  Future<void> scanningMethod() async {
    print("In scanning method");
    final isScanning = FlutterBluePlus.isScanningNow;
    if (isScanning) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.stopScan();
    //Empty the Devices List before storing new value
    scannedDevicesList.value = [];

    await streamSubscription?.cancel();

    streamSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult r in results) {
          if (r.device.localName.isNotEmpty &&
              !scannedDevicesList.contains(r.device)) {
            print("device name is ${r.device.localName}");
            scannedDevicesList.add(r.device);
            // Listen for changes in connection state
            r.device.connectionState.listen((connectionState) {
              if (connectionState == BluetoothConnectionState.connected) {
                // Remove the device from the list if it's connected
                scannedDevicesList.remove(r.device);
              }
            });
            /*if (r.device.toString().toLowerCase().contains("laser gun")) {
                print("device name is ${r.device.localName}");
                connectionController.devicesList.add(r.device);
              }*/
          }
        }
      },
    );

    await FlutterBluePlus.startScan();
  }

  Future<bool> connectToDevice() async {
    //showToast("Connecting ....");
    await FlutterBluePlus.stopScan();
    try {
      await gBleDevice!.disconnect();
      print("before trying to connect");
      await gBleDevice!.connect(autoConnect: false);
      print("after connect");
    } catch (e) {
      if (e.toString() != 'already_connected') {
        await gBleDevice!.disconnect();
      }
    } finally {
      gBleServices.value = await gBleDevice!.discoverServices();
      print("Services discovered in connect is ${gBleServices.value}");
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (Platform.isAndroid) {
          await gBleDevice!.requestMtu(200);
          print("mtu set");
        }
      });
      Future.delayed(Duration.zero, () async {
        print("Connected my device");
        showToast('Connected');
      });
    }
    return true;
  }
}
