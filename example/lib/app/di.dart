import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../features/scanningAndConnection/presentation/controller/scanning_connection_controller.dart';

Future<void> di() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(HomePageController());
}
