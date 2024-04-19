import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import '../routing/app_pages.dart';
class OTANewApp extends StatefulWidget {
  @override
  State<OTANewApp> createState() => _OTANewAppState();
}

class _OTANewAppState extends State<OTANewApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTA New App',
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      initialRoute: RoutePages.initial,
      getPages: RoutePages.routes,
      /*home: Scaffold(
        body: Center(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color.fromRGBO(125, 186, 236, 1),
                  Color.fromRGBO(82, 116, 211, 0.933),
                ],
              ),
            ),
            child: LiionAppPage(),
          ),
        ),
      ),*/
    );
  }
}