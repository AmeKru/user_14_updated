import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/screens/afternoon_screen.dart';
import 'package:user_14_updated/screens/announcements_page.dart';
import 'package:user_14_updated/screens/information_page.dart';
import 'package:user_14_updated/screens/morning_screen.dart';
import 'package:user_14_updated/screens/settings_page.dart';
import 'package:user_14_updated/services/get_location.dart';
import 'package:user_14_updated/services/mqtt.dart';
import 'package:user_14_updated/services/shared_preference.dart';
import 'package:user_14_updated/utils/marker_colour.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

///////////////////////////////////////////////////////////////
// Map Page

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
  DateTime now = DateTime.now();

  // Bus1 data
  LatLng? bus1Location;
  String? bus1Time;
  double? bus1Speed;
  String? bus1Stop;
  String? bus1ETA;
  int? bus1Count;

  // Bus2 data
  LatLng? bus2Location;
  String? bus2Time;
  double? bus2Speed;
  String? bus2Stop;
  String? bus2ETA;
  int? bus2Count;

  // Bus3 data
  LatLng? bus3Location;
  String? bus3Time;
  double? bus3Speed;
  String? bus3Stop;
  String? bus3ETA;
  int? bus3Count;

  ///////////////////////////////////////////////////////////////
  // Location and mqtt service

  final LocationService _locationService = LocationService();
  final ConnectMQTT _mqttConnect = ConnectMQTT();

  ///////////////////////////////////////////////////////////////
  // Stops, needed to be static const so later can just use defined names in Routes

  static const LatLng busStopENT = LatLng(
    1.3329143792222058,
    103.77742909276205,
  );
  static const LatLng busStopCLE = LatLng(1.313434, 103.765811);
  static const LatLng busStopCLEa = LatLng(1.314967973664341, 103.765121458707);
  static const LatLng busStopKAP = LatLng(1.335844, 103.783160);
  static const LatLng busStopOppositeKAP = LatLng(1.336274, 103.783146);
  static const LatLng busStopB23 = LatLng(1.333801, 103.775738);
  static const LatLng busStopSPH = LatLng(1.335110, 103.775464);
  static const LatLng busStopSIT = LatLng(1.334510, 103.774504);
  static const LatLng busStopB44 = LatLng(
    1.3329522845882348,
    103.77145520892851,
  );
  static const LatLng busStopB37 = LatLng(1.332797, 103.773304);
  static const LatLng busStopMAP = LatLng(1.332473, 103.774377);
  static const LatLng busStopHSC = LatLng(1.330028, 103.774623);
  static const LatLng busStopLCT = LatLng(1.330895, 103.774870);
  static const LatLng busStopB72 = LatLng(
    1.3314596165361228,
    103.7761976140868,
  );
  // others
  static const LatLng uTurn = LatLng(1.326394, 103.775705);
  static const LatLng betweenHSCAndLCT = LatLng(
    1.3307778258080973,
    103.77543148160284,
  );
  static const LatLng betweenB37AndMAP = LatLng(
    1.3325776073001032,
    103.77438270405088,
  );
  static const LatLng uTurnCLE = LatLng(1.314967973664341, 103.765121458707);

  ///////////////////////////////////////////////////////////////
  // All the Bus Routes

  final List<LatLng> amKAP = [busStopKAP, uTurn, busStopENT, busStopMAP];
  final List<LatLng> amCLE = [busStopCLE, busStopENT, busStopMAP];
  final List<LatLng> pmKAP = [
    busStopENT,
    busStopB23,
    busStopSPH,
    busStopSIT,
    busStopB44,
    busStopB37,
    betweenB37AndMAP,
    busStopMAP,
    busStopHSC,
    betweenHSCAndLCT,
    busStopLCT,
    busStopB72,
    busStopOppositeKAP,
  ];
  final List<LatLng> pmCLE = [
    busStopENT,
    busStopB23,
    busStopSPH,
    busStopSIT,
    busStopB44,
    busStopB37,
    betweenB37AndMAP,
    busStopMAP,
    busStopHSC,
    betweenHSCAndLCT,
    busStopLCT,
    busStopB72,
    uTurnCLE,
    busStopCLEa,
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

    // getBookingData returns Map<String, dynamic>? so await it directly
    final Map<String, dynamic>? bookingData = await prefsService
        .getBookingData();

    // Wait for timeNow to be initialized, but avoid waiting forever
    Future<void> waitForTimeNow({
      Duration timeout = const Duration(seconds: 5),
    }) async {
      final end = DateTime.now().add(timeout);
      while (timeNow == null && DateTime.now().isBefore(end)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    await waitForTimeNow();

    // Snapshot timeNow once
    final now = timeNow;
    final bool isAfternoonReady =
        now != null && now.hour >= startAfternoonService;

    // Compute selectedBox safely from bookingData
    int selectedBoxComputed = 0;
    if (isAfternoonReady && bookingData != null) {
      final dynamic sb = bookingData['selectedBox'];
      if (sb is int) {
        selectedBoxComputed = sb;
      } else if (sb is String) {
        selectedBoxComputed = int.tryParse(sb) ?? 0;
      }
    }

    // Compute busIndex safely
    final int busIndexComputed = (bookingData != null && isAfternoonReady)
        ? bookingData['busIndex']
        : 0;

    // Update state once
    if (!mounted) return;
    setState(() {
      selectedBox = selectedBoxComputed;
      busIndex = busIndexComputed;
    });

    // Apply side-effects after state update
    updateSelectedBox(selectedBox);
  }

  ///////////////////////////////////////////////////////////////
  // MQTT bindings for all 3 buses using the new MQTT_Connect.buses structure

  void _bindMQTTListeners() {
    // Generic binder for any ValueNotifier
    void bind<T>(ValueNotifier<T> notifier, void Function(T) update) {
      notifier.addListener(() => setState(() => update(notifier.value)));
    }

    // Loop through each bus in the buses map
    ConnectMQTT.buses.forEach((busId, busData) {
      bind(busData.location, (v) {
        if (busId == 1) bus1Location = v;
        if (busId == 2) bus2Location = v;
        if (busId == 3) bus3Location = v;
      });

      bind(busData.speed, (v) {
        if (busId == 1) bus1Speed = v;
        if (busId == 2) bus2Speed = v;
        if (busId == 3) bus3Speed = v;
      });

      bind(busData.time, (v) {
        if (busId == 1) bus1Time = v;
        if (busId == 2) bus2Time = v;
        if (busId == 3) bus3Time = v;
      });

      bind(busData.stop, (v) {
        if (busId == 1) bus1Stop = v;
        if (busId == 2) bus2Stop = v;

        if (busId == 3) bus3Stop = v;
      });

      bind(busData.eta, (v) {
        if (busId == 1) bus1ETA = v;
        if (busId == 2) bus2ETA = v;
        if (busId == 3) bus3ETA = v;
      });

      bind(busData.count, (v) {
        if (busId == 1) bus1Count = v;
        if (busId == 2) bus2Count = v;
        if (busId == 3) bus3Count = v;
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
    now =
        DateTime.now(); // update current time now, so that routes will be shown correctly
    setState(() {
      this.selectedBox = selectedBox;
      if (selectedBox == 1) {
        selectedMRT = 1;
        fetchRoute(now.hour >= startAfternoonService ? pmKAP : amKAP);
      } else if (selectedBox == 2) {
        selectedMRT = 2;
        fetchRoute(now.hour >= startAfternoonService ? pmCLE : amCLE);
      } else {
        routePoints.clear();
        selectedMRT = 0;
        busIndex = 0;
      }
    });
    if (kDebugMode) {
      print(
        'updated selectedBox to $selectedBox - time now hour: ${now.hour} ',
      );
    }
  }

  ///////////////////////////////////////////////////////////////
  // function to be able to draw the route on the map

  Future<void> fetchRoute(List<LatLng> waypoints) async {
    // Debug print to check if it works as it should
    if (kDebugMode) {
      print('fetching route $waypoints');
    }
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

  Marker _buildBusMarker(String label, LatLng? location) {
    final double iconSize = TextSizing.fontSizeText(context) * 2;

    return Marker(
      point: location ?? LatLng(1.3323127398440282, 103.774728443874),
      width: iconSize, //  define marker bounds
      height: iconSize,
      alignment: Alignment.center, //  anchor the LatLng to the center
      child: Stack(
        fit: StackFit.expand, // children share the same bounds
        alignment: Alignment.topCenter,
        children: [
          Icon(
            Icons.directions_bus_filled,
            size: iconSize,
            color: isDarkMode ? Colors.black : Colors.white,
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  TextSizing.fontSizeMiniText(context) * 0.1,
                  TextSizing.fontSizeMiniText(context) * 0.1,
                  TextSizing.fontSizeMiniText(context) * 0.1,
                  TextSizing.fontSizeMiniText(context),
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeMiniText(context) * 0.6,
                    fontFamily: 'Roboto',
                    color: getBusMarkerColor(label, selectedBox),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Icon(
            Icons.directions_bus,
            size: iconSize,
            color: getBusMarkerColor(label, selectedBox),
          ),
        ],
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
  ) {
    return Marker(
      point: point,
      width: TextSizing.fontSizeText(context),
      height: TextSizing.fontSizeText(context),
      alignment: Alignment
          .topCenter, // if one wants the tip of arrow pointing to the stop
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
                fontSize: TextSizing.fontSizeHeading(context),
              ),
            ),
            content: Text(
              description,
              softWrap: true,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: TextSizing.fontSizeText(context),
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  maxLines: 1, //  limits to 1 lines
                  overflow: TextOverflow.ellipsis, // clips text if not fitting
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.tealAccent
                        : const Color(0xff014689),
                    fontSize: TextSizing.fontSizeText(context),
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Transform.flip(
              flipY: true,
              child: Icon(
                CupertinoIcons.circle_fill,
                color: isDarkMode ? Colors.black : Colors.white,
                size: TextSizing.fontSizeText(context) * 1.75,
              ),
            ),
            Transform.flip(
              flipY: true,
              child: Icon(
                CupertinoIcons.location_circle_fill,
                color: getMarkerColor(title, busIndex),
                size: TextSizing.fontSizeText(context) * 1.75,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ///////////////////////////////////////////////////////////////
  // Build the map with all stops, routes and buses

  Widget _buildMap() {
    final mapCenter =
        currentLocation ?? LatLng(1.3331191965635956, 103.7765424614437);

    return FlutterMap(
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: 16,
        initialRotation: 0,
        interactionOptions: const InteractionOptions(
          flags: ~InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        Container(
          color: isDarkMode ? Colors.black : Colors.lightBlueAccent[50],
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.fleaflet.flutter_map.example',
            keepBuffer: 4,
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
                color: isDarkMode ? Colors.cyan : Colors.lightBlue[800]!,
                strokeWidth: TextSizing.fontSizeText(context) * 0.25,
                pattern: StrokePattern.dashed(
                  segments: [
                    TextSizing.fontSizeText(context) * 0.01,
                    TextSizing.fontSizeText(context) * 0.3,
                  ],
                  patternFit: PatternFit.scaleUp,
                ),
              ),
            ],
          ),
        MarkerLayer(
          rotate: true,
          markers: [
            _buildStopMarker(
              busStopENT,
              'ENT',
              'Entrance Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopOppositeKAP,
              'OPP KAP',
              'Opposite King Albert Park',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopB23,
              'B23',
              'Block 23 Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopSPH,
              'SPH',
              'Sports Hall Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopB44,
              'B44',
              'Block 44 Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopB37,
              'B37',
              'Block 37 Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopB72,
              'B72',
              'Block 72 Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopMAP,
              'MAP',
              'Makan Place Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopCLE,
              'CLE',
              'Clementi MRT Bus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopKAP,
              'KAP',
              'King Albert Park MRT\nBus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopHSC,
              'HSC',
              'School of Health Sciences\nBus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopLCT,
              'LCT',
              'School of Life Sciences & Technology\nBus Stop',
              isDarkMode,
            ),
            _buildStopMarker(
              busStopSIT,
              'SIT',
              'Singapore Institute of Technology\nBus Stop',
              isDarkMode,
            ),
            _buildBusMarker('Bus1', bus1Location),
            _buildBusMarker('Bus2', bus2Location),
            _buildBusMarker('Bus3', bus3Location),
          ],
        ),
        MarkerLayer(
          rotate: false,
          markers: [
            if (currentLocation != null)
              Marker(
                point: currentLocation!,
                child: CustomPaint(
                  size: Size(
                    TextSizing.fontSizeText(context),
                    TextSizing.fontSizeText(context),
                  ),
                  painter: CompassPainter(
                    direction: _heading,
                    arcSweepAngle: 360,
                    arcStartAngle: 0,
                    context: context,
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
      padding: EdgeInsets.fromLTRB(
        0,
        TextSizing.fontSizeText(context) * 2,
        TextSizing.fontSizeText(context) * 0.5,
        0,
      ),

      // Circular Menu button
      child: CircularMenu(
        alignment: Alignment.topRight,
        radius: TextSizing.fontSizeText(context) * 4.75,
        toggleButtonSize: TextSizing.fontSizeText(context) * 3.5,
        toggleButtonColor: isDarkMode
            ? Colors.blueGrey[500]
            : const Color(0xff014689),
        toggleButtonIconColor: Colors.white,
        curve: Curves.easeInOut,
        items: [
          // Information Page button
          CircularMenuItem(
            color: isDarkMode ? Colors.cyan : Colors.cyan[600],
            iconSize: TextSizing.fontSizeText(context) * 2.25,
            margin: TextSizing.fontSizeText(context),
            padding: TextSizing.fontSizeText(context) * 0.5,
            icon: Icons.info_rounded,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InformationPage()),
            ),
          ),

          // Settings Page button
          CircularMenuItem(
            color: isDarkMode ? Colors.green[300] : Colors.green,
            iconSize: TextSizing.fontSizeText(context) * 2.25,
            margin: TextSizing.fontSizeText(context),
            padding: TextSizing.fontSizeText(context) * 0.5,
            icon: Icons.settings,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Settings(onThemeChanged: _toggleTheme),
              ),
            ),
          ),

          // Announcement Page button
          CircularMenuItem(
            color: Color(0xfffeb041),
            iconSize: TextSizing.fontSizeText(context) * 2.25,
            margin: TextSizing.fontSizeText(context),
            padding: TextSizing.fontSizeText(context) * 0.5,
            icon: Icons.newspaper_rounded,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewsAnnouncement()),
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
          minHeight: Platform.isAndroid
              ? TextSizing.fontSizeHeading(context) * 4.6
              : TextSizing.fontSizeHeading(context) * 4.2,
          maxHeight: screenHeight * 0.75,
          backdropEnabled: true, // dim background
          backdropOpacity: 0.5, // adjust darkness
          backdropTapClosesPanel: true, // tap outside to close
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TextSizing.fontSizeText(context)),
          ),
          color: isDarkMode ? Colors.blueGrey[900]! : Colors.lightBlue[50]!,
          onPanelOpened: () {
            setState(() => ignoring = true);
          },
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
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(TextSizing.fontSizeText(context)),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Grab handle
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: TextSizing.fontSizeText(context) * 0.5,
                          ),
                          child: Container(
                            width: TextSizing.fontSizeText(context) * 3,
                            height: TextSizing.fontSizeText(context) * 0.2,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(
                                TextSizing.fontSizeText(context),
                              ),
                            ),
                          ),
                        ),
                        // Title row with bus icon
                        Padding(
                          padding: EdgeInsets.all(
                            TextSizing.fontSizeText(context) * 0.5,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: TextSizing.fontSizeHeading(context),
                              ),
                              SizedBox(
                                width: TextSizing.fontSizeText(context) * 0.5,
                              ),
                              Flexible(
                                child: Text(
                                  'MooBus on-demand',
                                  maxLines:
                                      1, // or more if you want multiple lines
                                  overflow: TextOverflow
                                      .ellipsis, // options: clip, ellipsis, fade
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: TextSizing.fontSizeHeading(
                                      context,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Montserrat',
                                  ),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            displayPage,
                            SizedBox(height: TextSizing.fontSizeText(context)),
                            NewsAnnouncementWidget(),
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

        // ===== TAP OVERLAY  =====
        if (!ignoring)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: TextSizing.fontSizeHeading(context) * 3.5,
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

    Widget displayPage = isAfternoon
        ? AfternoonScreen(updateSelectedBox: updateSelectedBox)
        : MorningScreen(updateSelectedBox: updateSelectedBox);

    ///////////////////////////////////////////////////////////////

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildCircularMenu(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              TextSizing.fontSizeText(context),
              TextSizing.fontSizeText(context) * 2.5,
              0,
              0,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: ClipOval(
                child: Image.asset(
                  'images/np_logo.png',
                  width: TextSizing.fontSizeHeading(context) * 2.75,
                  height: TextSizing.fontSizeHeading(context) * 2.75,
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
