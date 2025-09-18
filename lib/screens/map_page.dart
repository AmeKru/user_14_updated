import 'dart:async';
import 'dart:convert';

import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/screens/afternoon_screen.dart';
import 'package:user_14_updated/screens/info.dart';
import 'package:user_14_updated/screens/morning_screen.dart';
import 'package:user_14_updated/screens/news_announcement.dart';
import 'package:user_14_updated/screens/settings.dart';
import 'package:user_14_updated/services/get_location.dart';
import 'package:user_14_updated/services/mqtt.dart';
import 'package:user_14_updated/services/shared_preference.dart';
import 'package:user_14_updated/utils/marker_colour.dart';

///////////////////////////////////////////////////////////////
// Put this here for UI, depending on screen you use it on, not sure if really necessary

class ResponsiveConfig {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  late final bool isTablet;
  late final bool isPortrait;

  ResponsiveConfig(this.context) {
    final mq = MediaQuery.of(context);
    screenWidth = mq.size.width;
    screenHeight = mq.size.height;
    isTablet = mq.size.shortestSide >= 600;
    isPortrait = mq.orientation == Orientation.portrait;
  }

  double get iconSize => isTablet
      ? (isPortrait ? screenWidth * 0.04 : screenHeight * 0.04)
      : screenWidth * 0.05;

  double get busIconSize => isTablet
      ? (isPortrait ? screenWidth * 0.035 : screenHeight * 0.035)
      : screenWidth * 0.045;

  double get logoSize => isTablet ? screenWidth * 0.1 : screenWidth * 0.15;
}

