import 'package:get/get.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/controller/ota_update_controller.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/view/ota_logger_page.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/view/ota_update_page.dart';

import '../features/scanningAndConnection/presentation/view/scanning_page_view.dart';
import '../main.dart';
import 'routes.dart';

class RoutePages {
  static const initial = AppRoutes.splash;
  // static const initial = AppRoutes.navBarView;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const MyHomePage(title: "Flutter OTA App"),
    ),
    //GetPage(name: '/', page: () => LiionApp()),
    GetPage(
      name: AppRoutes.scanning,
      page: () => const ScanningPageView(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.newOtaUpdate,
      page: () => const NewOTAUpdatePage(),
      binding: BindingsBuilder(() {
        Get.put(OtaUpdateController());
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.otaLogs,
      page: () => const OtaLoggerPage(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
