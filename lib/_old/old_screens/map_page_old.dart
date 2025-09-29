import 'dart:async';
import 'dart:convert';

import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlng;
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/screens/afternoon_screen.dart';
import 'package:user_14_updated/screens/information_page.dart';
import 'package:user_14_updated/screens/announcements_page.dart';
import 'package:user_14_updated/screens/settings_page.dart';
import 'package:user_14_updated/services/get_location.dart';
import 'package:user_14_updated/_old/old_services/mqtt_old.dart';
import 'package:user_14_updated/utils/marker_colour.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  Timer? _timer;
  int selectedBox = 0;
  LatLng? currentLocation;
  double _heading = 0.0;
  List<LatLng> routePoints = [];
  int serviceTime = 9;
  bool ignoring = false;
  bool _isDarkMode = false;

  LatLng? bus1Location;
  String? bus1Time;
  double? bus1Speed;
  String? bus1Stop;
  String? bus1ETA;
  int? bus1Count;

  LatLng? bus2Location;
  String? bus2Time;
  double? bus2Speed;
  String? bus2Stop;
  String? bus2ETA;
  int? bus2Count;

  LatLng? bus3Location;
  String? bus3Time;
  double? bus3Speed;
  String? bus3Stop;
  String? bus3ETA;
  int? bus3Count;

  LocationService locationService = LocationService();
  ConnectMQTT _mqttConnect = ConnectMQTT();
  DateTime now = DateTime.now();

  LatLng busStopENT = LatLng(1.332959, 103.777306);
  LatLng busStopCLE = LatLng(1.313434, 103.765811); // change to test out
  LatLng busStopKAP = LatLng(1.335844, 103.783160);
  LatLng busStopB23 = LatLng(1.333801, 103.775738);
  LatLng busStopSPH = LatLng(1.335110, 103.775464);
  LatLng busStopSIT = LatLng(1.334510, 103.774504);
  LatLng busStopB44 = LatLng(1.3329522845882348, 103.77145520892851);
  LatLng busStopB37 = LatLng(1.332797, 103.773304);
  LatLng busStopMAP = LatLng(1.332473, 103.774377);
  LatLng busStopHSC = LatLng(1.330028, 103.774623);
  LatLng busStopLCT = LatLng(1.330895, 103.774870);
  LatLng busStopB72 = LatLng(1.3314596165361228, 103.7761976140868);
  LatLng oppositeKAP = LatLng(1.336274, 103.783146); //OPP KAP

  List<LatLng> amKAP = [
    // TODO: currently set to Opposite KAP instead of KAP
    // LatLng(1.3365156413692888, 103.78278794804254), // KAP
    LatLng(1.335844, 103.783160),
    LatLng(1.326394, 103.775705), // uTurn
    LatLng(1.3329143792222058, 103.77742909276205), // ENT
    LatLng(1.3324019134469306, 103.7747380910866), // MAP
  ];

  List<LatLng> amCLE = [
    LatLng(1.3153179405495476, 103.76538319080443), // CLE
    LatLng(1.3329143792222058, 103.77742909276205), // ENT
    LatLng(1.3324019134469306, 103.7747380910866), // MAP
  ];

  List<LatLng> pmKAP = [
    LatLng(1.3329143792222058, 103.77742909276205), // ENT
    LatLng(1.3339219201675242, 103.77574132061896), // B23
    LatLng(1.3350826567868576, 103.7754223503998), // SPH
    LatLng(1.3343686930989717, 103.77435631203087), // SIT
    LatLng(1.3329522845882348, 103.77145520892851), // B44
    LatLng(1.3327697559194817, 103.77323977064727), // B37
    LatLng(1.3325776073001032, 103.77438270405088),

    // LatLng(1.3324019134469306, 103.7747380910866), // MAP
    //TODO: something wrong with MAP to HSC
    LatLng(1.330028, 103.774623), //HSC
    LatLng(1.3307778258080973, 103.77543148160284), //between hsc and lct
    LatLng(1.3311533369747423, 103.77490110804173), // LCT
    LatLng(1.3312394356934057, 103.77644173403719), // B72
    LatLng(1.3365156413692888, 103.78278794804254), // Opposite KAP
  ];

  List<LatLng> pmCLE = [
    LatLng(1.3329143792222058, 103.77742909276205), // ENT
    LatLng(1.3339219201675242, 103.77574132061896), // B23
    LatLng(1.3350826567868576, 103.7754223503998), // SPH
    LatLng(1.3343686930989717, 103.77435631203087), // SIT
    LatLng(1.3329522845882348, 103.77145520892851), // B44
    LatLng(1.3327697559194817, 103.77323977064727), // B37
    LatLng(1.3325776073001032, 103.77438270405088),
    // LatLng(1.3324019134469306, 103.7747380910866), // MAP
    //TODO: something wrong with MAP to HSC
    LatLng(1.330028, 103.774623), //HSC
    LatLng(1.3307778258080973, 103.77543148160284), //between hsc and lct
    LatLng(1.3311533369747423, 103.77490110804173), // LCT
    LatLng(1.3312394356934057, 103.77644173403719), // B72
    LatLng(1.331820636037709, 103.77790742890757), //CLE uTurn
    LatLng(1.314967973664341, 103.765121458707), //CLE A
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getLocation();
    _mqttConnect = ConnectMQTT();
    _mqttConnect
        .createState()
        .initState(); // Assuming you have this function in your MQTT_Connect class.

    // Subscribe to the ValueNotifier for bus location updates

    ///////////////////////////////////////////////////////////////
    // BUS 1
    ConnectMQTT.bus1LocationNotifier.addListener(() {
      setState(() {
        bus1Location = ConnectMQTT.bus1LocationNotifier.value;
      });
    });

    ConnectMQTT.bus1SpeedNotifier.addListener(() {
      setState(() {
        bus1Speed = ConnectMQTT.bus1SpeedNotifier.value;
      });
    });
    ConnectMQTT.bus1TimeNotifier.addListener(() {
      setState(() {
        bus1Time = ConnectMQTT.bus1TimeNotifier.value;
      });
    });

    ConnectMQTT.bus1StopNotifier.addListener(() {
      setState(() {
        bus1Stop = ConnectMQTT.bus1StopNotifier.value;
      });
    });

    ConnectMQTT.bus1ETANotifier.addListener(() {
      setState(() {
        bus1ETA = ConnectMQTT.bus1ETANotifier.value;
      });
    });

    ConnectMQTT.bus1CountNotifier.addListener(() {
      setState(() {
        bus1Count = ConnectMQTT.bus1CountNotifier.value;
      });
    });
    // BUS 1
    ///////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////
    // BUS 2
    ConnectMQTT.bus2LocationNotifier.addListener(() {
      setState(() {
        bus2Location = ConnectMQTT.bus2LocationNotifier.value;
      });
    });

    ConnectMQTT.bus2SpeedNotifier.addListener(() {
      setState(() {
        bus2Speed = ConnectMQTT.bus2SpeedNotifier.value;
      });
    });
    ConnectMQTT.bus2TimeNotifier.addListener(() {
      setState(() {
        bus2Time = ConnectMQTT.bus2TimeNotifier.value;
      });
    });

    ConnectMQTT.bus2StopNotifier.addListener(() {
      setState(() {
        bus2Stop = ConnectMQTT.bus2StopNotifier.value;
      });
    });

    ConnectMQTT.bus2ETANotifier.addListener(() {
      setState(() {
        bus2ETA = ConnectMQTT.bus2ETANotifier.value;
      });
    });

    ConnectMQTT.bus2CountNotifier.addListener(() {
      setState(() {
        bus2Count = ConnectMQTT.bus2CountNotifier.value;
      });
    });
    // BUS 2
    ///////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////
    // BUS 3
    ConnectMQTT.bus3LocationNotifier.addListener(() {
      setState(() {
        bus3Location = ConnectMQTT.bus3LocationNotifier.value;
      });
    });

    ConnectMQTT.bus3SpeedNotifier.addListener(() {
      setState(() {
        bus3Speed = ConnectMQTT.bus3SpeedNotifier.value;
      });
    });
    ConnectMQTT.bus3TimeNotifier.addListener(() {
      setState(() {
        bus3Time = ConnectMQTT.bus3TimeNotifier.value;
      });
    });

    ConnectMQTT.bus3StopNotifier.addListener(() {
      setState(() {
        bus3Stop = ConnectMQTT.bus3StopNotifier.value;
      });
    });

    ConnectMQTT.bus3ETANotifier.addListener(() {
      setState(() {
        bus3ETA = ConnectMQTT.bus3ETANotifier.value;
      });
    });

    ConnectMQTT.bus3CountNotifier.addListener(() {
      setState(() {
        bus3Count = ConnectMQTT.bus3CountNotifier.value;
      });
    });
    // BUS 3
    ///////////////////////////////////////////////////////////////
  }

  // void _getLocation() {
  //   _locationService.getCurrentLocation().then((location) {
  //     setState(() {
  //       currentLocation = location;
  //       print('Printing current location: $currentLocation');
  //       print("Bus Location: ${Bus1_Location}");
  //     });
  //   });
  //   _locationService.initCompass((heading){
  //     setState(() {
  //       _heading = heading;
  //     });
  //   });
  // }

  void _getLocation() {
    // Initial location fetch
    locationService.getCurrentLocation().then((location) {
      setState(() {
        currentLocation = location;
        if (kDebugMode) {
          print('Printing current location: $currentLocation');
        }
      });
    });

    // Set up periodic location updates
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      locationService.getCurrentLocation().then((location) {
        setState(() {
          currentLocation = location;
          if (kDebugMode) {
            print('Updated location: $currentLocation');
          }
        });
      });
    });

    // Compass heading updates
    locationService.initCompass((heading) {
      setState(() {
        _heading = heading;
      });
    });
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void updateSelectedBox(int selectedBox) async {
    setState(() {
      this.selectedBox = selectedBox;
      if (selectedBox == 1) {
        //KAP
        //fetchRoute(LatLng(1.3359291665604225, 103.78307744418207));
        //fetchAM_KAPRoute();
        if (now.hour >= startAfternoonService) {
          fetchRoute(pmKAP);
        } else {
          fetchRoute(amKAP);
        }
      } else if (selectedBox == 2) {
        //CLE
        //fetchRoute(LatLng(1.3157535241817033, 103.76510924418207));
        //fetchAM_CLERoute();
        if (now.hour >= startAfternoonService) {
          fetchRoute(pmCLE);
        } else {
          fetchRoute(amCLE);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    //subscription.cancel();
    //client.disconnect();
    super.dispose();
  }

  //Future<void> fetchRoute(List<LatLng> waypoints) async {
  // LatLng start = LatLng(1.3327930713846318, 103.77771893587253);
  //String waypointsStr = waypoints
  //      .map((point) => '${point.longitude},${point.latitude}')
  //      .join(';');
  // TODO: Currently set to morning route, add additional for afternoon route
  //  var url = Uri.parse(
  //  'http://router.project-osrm.org/route/v1/foot/${waypointsStr}?overview=simplified&steps=true&continue_straight=true',
  //);
  //  var response = await http.get(url);

  // if (response.statusCode == 200) {
  // setState(() {
  // routePoints.clear();
  //routePoints.add(start);
  // var data = jsonDecode(response.body);

  //if (data['routes'] != null) {
  //String encodedPolyline = data['routes'][0]['geometry'];
  // List<LatLng> decodedCoordinates = PolylinePoints.decodePolyline(
  // encodedPolyline,
  //   ).map((point) => LatLng(point.latitude, point.longitude)).toList();
  // routePoints.addAll(decodedCoordinates);
  //}
  // });
  //}
  //}

  ///////////////////////////////////////////////////////////////
  // Needed to be able to load map, need to check how this works

  Future<void> fetchRoute(List<latlng.LatLng> waypoints) async {
    // OSRM expects lon,lat order in the URL
    String waypointsStr = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');

    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/foot/$waypointsStr'
      '?overview=simplified&steps=true&continue_straight=true',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final encodedPolyline = data['routes'][0]['geometry'];

        final points = PolylinePoints.decodePolyline(encodedPolyline);

        setState(() {
          routePoints.clear();
          routePoints.addAll(
            points.map((p) => latlng.LatLng(p.latitude, p.longitude)).toList(),
          );
        });
      }
    }
  }
  ///////////////////////////////////////////////////////////////

  void _onPanelOpened() {
    setState(() {
      ignoring = true;
    });
  }

  void _onPanelClosed() {
    setState(() {
      ignoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Widget displayPage = Morning_Screen(updateSelectedBox: updateSelectedBox);
    Widget displayPage = AfternoonScreen(
      updateSelectedBox: updateSelectedBox,
      isDarkMode: _isDarkMode,
    );
    // Widget displayPage = now.hour >= startAfternoonService ? Afternoon_Screen(updateSelectedBox: updateSelectedBox, isDarkMode: _isDarkMode,) : Morning_Screen(updateSelectedBox: updateSelectedBox);
    return Scaffold(
      // body: currentLocation == null? LoadingScreen(isDarkMode: _isDarkMode) : Stack(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              //initialCenter: LatLng(currentLocation!.latitude, currentLocation!.longitude),
              initialCenter: currentLocation == null
                  ? LatLng(1.3331191965635956, 103.7765424614437)
                  : LatLng(
                      currentLocation!.latitude,
                      currentLocation!.longitude,
                    ),
              initialZoom: 18,
              // initialRotation: _heading,
              initialRotation: 0,
              interactionOptions: const InteractionOptions(
                flags: ~InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                tileBuilder: _isDarkMode == true
                    ? (
                        BuildContext context,
                        Widget tileWidget,
                        TileImage tile,
                      ) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -1,
                            0,
                            0,
                            0,
                            255,
                            0,
                            -1,
                            0,
                            0,
                            255,
                            0,
                            0,
                            -1,
                            0,
                            255,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: tileWidget,
                        );
                      }
                    : null,
              ),

              ///////////////////////////////////////////////////////////////
              // Check necessary, so map loads properly
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blue,
                      strokeWidth: 5,
                      pattern: StrokePattern.dashed(
                        segments: [1, 7],
                        patternFit: PatternFit.scaleUp,
                      ),
                    ),
                  ],
                ),

              ///////////////////////////////////////////////////////////////
              MarkerLayer(
                markers: [
                  Marker(
                    point: busStopENT,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('ENT'),
                              content: Text('Entrance Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('ENT', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point:
                        bus1Location ??
                        LatLng(1.3323127398440282, 103.774728443874),
                    child: SizedBox(
                      width: 50,
                      height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bus1',
                            style: TextStyle(
                              fontSize: 8,
                              color: _isDarkMode
                                  ? Colors.lightBlueAccent
                                  : Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.directions_bus,
                            // Icons.circle_sharp,
                            color: _isDarkMode
                                ? Colors.lightBlueAccent
                                : Colors.blue[900],
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Marker(
                    point:
                        bus2Location ??
                        LatLng(1.3323127398440282, 103.774728443874),
                    child: SizedBox(
                      width: 50,
                      height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bus2',
                            style: TextStyle(
                              fontSize: 8,
                              color: _isDarkMode
                                  ? Colors.lightBlueAccent
                                  : Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.directions_bus,
                            // Icons.circle_sharp,
                            color: _isDarkMode
                                ? Colors.lightBlueAccent
                                : Colors.blue[900],
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Marker(
                    point:
                        bus3Location ??
                        LatLng(1.3323127398440282, 103.774728443874),
                    child: SizedBox(
                      width: 50,
                      height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bus3',
                            style: TextStyle(
                              fontSize: 8,
                              color: _isDarkMode
                                  ? Colors.lightBlueAccent
                                  : Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.directions_bus,
                            // Icons.circle_sharp,
                            // color: Colors.blue[900],
                            color: _isDarkMode
                                ? Colors.lightBlueAccent
                                : Colors.blue[900],
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation!,
                      child: CustomPaint(
                        size: Size(300, 200),
                        painter: CompassPainter(
                          direction: _heading,
                          arcSweepAngle: 360,
                          arcStartAngle: 0,
                          context: context,
                        ),
                      ),
                    ),
                  Marker(
                    point: busStopCLE,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('CLE'),
                              content: Text('Clementi MRT Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: _isDarkMode ? Colors.blue[900] : Colors.red,
                        size: (25),
                      ),
                    ),
                  ),
                  // color : _isDarkMode ? Colors.blue[900] : Colors.red,
                  Marker(
                    point: busStopKAP,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('KAP'),
                              content: Text('King Albert Park MRT Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: _isDarkMode ? Colors.blue[900] : Colors.red,
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: oppositeKAP,
                    child: Icon(
                      CupertinoIcons.location_circle_fill,
                      color: Colors.blue[900],
                      size: (25),
                    ),
                  ),
                  Marker(
                    point: busStopB23,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('B23'),
                              content: Text('Block 23 Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('B23', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopSPH,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('SPH'),
                              content: Text('Sports Hall Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('SPH', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopSIT,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('SIT'),
                              content: Text(
                                'Singapore Institute of Technology Bus Stop',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('SIT', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopB44,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('B44'),
                              content: Text('Block 44 Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('B44', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopB37,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('B37'),
                              content: Text('Block 37 Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('B37', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopMAP,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('MAP'),
                              content: Text('Makan Place Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('MAP', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopHSC,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('HSC'),
                              content: Text(
                                'School of Health Sciences Bus Stop',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('HSC', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopLCT,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('LCT'),
                              content: Text(
                                'School of Life Sciences & Technology Bus Stop',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('LCT', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                  Marker(
                    point: busStopB72,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('B72'),
                              content: Text('Block 72 Bus Stop'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Icon(
                        CupertinoIcons.location_circle_fill,
                        // color: Colors.red,
                        color: getMarkerColor('B72', busIndex, _isDarkMode),
                        size: (25),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 30.0, 10.0, 0),
                child: CircularMenu(
                  alignment: Alignment.topRight,
                  radius: 80.0,
                  toggleButtonColor: Colors.cyan,
                  curve: Curves.easeInOut,
                  items: [
                    CircularMenuItem(
                      color: Colors.yellow[300],
                      iconSize: 30.0,
                      margin: 10.0,
                      padding: 10.0,
                      icon: Icons.info_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                InformationPage(isDarkMode: _isDarkMode),
                          ),
                        );
                      },
                    ),
                    CircularMenuItem(
                      color: Colors.green[300],
                      iconSize: 30.0,
                      margin: 10.0,
                      padding: 10.0,
                      icon: Icons.settings,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Settings(
                              isDarkMode: _isDarkMode,
                              onThemeChanged: _toggleTheme,
                            ),
                          ),
                        );
                      },
                    ),
                    CircularMenuItem(
                      color: Colors.pink[300],
                      iconSize: 30.0,
                      margin: 10.0,
                      padding: 10.0,
                      icon: Icons.newspaper,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NewsAnnouncement(isDarkMode: _isDarkMode),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 40.0, 0.0, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ClipOval(
                    child: Image.asset(
                      'images/logo.jpeg',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SlidingUpPanel(
            onPanelOpened: _onPanelOpened,
            onPanelClosed: _onPanelClosed,
            panelBuilder: (controller) {
              return Container(
                color: _isDarkMode
                    ? Colors.lightBlue[900]
                    : Colors.lightBlue[100],
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'MooBus on-demand',
                            style: TextStyle(
                              color: _isDarkMode ? Colors.white : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                      displayPage,
                      SizedBox(height: 16),
                      NewsAnnouncementWidget(isDarkMode: _isDarkMode),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
