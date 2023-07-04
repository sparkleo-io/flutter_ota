// presentation layer/ main.dart

import 'package:flutter/material.dart';
import 'package:ota_test/domain/usecases/home_page.dart';


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BLE Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: MyHomePage(title: 'Flutter BLE Demo'),
  );
}

