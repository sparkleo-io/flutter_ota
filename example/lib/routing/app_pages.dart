import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:ota_new_protocol/features/scanningAndConnection/presentation/view/ota_update_page.dart';

import '../features/scanningAndConnection/presentation/view/scanning_page_view.dart';
import '../main.dart';
import 'routes.dart';

class RoutePages {
  static const initial = AppRoutes.splash;
  // static const initial = AppRoutes.navBarView;

  static final routes = [
    GetPage(name: AppRoutes.splash, page: () => const MyHomePage(title: "Flutter OTA App")),
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
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    /*GetPage(
      name: AppRoutes.connecting,
      page: () => ConnectingPage(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.scanningPage,
      page: () => Scanning(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.otaUpdate,
      page: () => OtaUpdatePage(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),

    GetPage(name: AppRoutes.leoEmptyScreenView, page: () => const LeoEmptyScreen()),
    GetPage(name: AppRoutes.navBarView, page: () => BottomNavBarView()),
    GetPage(name: AppRoutes.addNewLeoDevice, page: () => const AddNewLeoDevice()),
    GetPage(name: AppRoutes.addedLeoDeviceDetails, page: () => const AddedLeoDetailsView()),
    GetPage(name: AppRoutes.setChargeLimitView, page: () => const SetChargeLimitView()),
    GetPage(name: AppRoutes.feedbackView, page: () => const FeedbackView()),*/

  ];
}
