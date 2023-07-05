// presentation layer/ main.dart

import 'package:flutter/material.dart';
import 'package:ota_package/domain/usecases/home_page.dart';




void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OTA Package',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: MyHomePage(title: 'Flutter OTA Package'),
    
  );
}

