import 'package:flutter/material.dart';

import 'data/getData.dart';
import 'screens/mapPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BusData().loadData();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;
  void onThemeChanged(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      initialRoute: '/home',
      routes: {'/home': (context) => Map_Page()},
    );
  }
}
