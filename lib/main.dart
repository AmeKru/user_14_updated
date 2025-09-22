import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/get_data.dart';
import 'screens/map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BusData().loadData();

  ////////////////////////////////////////////////////////////////////
  // needed to hide navigation bar on android devices
  // Start hidden by default
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
      routes: {'/home': (context) => MapPage()},
    );
  }
}
