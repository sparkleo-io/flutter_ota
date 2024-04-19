
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../features/scanningAndConnection/presentation/controller/scanning_connection_controller.dart';

di()async{
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(HomePageController());
 /* Get.put<HiveServices>(HiveServicesImplementation());
  Get.put(BleDeviceController());
  Get.put<BleUartController>(BleUartController());
  Get.put(HomePageController(Get.find<HiveServices>()));
  Get.put(AddedLeoDetailsController(Get.find<HiveServices>()));
  Get.put(BatteryController(Get.find<HiveServices>()));
  Get.put(SettingController());

  //Scanning and connection
  Get.put(HomePageDataSource());
  Get.put(HomepageRepoImpl(Get.find<HomePageDataSource>()));
  Get.put(ScanningUseCase(
      Get.find<HomepageRepoImpl>()
  ));
  Get.put(ConnectionUseCase(
      Get.find<HomepageRepoImpl>()
  ));*/

}