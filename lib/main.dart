import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
// Amplify imports
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:user_14_updated/services/shared_preference.dart';

import 'amplifyconfiguration.dart'; // generated config
import 'data/get_data.dart';
import 'data/global.dart';
import 'models/model_provider.dart';
import 'screens/map_page.dart';
import 'utils/text_sizing.dart';

// Top-level Amplify configuration helper and readiness future
Future<void> configureAmplifyOnce() async {
  try {
    if (!Amplify.isConfigured) {
      final provider = ModelProvider();
      Amplify.addPlugin(AmplifyDataStore(modelProvider: provider));
      Amplify.addPlugin(
        AmplifyAPI(options: APIPluginOptions(modelProvider: provider)),
      );
      await Amplify.configure(amplifyconfig);
      if (kDebugMode) print('Amplify configured');
    } else {
      if (kDebugMode) print('Amplify already configured');
    }
  } catch (e, st) {
    if (kDebugMode) print('Amplify configuration error: $e\n$st');
    rethrow;
  }
}

// Exposed readiness future other code can await
final Future<void> amplifyReady = configureAmplifyOnce();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure Amplify configured before the app starts
  try {
    await amplifyReady;
  } catch (e) {
    if (kDebugMode) print('Amplify failed to configure in main: $e');
    // Choose to continue in local-only mode or rethrow during development
    // rethrow;
  }

  // load other app data
  await BusData().loadData();

  // load saved dark mode before building the first frame (to prevent flashing light mode)
  final SharedPreferenceService prefsService = SharedPreferenceService();
  final bool savedDark = await prefsService.loadDarkMode();
  isDarkMode = savedDark; // keep global in sync

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('rebuilt app');
    }
    // sets size at start so layout will scale accordingly
    TextSizing.setSize(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      initialRoute: '/home',
      routes: {'/home': (context) => MapPage()},
    );
  }
}
