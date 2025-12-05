import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../data/global.dart';
import '../screens/afternoon_screen.dart';
import '../screens/announcements_page.dart';
import '../screens/information_page.dart';
import '../screens/morning_screen.dart';
import '../screens/settings_page.dart';
import '../services/get_location.dart';
import '../services/mqtt.dart';
import '../services/shared_preference.dart';
import '../utils/get_time.dart';
import '../utils/loading.dart';
import '../utils/marker_colour.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Map Page ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// MapPage class
// the 'main page', shows the map and stuff on it, and all the menus,
// logo and screens through sliding panel at the bottom

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  // selected MRT but as local variable
  int selectedBox = 0;

  // to save current user location
  LatLng? currentLocation;

  // Timer to update location every defined interval
  Timer? _timer;

  // for route; ValueNotifier used as it will rebuild only route if route is reassigned
  ValueNotifier<List<LatLng>> routePoints = ValueNotifier<List<LatLng>>([]);

  // same as route but for getLocation
  final ValueNotifier<LatLng?> currentLocationNotifier = ValueNotifier(null);
  final ValueNotifier<double?> headingNotifier = ValueNotifier(null);

  // used to determine what route to show etc.
  DateTime now = DateTime.now();

  // needed to gate updateSelectedBox and prevent too many interactions at once
  bool _tapLocked = false;

  // to check which page is to be shown in sliding panel
  bool? lastCheckIsAfternoon; // to check if page is to be reassigned
  bool isAfternoon = false; // if it is afternoon
  bool isSwitching =
      false; // when switching between morning/afternoon to prevent flicker
  int oldSelectedBox = 0; // to check box that was selected before
  Widget displayPage = LoadingScreen();

  // for circularMenu so that one can close it when panel is open
  final GlobalKey<CircularMenuState> menuKey = GlobalKey<CircularMenuState>();

  // for Sliding Panel
  ScrollController? _panelScrollController;
  final PanelController _panelController = PanelController();
  final ValueNotifier<bool> _isPanelOpen = ValueNotifier(false);

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

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

  // Location and mqtt service
  final LocationService _locationService = LocationService();
  final ConnectMQTT _mqttConnect = ConnectMQTT();

  // All the bus stops
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

  // other necessary points for correct routing
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

  //////////////////////////////////////////////////////////////////////////////
  // initState

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init(); // run everything in order
  }

  //////////////////////////////////////////////////////////////////////////////
  // called at start after initState (cannot access context in initState)
  // to assign necessary variables

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  //////////////////////////////////////////////////////////////////////////////
  // dispose to remove listeners and stop timers when widget gets deleted

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- loading initial data ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // function to load async data in order and at start in initState

  Future<void> _init() async {
    await _loadInitialData(); // wait for preferences to load
    _getLocation(); // now safe to run
    _mqttConnect.createState().initState();
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to load data and check for saved booking

  Future<void> _loadInitialData() async {
    if (kDebugMode) {
      print('_loadInitialData called');
    }
    final prefsService = SharedPreferenceService();

    // getBookingData returns Map<String, dynamic>? so await it directly
    final Map<String, dynamic>? bookingData = await prefsService
        .getBookingData();

    if (bookingData != null) {
      final TimeService timeService = TimeService();
      await timeService.getTime();

      if (kDebugMode) {
        print('TimeNow: $timeNow');
      }

      // Snapshot timeNow once
      final now = timeNow;
      final bool isAfternoonReady =
          now != null && now.hour >= startAfternoonService;

      if (kDebugMode) {
        print('isAfternoonReady = $isAfternoonReady');
      }

      // Compute selectedBox safely from bookingData
      int selectedBoxComputed = 0;
      if (isAfternoonReady) {
        final dynamic sb = bookingData['selectedBox'];
        if (sb is int) {
          selectedBoxComputed = sb;
          if (kDebugMode) {
            print('selectedBoxComputed was int and = $sb');
          }
        } else if (sb is String) {
          selectedBoxComputed = int.tryParse(sb) ?? 0;
          if (kDebugMode) {
            print('selectedBoxComputed was not an int and = $sb');
          }
        }
      }

      selectedBox = selectedBoxComputed;

      // Compute busIndex safely
      final int busIndexComputed = (isAfternoonReady)
          ? bookingData['busIndex']
          : 0;

      busIndex.value = busIndexComputed;
    }

    // Update state once
    if (!mounted) {
      return;
    }
    if (selectedBox == 0) {
      if (kDebugMode) {
        print('no booking was loaded, no initial states to be set');
      }
      pageToBeBuilt();
      updateSelectedBox(selectedBox);
      return;
    }
    if (kDebugMode) {
      print(
        'booking was loaded, with selectedBox $selectedBox and busIndex ${busIndex.value}',
      );
    }

    if (kDebugMode) {
      print('initial data load, booking existed so setting state');
    }

    // so UI updates accordingly?
    setState(() {
      selectedMRT = selectedBox;
    });

    // Apply side-effects after state update
    updateSelectedBox(selectedBox);
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Dark Mode ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // toggle Dark mode

  void _toggleTheme(bool value) {
    if (kDebugMode) {
      print('_toggleTheme called');
    }
    if (!mounted) return;
    setState(() => isDarkMode = value);
    lastCheckIsAfternoon = null;
    pageToBeBuilt();
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Update Selected Box and check which page is to be shown ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // checks which MRT Station is selected by user (KAP or CLE),
  // the Time (am or pm) and then loads the corresponding Routes

  Future<void> updateSelectedBox(int newBox) async {
    if (!mounted) return;
    if (_tapLocked) return;
    _tapLocked = true;

    if (kDebugMode) {
      print('updateSelectedBox called in map_page with newBox $newBox');
    }

    selectedBox = newBox;
    if (newBox == 1) {
      selectedMRT = 1;
    } else if (newBox == 2) {
      selectedMRT = 2;
    } else {
      routePoints.value = [];
      selectedMRT = 0;
      busIndex.value = 0;
    }

    // gets time now
    final TimeService timeService = TimeService();

    try {
      await timeService.getTime().timeout(
        const Duration(milliseconds: 100),
      ); // max wait 100ms
      now = timeNow ?? DateTime.now();
    } on TimeoutException {
      if (kDebugMode) {
        print(
          'getTime took too long (>100ms) - will fallback to device singaporean time',
        );
      }
      // Get the current device time
      DateTime localTime = DateTime.now();
      // Convert local time to UTC
      DateTime utcTime = localTime.toUtc();
      now = utcTime.add(Duration(hours: 8));
    }

    if (kDebugMode) {
      print('updateSelectedBox map_page now: $now');
    }

    // Checks if afternoon
    pageToBeBuilt();

    if (newBox == 1) {
      if (kDebugMode) {
        print('map_page fetching route for KAP');
      }
      await fetchRoute(now.hour >= startAfternoonService ? pmKAP : amKAP);
    } else if (newBox == 2) {
      if (kDebugMode) {
        print('map_page fetching route for CLE');
      }
      await fetchRoute(now.hour >= startAfternoonService ? pmCLE : amCLE);
    }
    _tapLocked = false;

    if (kDebugMode) {
      print('updated selectedBox to $newBox - time now hour: ${now.hour}');
    }
  }

  ///////////////////////////////////////////////////////////////
  // checks and assigns page that is shown in sliding panel

  void pageToBeBuilt() {
    // Decide which screen to show based on the current hour
    // only changes when isAfternoon changes
    isAfternoon = now.hour >= startAfternoonService;
    if (isAfternoon != lastCheckIsAfternoon) {
      if (kDebugMode) {
        print('map_page => checked and assigned a page to be built');
      }
      if (lastCheckIsAfternoon != null) {
        // only null when first loading and setting page
        // if switching between morning/afternoon
        if (!mounted) return;
        String loadingText = isAfternoon ? 'Afternoon' : 'Morning';
        setState(() {
          // show a loading screen in between switch
          selectedMRT = 0;
          updateSelectedBox(0);
          isSwitching = true;
          displayPage = Column(
            children: [
              Text(
                'Loading $loadingText Service...',
                style: TextStyle(
                  color: Colors.blueGrey[200],
                  fontSize: fontSizeText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
              LoadingScreen(),
            ],
          );
        });

        Future.delayed(const Duration(milliseconds: 500)).then((_) {
          if (!mounted) return;
          setState(() {
            // switch to the real page
            displayPage = isAfternoon
                ? AfternoonScreen(updateSelectedBox: updateSelectedBox)
                : MorningScreen(updateSelectedBox: updateSelectedBox);
            isSwitching = false;
          });
        });
      } else {
        // just sets page when first startup of app
        if (!mounted) return;
        setState(() {
          displayPage = isAfternoon
              ? AfternoonScreen(updateSelectedBox: updateSelectedBox)
              : MorningScreen(updateSelectedBox: updateSelectedBox);
        });
      }
      // remember last check to know if need to reassign
      lastCheckIsAfternoon = isAfternoon;
    }
    // Debug prints
    if (kDebugMode) {
      if (isAfternoon) {
        print('it is afternoon');
      } else {
        print('it is morning');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Functions for map and everything on it ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // function to acquire location of user

  void _getLocation() {
    if (kDebugMode) {
      print('_getLocation called');
    }

    // initial location fetch
    _locationService.getCurrentLocation().then((location) {
      currentLocationNotifier.value = location;
    });

    // periodic updates
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _locationService.getCurrentLocation().then((location) {
        currentLocationNotifier.value = location;
      });
    });

    // Compass heading updates (direction user faces)
    _locationService.initCompass((heading) {
      headingNotifier.value = heading;
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to be able to draw the route on the map

  Future<void> fetchRoute(List<LatLng> waypoints) async {
    if (kDebugMode) {
      print('fetchRoute called in map_page');
    }
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
        if (kDebugMode) {
          print('assigning new route to routePoints');
        }
        //only if there is a route, then decodes it into LatLng and draws it on map
        final encodedPolyline = data['routes'][0]['geometry'];
        final points = PolylinePoints.decodePolyline(encodedPolyline);
        routePoints.value = points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Function to be able to create Bus marker on map more easily

  Marker _buildBusMarker(String label, LatLng? location) {
    final double iconSize = fontSizeText * 2;

    return Marker(
      point: location ?? LatLng(1.3323127398440282, 103.774728443874),
      width: iconSize,
      //  define marker bounds
      height: iconSize,
      //  anchor the LatLng to the center
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
                  fontSizeMiniText * 0.1,
                  fontSizeMiniText * 0.1,
                  fontSizeMiniText * 0.1,
                  fontSizeMiniText,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withAlpha(150)
                          : Colors.white.withAlpha(50), // ~45% opacity
                      blurRadius: 5, // how soft the shadow is
                      spreadRadius: 1, // how far it extends
                    ),
                  ],
                ),

                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeMiniText * 0.6,
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

  //////////////////////////////////////////////////////////////////////////////
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
      width: fontSizeText,
      height: fontSizeText,
      alignment: Alignment.topCenter,
      // if one wants the tip of arrow pointing to the stop
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: isDarkMode ? Colors.blueGrey[800] : Colors.white,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: fontSizeHeading,
              ),
            ),
            content: Text(
              description,
              softWrap: true,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: fontSizeText,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  maxLines: 1,
                  //  limits to 1 lines
                  overflow: TextOverflow.ellipsis,
                  // clips text if not fitting
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.tealAccent
                        : const Color(0xff014689),
                    fontSize: fontSizeText,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withAlpha(150)
                    : Colors.black.withAlpha(100), // ~45% opacity
                blurRadius: isDarkMode ? 5 : 10, // how soft the shadow is
                spreadRadius: 1, // how far it extends
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Transform.flip(
                flipY: true,
                child: Icon(
                  CupertinoIcons.circle_fill,
                  color: isDarkMode ? Colors.black : Colors.white,
                  size: fontSizeText * 1.75,
                ),
              ),
              Transform.flip(
                flipY: true,
                child: Icon(
                  CupertinoIcons.location_circle_fill,
                  color: getMarkerColor(title, busIndex.value),
                  size: fontSizeText * 1.75,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // Build the map with all stops, routes and buses

  Widget _buildMap() {
    if (kDebugMode) {
      print('map_page => map built');
    }

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
                      -0.8, 0, 0, 0, 80, // R row
                      0, -0.8, 0, 0, 196, // G row
                      0, 0, -0.8, 0, 200, // B row
                      0, 0, 0, 1, 0, // A row
                    ]),
                    child: widget,
                  )
                : null,
          ),
        ),

        // so the map colours do not distract as much and one can see the route better
        if (!isDarkMode)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                color: const Color.fromRGBO(255, 255, 255, 0.1), // 10% opacity
              ),
            ),
          ),

        ValueListenableBuilder<List<LatLng>>(
          valueListenable: routePoints,
          builder: (context, points, child) {
            if (points.isEmpty) return const SizedBox.shrink();

            return PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: isDarkMode ? Colors.cyan : Colors.lightBlue[800]!,
                  strokeWidth: fontSizeText * 0.25,
                  pattern: StrokePattern.dashed(
                    segments: [fontSizeText * 0.01, fontSizeText * 0.3],
                    patternFit: PatternFit.scaleUp,
                  ),
                ),
              ],
            );
          },
        ),

        ValueListenableBuilder<int>(
          valueListenable: busIndex,
          builder: (context, value, child) {
            return MarkerLayer(
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
              ],
            );
          },
        ),

        // only necessary  markers will be rebuilt if changes in location
        ValueListenableBuilder<LatLng?>(
          valueListenable:
              ConnectMQTT.buses[1]!.location, // ValueNotifier<LatLng?>
          builder: (_, bus1LatLng, _) {
            bus1Location = bus1LatLng;
            if (bus1LatLng == null) {
              return const SizedBox.shrink(); // to hide bus if no location
            }
            return MarkerLayer(
              rotate: true,
              markers: [_buildBusMarker('Bus1', bus1Location)],
            );
          },
        ),

        ValueListenableBuilder<LatLng?>(
          valueListenable:
              ConnectMQTT.buses[2]!.location, // ValueNotifier<LatLng?>
          builder: (_, bus2LatLng, _) {
            bus2Location = bus2LatLng;
            if (bus2LatLng == null) {
              return const SizedBox.shrink(); // to hide bus if no location
            }
            return MarkerLayer(
              rotate: true,
              markers: [_buildBusMarker('Bus2', bus2LatLng)],
            );
          },
        ),

        ValueListenableBuilder<LatLng?>(
          valueListenable:
              ConnectMQTT.buses[3]!.location, // ValueNotifier<LatLng?>
          builder: (_, bus3LatLng, _) {
            bus3Location = bus3LatLng;
            if (bus3LatLng == null) {
              return const SizedBox.shrink(); // to hide bus if no location
            }
            return MarkerLayer(
              rotate: true,
              markers: [_buildBusMarker('Bus3', bus3LatLng)],
            );
          },
        ),

        AnimatedBuilder(
          animation: Listenable.merge([
            currentLocationNotifier,
            headingNotifier,
          ]),
          builder: (context, _) {
            final LatLng? location = currentLocationNotifier.value;
            final double? heading = headingNotifier.value;

            if (location == null || heading == null) {
              return const SizedBox.shrink();
            }

            return MarkerLayer(
              rotate: false,
              markers: [
                Marker(
                  point: location,
                  child: CustomPaint(
                    size: Size(fontSizeText, fontSizeText),
                    painter: CompassPainter(
                      direction: heading,
                      arcSweepAngle: 360,
                      arcStartAngle: 0,
                      fontSizeText: fontSizeText,
                      context: context,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Circular menu ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // the circular menu at the top right

  Widget _buildCircularMenu() {
    if (kDebugMode) {
      print('map_page => circular menu built');
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(0, fontSizeText * 0.5, fontSizeText, 0),

      // Circular Menu button
      child: CircularMenu(
        key: menuKey,
        toggleButtonBoxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withAlpha(100), // ~45% opacity
            blurRadius: 15, // how soft the shadow is
            spreadRadius: 2, // how far it extends
            offset: Offset(0, 0), // no offset = shadow all around
          ),
        ],
        toggleButtonMargin: 0,
        toggleButtonPadding: fontSizeMiniText,
        alignment: Alignment.topRight,
        radius: fontSizeText * 4.5,
        toggleButtonSize: fontSizeText * 3.75,
        toggleButtonColor: isDarkMode
            ? Colors.blueGrey[600]
            : const Color(0xff014689),
        toggleButtonIconColor: Colors.white,
        curve: Curves.easeInOut,
        items: [
          // Information Page button
          CircularMenuItem(
            color: isDarkMode ? Colors.cyan : Colors.cyan[600],
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withAlpha(100), // ~45% opacity
                blurRadius: 15, // how soft the shadow is
                spreadRadius: 2, // how far it extends
                offset: Offset(0, 0), // no offset = shadow all around
              ),
            ],
            iconSize: fontSizeText * 2.25,
            margin: fontSizeText,
            padding: fontSizeText * 0.5,
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
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withAlpha(100), // ~45% opacity
                blurRadius: 15, // how soft the shadow is
                spreadRadius: 2, // how far it extends
                offset: Offset(0, 0), // no offset = shadow all around
              ),
            ],
            iconSize: fontSizeText * 2.25,
            margin: fontSizeText,
            padding: fontSizeText * 0.5,
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
            color: const Color(0xfffeb041),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withAlpha(100), // ~45% opacity
                blurRadius: 15, // how soft the shadow is
                spreadRadius: 2, // how far it extends
                offset: Offset(0, 0), // no offset = shadow all around
              ),
            ],
            iconSize: fontSizeText * 2.25,
            margin: fontSizeText,
            padding: fontSizeText * 0.5,
            icon: Icons.newspaper_rounded,
            iconColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsAnnouncement(
                  fontSizeMiniText: fontSizeMiniText,
                  fontSizeText: fontSizeText,
                  fontSizeHeading: fontSizeHeading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- NP Logo  ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // the logo at the top left

  Widget _logoNP() {
    if (kDebugMode) {
      print('map_page => logo NP built');
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(fontSizeText, fontSizeText * 0.5, 0, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: fontSizeHeading * 2.9,
          height: fontSizeHeading * 2.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withAlpha(100), // ~45% opacity
                blurRadius: 15, // how soft the shadow is
                spreadRadius: 2, // how far it extends
                offset: Offset(0, 0), // no offset = shadow all around
              ),
            ],
          ),
          child: const ClipOval(
            child: Image(
              image: AssetImage('images/np_logo.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Main sliding panel  ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // The panel at the bottom

  Widget _buildSlidingPanel() {
    if (kDebugMode) {
      print('map_page => Sliding Panel built');
    }
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    double maxHeight = (TextSizing.isLandscapeMode(context)
        ? (TextSizing.isTablet(context)
              ? screenHeight * 0.965
              : screenHeight * 0.98)
        : screenHeight * 0.8);

    // Wrapping the panel in a Stack so we can place a tap overlay above it
    return Stack(
      children: [
        SlidingUpPanel(
          boxShadow: null,
          controller: _panelController,
          // wire controller
          minHeight: fontSizeHeading * 4.2,
          maxHeight: maxHeight,
          backdropEnabled: true,
          // dim background
          backdropOpacity: 0.5,
          // adjust darkness
          backdropTapClosesPanel: true,
          // tap outside to close
          borderRadius: BorderRadius.zero,
          color: Colors.transparent,
          onPanelOpened: () {
            _isPanelOpen.value = true;
            menuKey.currentState?.reverseAnimation();
          },
          onPanelClosed: () {
            // Reset scroll position when panel closes
            _isPanelOpen.value = false;
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
            _panelScrollController ??= controller;

            return Padding(
              padding: EdgeInsetsGeometry.all(0),
              child: SafeArea(
                top: false,
                bottom: false,
                left: true,
                right: true,
                child: Material(
                  elevation: 20,
                  color: isDarkMode
                      ? Colors.blueGrey[700]
                      : const Color(0xff014689),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(fontSizeText),
                  ),
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
                            top: Radius.circular(fontSizeText),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Grab handle
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: fontSizeText * 0.5,
                              ),
                              child: Container(
                                width: fontSizeText * 3,
                                height: fontSizeText * 0.2,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black26,
                                  borderRadius: BorderRadius.circular(
                                    fontSizeText,
                                  ),
                                ),
                              ),
                            ),
                            // Title row with bus icon
                            Padding(
                              padding: EdgeInsets.all(fontSizeText * 0.5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_bus,
                                    color: Colors.white,
                                    size: fontSizeHeading,
                                  ),
                                  SizedBox(width: fontSizeText * 0.5),
                                  Flexible(
                                    child: Text(
                                      'MooBus on-demand',
                                      maxLines: 1,
                                      // or more if you want multiple lines
                                      overflow: TextOverflow.ellipsis,
                                      // options: clip, ellipsis, fade
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
                      // Main body section
                      Expanded(
                        child: Container(
                          color: isDarkMode
                              ? Colors.blueGrey[900]
                              : Colors.white,
                          child: ScrollConfiguration(
                            behavior: const MaterialScrollBehavior().copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                                PointerDeviceKind.stylus,
                              },
                            ),
                            child: ListView.builder(
                              controller: controller,
                              physics:
                                  const ClampingScrollPhysics(), // keep this
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).padding.bottom,
                              ),
                              // We have 6 visual "slots" to build:
                              // 0: SizedBox(height: fontSizeMiniText)
                              // 1: Title Text 'Select MRT'
                              // 2: SizedBox(height: fontSizeMiniText)
                              // 3: displayPage
                              // 4: SizedBox(height: fontSizeText)
                              // 5: NewsAnnouncementWidget
                              itemCount: 6,
                              itemBuilder: (context, index) {
                                switch (index) {
                                  case 0:
                                    return SizedBox(height: fontSizeMiniText);
                                  case 1:
                                    return Center(
                                      child: Text(
                                        'Select MRT',
                                        maxLines: 1, //  limits to 1 lines
                                        overflow: TextOverflow
                                            .ellipsis, // clips text if not fitting
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: fontSizeText,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    );
                                  case 2:
                                    return SizedBox(height: fontSizeMiniText);
                                  case 3:
                                    return RepaintBoundary(child: displayPage);
                                  case 4:
                                    return SizedBox(height: fontSizeText);
                                  case 5:
                                    return NewsAnnouncementWidget();
                                  default:
                                    return const SizedBox.shrink();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // ===== TAP OVERLAY  =====
        // change transparent colour to something else (e.g. green) to see it

        // Overlay controlled by ValueNotifier
        ValueListenableBuilder<bool>(
          valueListenable: _isPanelOpen,
          builder: (context, isOpen, _) {
            if (!isOpen) {
              // when closed at the bottom, so user can also press on header
              // and open panel instead of just dragging it
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0, //  anchored to bottom
                height: fontSizeHeading * 2,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  left: true,
                  right: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _panelController.open(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              );
            } else {
              // same here but for closing
              return Stack(
                children: [
                  // added tap overlays on both left and right if safe area exists
                  // so user can also press there and close the panel
                  if (padding.left > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: padding.left,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _panelController.close(),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  if (padding.right > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: padding.right,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _panelController.close(),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  // and at top (MooBus on-demand height) so if no safe area on left or right
                  // can still close by pressing on it
                  Positioned(
                    left: 0,
                    right: 0,
                    top:
                        screenHeight -
                        (TextSizing.isLandscapeMode(context)
                            ? (TextSizing.isTablet(context)
                                  ? screenHeight * 0.965
                                  : screenHeight * 0.98)
                            : screenHeight * 0.8) +
                        fontSizeText * 3, // towards top of the open panel
                    height: fontSizeHeading * 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _panelController.close(),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- build function of Map Page  ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // build

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('map_page built');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          isDarkMode // changes System UI depending on if it is dark mode or not
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.lightBlueAccent[50],
        body: Stack(
          children: [
            _buildMap(),
            SafeArea(
              top: true,
              bottom: false,
              child: Stack(children: [_logoNP(), _buildCircularMenu()]),
            ),
            _buildSlidingPanel(),
          ],
        ),
      ),
    );
  }
}
