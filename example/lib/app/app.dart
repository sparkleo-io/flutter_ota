import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import '../routing/app_pages.dart';

class OTANewApp extends StatelessWidget {
  const OTANewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter OTA Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      initialRoute: RoutePages.initial,
      getPages: RoutePages.routes,
    );
  }
}