///////////////////////////////////////////////////////////////
// start of class Map_Page

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  ///////////////////////////////////////////////////////////////
  // Variables?

  Timer? _timer;
  int selectedBox = 0;
  LatLng? currentLocation;
  double _heading = 0.0;
  List<LatLng> routePoints = [];
  bool ignoring = false;
  bool isDarkMode = false;
  DateTime now = DateTime.now();

  // Bus1 data
  LatLng? Bus1_Location;
  String? Bus1_Time;
  double? Bus1_Speed;
  String? Bus1_Stop;
  String? Bus1_ETA;
  int? Bus1_Count;

  // Bus2 data
  LatLng? Bus2_Location;
  String? Bus2_Time;
  double? Bus2_Speed;
  String? Bus2_Stop;
  String? Bus2_ETA;
  int? Bus2_Count;

  // Bus3 data
  LatLng? Bus3_Location;
  String? Bus3_Time;
  double? Bus3_Speed;
  String? Bus3_Stop;
  String? Bus3_ETA;
  int? Bus3_Count;

  ///////////////////////////////////////////////////////////////
  // Location and mqtt service

  final LocationService _locationService = LocationService();
  MQTT_Connect _mqttConnect = MQTT_Connect();

  ///////////////////////////////////////////////////////////////
  // Stops, needed to be static const so later can just use defined names in Routes

  static const LatLng ENT = LatLng(1.3329143792222058, 103.77742909276205);
  static const LatLng CLE = LatLng(1.313434, 103.765811);
  static const LatLng CLE_A = LatLng(1.314967973664341, 103.765121458707);
  static const LatLng KAP = LatLng(1.335844, 103.783160);
  static const LatLng OPP_KAP = LatLng(1.336274, 103.783146);
  static const LatLng B23 = LatLng(1.333801, 103.775738);
  static const LatLng SPH = LatLng(1.335110, 103.775464);
  static const LatLng SIT = LatLng(1.334510, 103.774504);
  static const LatLng B44 = LatLng(1.3329522845882348, 103.77145520892851);
  static const LatLng B37 = LatLng(1.332797, 103.773304);
  static const LatLng MAP = LatLng(1.332473, 103.774377);
  static const LatLng HSC = LatLng(1.330028, 103.774623);
  static const LatLng LCT = LatLng(1.330895, 103.774870);
  static const LatLng B72 = LatLng(1.3314596165361228, 103.7761976140868);
  // others
  static const LatLng UTURN = LatLng(1.326394, 103.775705);
  static const LatLng Between_HSC_LCT = LatLng(
    1.3307778258080973,
    103.77543148160284,
  );
  static const LatLng Between_B37_MAP = LatLng(
    1.3325776073001032,
    103.77438270405088,
  );
  static const LatLng CLE_UTURN = LatLng(1.314967973664341, 103.765121458707);

  ///////////////////////////////////////////////////////////////
  // All the Bus Routes

  final List<LatLng> AM_KAP = [
    KAP, // TODO: currently set to OPPKAP instead of KAP??
    UTURN,
    ENT,
    MAP,
  ];
  final List<LatLng> AM_CLE = [CLE, ENT, MAP];
  final List<LatLng> PM_KAP = [
    ENT,
    B23,
    SPH,
    SIT,
    B44,
    B37,
    Between_B37_MAP,
    MAP,
    //TODO: something wrong with MAP to HSC??? need to check
    HSC,
    Between_HSC_LCT,
    LCT,
    B72,
    OPP_KAP,
  ];
  final List<LatLng> PM_CLE = [
    ENT,
    B23,
    SPH,
    SIT,
    B44,
    B37,
    Between_B37_MAP,
    MAP,
    //TODO: something wrong with MAP to HSC??? need to check
    HSC,
    Between_HSC_LCT,
    LCT,
    B72,
    CLE_UTURN,
    CLE_A,
  ];

  ///////////////////////////////////////////////////////////////
  // initState

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init(); // run everything in order
  }

  Future<void> _init() async {
    await _loadInitialData(); // wait for preferences to load
    _getLocation(); // now safe to run
    _mqttConnect.createState().initState();
    _bindMQTTListeners();
  }

  Future<void> _loadInitialData() async {
    final prefsService = SharedPreferenceService();

    // Run all async loads in parallel
    final results = await Future.wait([
      prefsService.getBookingData(), // index 0
      loadDarkMode(), // index 1
      loadBusIndex(), // index 2
    ]);

    final bookingData = results[0] as Map<String, dynamic>?;
    final dark = results[1] as bool;
    final busIndexLoad = results[2] as int?;

    setState(() {
      // Load booking data first
      if (bookingData != null && bookingData.containsKey('selectedBox')) {
        selectedBox = bookingData['selectedBox'];
      } else {
        selectedBox = 0; // default if no booking
      }

      // Load bus index if not set by booking
      if (busIndexLoad != null) {
        busIndex = busIndexLoad;
      } else if (busIndexLoad == null) {
        busIndex = 0; // safe default
      }

      // Load dark mode preference
      isDarkMode = dark;
    });

    // Apply selected box logic after state is set
    updateSelectedBox(selectedBox);
  }

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkMode') ?? false;
  }

  Future<int?> loadBusIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('busIndex'); // returns null if not set
  }

  ///////////////////////////////////////////////////////////////
  // MQTT bindings for all 3 buses using the new MQTT_Connect.buses structure

  void _bindMQTTListeners() {
    // Generic binder for any ValueNotifier
    void bind<T>(ValueNotifier<T> notifier, void Function(T) update) {
      notifier.addListener(() => setState(() => update(notifier.value)));
    }

    // Loop through each bus in the buses map
    MQTT_Connect.buses.forEach((busId, busData) {
      bind(busData.location, (v) {
        if (busId == 1) Bus1_Location = v;
        if (busId == 2) Bus2_Location = v;
        if (busId == 3) Bus3_Location = v;
      });

      bind(busData.speed, (v) {
        if (busId == 1) Bus1_Speed = v;
        if (busId == 2) Bus2_Speed = v;
        if (busId == 3) Bus3_Speed = v;
      });

      bind(busData.time, (v) {
        if (busId == 1) Bus1_Time = v;
        if (busId == 2) Bus2_Time = v;
        if (busId == 3) Bus3_Time = v;
      });

      bind(busData.stop, (v) {
        if (busId == 1) Bus1_Stop = v;
        if (busId == 2) Bus2_Stop = v;

        if (busId == 3) Bus3_Stop = v;
      });

      bind(busData.eta, (v) {
        if (busId == 1) Bus1_ETA = v;
        if (busId == 2) Bus2_ETA = v;
        if (busId == 3) Bus3_ETA = v;
      });

      bind(busData.count, (v) {
        if (busId == 1) Bus1_Count = v;
        if (busId == 2) Bus2_Count = v;
        if (busId == 3) Bus3_Count = v;
      });
    });
  }

  ///////////////////////////////////////////////////////////////
  // function to acquire location of user

  void _getLocation() {
    // initial location fetch
    _locationService.getCurrentLocation().then((location) {
      setState(() => currentLocation = location);
    });
    // Set up periodic location updates (every 1 second)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _locationService.getCurrentLocation().then((location) {
        setState(() => currentLocation = location);
      });
    });
    // Compass heading updates (direction user faces)
    _locationService.initCompass((heading) {
      setState(() => _heading = heading);
    });
  }

  ///////////////////////////////////////////////////////////////
  // toggle Dark mode

  void _toggleTheme(bool value) => setState(() => isDarkMode = value);

  ///////////////////////////////////////////////////////////////
  // checks which MRT Station is selected by user (KAP or CLE),
  // the Time (am or pm) and then loads the corresponding Routes

  void updateSelectedBox(int selectedBox) {
    setState(() {
      this.selectedBox = selectedBox;
      if (selectedBox == 1) {
        fetchRoute(now.hour > startAfternoonService ? PM_KAP : AM_KAP);
      } else if (selectedBox == 2) {
        fetchRoute(now.hour > startAfternoonService ? PM_CLE : AM_CLE);
      } else {
        routePoints.clear();
      }
    });
  }

  ///////////////////////////////////////////////////////////////
  // function to be able to draw the route on the map

  Future<void> fetchRoute(List<LatLng> waypoints) async {
    // reformatting into String so one can use for osrm
    String waypointsStr = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    // get a route from osrm (for driving since bus)
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/$waypointsStr?overview=simplified&steps=true&continue_straight=true',
    );
    final response = await http.get(url);
    // checks for route
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        //only if there is a route, then decodes it into LatLng and draws it on map
        final encodedPolyline = data['routes'][0]['geometry'];
        final points = PolylinePoints.decodePolyline(encodedPolyline);
        setState(() {
          routePoints
            ..clear()
            ..addAll(points.map((p) => LatLng(p.latitude, p.longitude)));
        });
      }
    }
  }

  ///////////////////////////////////////////////////////////////
  // Function to be able to create Bus marker on map more easily

  Marker _buildBusMarker(
    String label,
    LatLng? location,
    ResponsiveConfig config,
  ) {
    return Marker(
      point: location ?? LatLng(1.3323127398440282, 103.774728443874),
      child: SizedBox(
        width: config.iconSize * 2,
        height: config.iconSize * 2.4,
        child: FittedBox(
          // Scales down contents to avoid overflow
          fit: BoxFit.contain,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: config.isTablet ? 10 : 8,
                  color: getBusMarkerColor(label, selectedBox, isDarkMode),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 0.5),

              Icon(
                Icons.directions_bus,
                color: getBusMarkerColor(label, selectedBox, isDarkMode),
                size: config.busIconSize * 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ///////////////////////////////////////////////////////////////
  // Function to be able to easily create Bus stops on Map
  // instead of having to do them all separately

  Marker _buildStopMarker(
    LatLng point,
    String title,
    String description,
    bool isDarkMode,
    ResponsiveConfig config,
  ) {
    return Marker(
      point: point,
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: Text(
              description,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.tealAccent
                        : const Color(0xff014689),
                  ),
                ),
              ),
            ],
          ),
        ),
        child: Transform.flip(
          flipY: true,
          child: Icon(
            CupertinoIcons.location_circle_fill,
            color: getMarkerColor(title, busIndex, isDarkMode),
            size: config.iconSize,
          ),
        ),
      ),
    );
  }

  ///////////////////////////////////////////////////////////////
  // Build the map with all stops, routes and buses

  Widget _buildMap() {
    final config = ResponsiveConfig(context);
    final mapCenter =
        currentLocation ?? LatLng(1.3331191965635956, 103.7765424614437);

    return FlutterMap(
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: config.isTablet ? 17 : 18,
        initialRotation: 0,
        interactionOptions: const InteractionOptions(
          flags: ~InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        Container(
          color: isDarkMode ? Colors.black87 : Colors.lightBlueAccent[50],
          child: TileLayer(
            keepBuffer: 4,
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.fleaflet.flutter_map.example',
            tileBuilder: isDarkMode
                ? (context, widget, tile) => ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -1,
                      0,
                      0,
                      0,
                      100,
                      0,
                      -1,
                      0,
                      0,
                      245,
                      0,
                      0,
                      -1,
                      0,
                      250,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: widget,
                  )
                : null,
          ),
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: isDarkMode ? Colors.cyan : Colors.blue[600]!,
                strokeWidth: 5,
                pattern: StrokePattern.dashed(
                  segments: [1, 7],
                  patternFit: PatternFit.scaleUp,
                ),
              ),
            ],
          ),
        MarkerLayer(
          rotate: true,
          markers: [
            _buildStopMarker(
              ENT,
              'ENT',
              'Entrance Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(OPP_KAP, 'Opposite KAP', ' ', isDarkMode, config),
            _buildStopMarker(
              B23,
              'B23',
              'Block 23 Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              SPH,
              'SPH',
              'Sports Hall Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              B44,
              'B44',
              'Block 44 Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              B37,
              'B37',
              'Block 37 Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              B72,
              'B72',
              'Block 72 Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              MAP,
              'MAP',
              'Makan Place Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              CLE,
              'CLE',
              'Clementi MRT Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              KAP,
              'KAP',
              'King Albert Park\nMRT Bus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              HSC,
              'HSC',
              'School of Health Sciences\nBus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              LCT,
              'LCT',
              'School of Life Sciences & Technology\nBus Stop',
              isDarkMode,
              config,
            ),
            _buildStopMarker(
              SIT,
              'SIT',
              'Singapore Institute of Technology\nBus Stop',
              isDarkMode,
              config,
            ),
            _buildBusMarker('Bus1', Bus1_Location, config),
            _buildBusMarker('Bus2', Bus2_Location, config),
            _buildBusMarker('Bus3', Bus3_Location, config),
          ],
        ),
        MarkerLayer(
          rotate: false,
          markers: [
            if (currentLocation != null)
              Marker(
                point: currentLocation!,
                child: CustomPaint(
                  size: Size(config.iconSize * 3, config.iconSize * 2),
                  painter: CompassPainter(
                    direction: _heading,
                    arcSweepAngle: 360,
                    arcStartAngle: 0,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  ///////////////////////////////////////////////////////////////
  // the circular menu at the top right

  Widget _buildCircularMenu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30.0, 10.0, 0),
      child: CircularMenu(
        alignment: Alignment.topRight,
        radius: 80.0,
        toggleButtonSize: 55,
        toggleButtonColor: isDarkMode
            ? Colors.blueGrey[500]
            : const Color(0xff014689),
        toggleButtonIconColor: Colors.white,
        curve: Curves.easeInOut,
        items: [
          CircularMenuItem(
            color: Colors.cyan,
            iconSize: 30.0,
            margin: 10.0,
            padding: 10.0,
            icon: Icons.info_rounded,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InformationPage(isDarkMode: isDarkMode),
              ),
            ),
          ),
          CircularMenuItem(
            color: Colors.green[300],
            iconSize: 30.0,
            margin: 10.0,
            padding: 10.0,
            icon: Icons.settings,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Settings(
                  isDarkMode: isDarkMode,
                  onThemeChanged: _toggleTheme,
                ),
              ),
            ),
          ),
          CircularMenuItem(
            color: Color(0xfffeb041),
            iconSize: 30.0,
            margin: 10.0,
            padding: 10.0,
            icon: Icons.newspaper,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsAnnouncement(isDarkMode: isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ///////////////////////////////////////////////////////////////
  // The panel at the bottom

  ScrollController? _panelScrollController;
  final PanelController _panelController = PanelController();

  Widget _buildSlidingPanel(Widget displayPage) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Wrapping the panel in a Stack so we can place a tap overlay above it
    return Stack(
      children: [
        SlidingUpPanel(
          controller: _panelController, // wire controller
          minHeight: 100,
          maxHeight: screenHeight * 0.65,
          backdropEnabled: true, // dim background
          backdropOpacity: 0.5, // adjust darkness
          backdropTapClosesPanel: true, // tap outside to close
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          color: isDarkMode ? Colors.blueGrey[900]! : Colors.lightBlue[50]!,
          onPanelOpened: () => setState(() => ignoring = true),
          onPanelClosed: () {
            setState(() => ignoring = false);
            // Reset scroll position when panel closes
            if (_panelScrollController != null) {
              _panelScrollController!.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          panelBuilder: (controller) {
            // Store the controller so we can use it in onPanelClosed
            _panelScrollController = controller;

            return SafeArea(
              top: false,
              child: Column(
                children: [
                  // Header section with different background
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blueGrey[700]
                          : const Color(0xff014689), // header color
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Grab handle
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            width: 40,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Title row with bus icon
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MooBus on-demand',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveConfig(context).isTablet
                                      ? 20
                                      : 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main body section
                  Expanded(
                    child: Container(
                      color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            displayPage,
                            const SizedBox(height: 16),
                            NewsAnnouncementWidget(isDarkMode: isDarkMode),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ===== TAP OVERLAY (unchanged) =====
        if (!ignoring)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _panelController.open();
              },
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }

  ///////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Decide which screen to show based on the current hour
    final bool isAfternoon = now.hour >= startAfternoonService;

    Widget displayPage = SingleChildScrollView(
      child: isAfternoon
          ? AfternoonScreen(
              updateSelectedBox: updateSelectedBox,
              isDarkMode: isDarkMode,
            )
          : MorningScreen(
              updateSelectedBox: updateSelectedBox,
              isDarkMode: isDarkMode,
            ),
    );

    ///////////////////////////////////////////////////////////////

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildCircularMenu(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 40.0, 0.0, 0),
            child: Align(
              alignment: Alignment.topLeft,
              child: ClipOval(
                child: Image.asset(
                  'images/logo.jpeg',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          _buildSlidingPanel(displayPage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
