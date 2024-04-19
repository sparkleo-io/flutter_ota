import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_new_protocol/routing/routes.dart';

import '../../../../common/custom_button/feedback_enabled_button.dart';
import '../../../../common/toast/show_toast.dart';
import '../../../../utils/colors.dart';
import '../controller/scanning_connection_controller.dart';

class ScanningPageView extends StatefulWidget {
  const ScanningPageView({Key? key}) : super(key: key);

  @override
  State<ScanningPageView> createState() => _ScanningPageViewState();
}

class _ScanningPageViewState extends State<ScanningPageView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  HomePageController homePageController = Get.find();

  StreamSubscription? connectionStateListener;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    ); // Use repeat to make the animation continuously rotate
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _controller.reset();
          _controller.forward();
        });
      }
    });

    _controller.forward(); // Start the initial rotation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanning"),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: whiteColor,
          border: Border.all(
            color: const Color(0xFFFFFFFF),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(Platform.isAndroid ? 60 : 25),
        ),
        height: 650, //screenHeight * 0.25,
        child: Obx(
          () => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _controller,
                      child: const Icon(
                        Icons.autorenew_rounded,
                        color: Colors.black,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        "Available Devices",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF282828),
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                    itemCount: homePageController.scannedDevicesList.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: FeedbackEnabledButton(
                          scaleFactor: 1.0,
                          translationFactorX: 0.0,
                          childWidget: Container(
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              shape: BoxShape.rectangle,
                              border: Border.all(
                                color: secondaryColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    homePageController
                                        .scannedDevicesList[index].localName,
                                    style: const TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: Icon(
                                      Icons.bluetooth,
                                      color: whiteColor,
                                      size: 25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onTap: () async {
                            print("Device tapped");
                            homePageController.gBleDevice = null;
                            homePageController.gIsDeviceConnected.value = false;
                            homePageController.gBleDevice =
                                homePageController.scannedDevicesList[index];
                            homePageController.gIsDeviceConnected.value =
                                await homePageController.connectToDevice();
                            if (homePageController.gIsDeviceConnected.value) {
                              homePageController.connectedDevice.value = [];
                              homePageController.connectedDevice
                                  .add(homePageController.gBleDevice!);
                              Get.toNamed(AppRoutes.newOtaUpdate);
                            } else {
                              showToast("Could not connect to Device");
                            }

                            //homePageController.scanningMethod();
                          },
                        ),
                      );
                    }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: FeedbackEnabledButton(
                  scaleFactor: 1.0,
                  translationFactorX: 0.0,
                  childWidget: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFFFFFFF),
                        ],
                      ),
                      shape: BoxShape.rectangle,
                      border: Border.all(
                        color: secondaryColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: secondaryColor,
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    Get.back();
                  },
                ),
                /*InkWell(
                  onTap: (){
                    Get.back();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFFFFFFF),
                        ],
                      ),
                      shape: BoxShape.rectangle,
                      border: Border.all(
                        color: secondaryColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: secondaryColor,
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),*/
              ),
            ],
          ),
        ),
      ),
    );
  }
}
