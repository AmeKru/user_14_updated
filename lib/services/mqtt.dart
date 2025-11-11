import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt;

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- MQTT ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Data model for storing MQTT-related values for a single bus.
//
// Each property is wrapped in a [ValueNotifier] so that UI widgets
// can listen for changes and update automatically when new data arrives.

class BusData {
  final ValueNotifier<LatLng?> location = ValueNotifier(
    null,
  ); // Current GPS location
  final ValueNotifier<String?> time = ValueNotifier(''); // Last reported time
  final ValueNotifier<double?> speed = ValueNotifier(
    0,
  ); // Current speed in km/h
  final ValueNotifier<String?> stop = ValueNotifier(''); // Next bus stop name
  final ValueNotifier<String?> eta = ValueNotifier(''); // ETA to next stop
  final ValueNotifier<int?> count = ValueNotifier(0); // Passenger count
}

////////////////////////////////////////////////////////////////////////////////
// Widget that connects to an MQTT broker and listens for bus telemetry.
//
// Displays bus markers on a map based on live location updates.

class ConnectMQTT extends StatefulWidget {
  const ConnectMQTT({super.key});

  //////////////////////////////////////////////////////////////////////////////
  // Static map of bus IDs to their [BusData] instances.
  // This allows easy access to bus data from anywhere in the app.

  static final Map<int, BusData> buses = {
    1: BusData(),
    2: BusData(),
    3: BusData(),
  };

  @override
  ConnectMQTTState createState() => ConnectMQTTState();
}

class ConnectMQTTState extends State<ConnectMQTT> {
  String uniqueID = 'MyPC_24092024'; //MR HUI

  String statusText = "Status Text";
  String? _pendingStatus; // stores a status set before mount
  bool isConnected = false; // Tracks connection state

  // Chelsters
  final mqtt.MqttServerClient client = mqtt.MqttServerClient(
    'a2a1gb4ur9migt-ats.iot.ap-southeast-2.amazonaws.com',
    '',
  );
  // Chelsters

  //////////////////////////////////////////////////////////////////////////////
  // Topics for each bus and data type.
  //
  // Keys: bus ID → Map of data type → MQTT topic name.

  final Map<int, Map<String, String>> topics = {
    1: {
      'loc': 'Bus1Loc',
      'time': 'Bus1Tim',
      'speed': 'Bus1Spd',
      'stop': 'Bus1Stp',
      'eta': 'Bus1Eta',
      'count': 'Bus1Cnt',
    },
    2: {
      'loc': 'Bus2Loc',
      'time': 'Bus2Tim',
      'speed': 'Bus2Spd',
      'stop': 'Bus2Stp',
      'eta': 'Bus2Eta',
      'count': 'Bus2Cnt',
    },
    3: {
      'loc': 'Bus3Loc',
      'time': 'Bus3Tim',
      'speed': 'Bus3Spd',
      'stop': 'Bus3Stp',
      'eta': 'Bus3Eta',
      'count': 'Bus3Cnt',
    },
  };

  // Unique client ID for this MQTT session
  final randomClientID = 'MooRideApp_${DateTime.now().millisecondsSinceEpoch}';

  // Toggle debug logging
  bool debugMode = true;
  void logDebug(String message) {
    if (debugMode) {
      if (kDebugMode) {
        print("[${DateTime.now().toIso8601String()}] $message");
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // If a status was assigned prior to mounting, apply it now without extra logic
    if (_pendingStatus != null) {
      statusText = _pendingStatus!;
      _pendingStatus = null;
    }
    _connect(); // Attempt connection on widget load
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically render markers for all buses based on their live location
    return Stack(
      children: ConnectMQTT.buses.entries.map((entry) {
        final busId = entry.key;
        final busData = entry.value;

        return ValueListenableBuilder<LatLng?>(
          valueListenable: busData.location,
          builder: (context, location, _) {
            if (location != null) {
              return MarkerLayer(
                markers: [
                  Marker(
                    point: location,
                    child: Icon(
                      Icons.directions_bus,
                      color:
                          Colors.blue[busId * 200], // Different shade per bus
                    ),
                  ),
                ],
              );
            }
            return Container(); // No marker if location is null
          },
        );
      }).toList(),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // Initiates connection to the MQTT broker.

  Future<void> _connect() async {
    try {
      logDebug("Connecting to MQTT server...");
      isConnected = await mqttConnect();
      if (mounted) {
        setState(() {
          statusText = isConnected ? "Connected to MQTT" : "Failed to connect";
        });
      }
    } catch (e) {
      logDebug("Error during connection: $e");
      if (mounted) {
        setState(() {
          statusText = "Error during connection";
        });
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // configures and connects the MQTT client to AWS IoT Core
  // loads TLS certificates from assets, sets up secure connection
  // subscribes to all bus topics, and starts listening for updates

  Future<bool> mqttConnect() async {
    try {
      // ===== Load AWS IoT Certificates =====
      ByteData rootCA = await rootBundle.load(
        'assets/c_certs/AmazonRootCA1.pem',
      );
      ByteData deviceCert = await rootBundle.load(
        'assets/c_certs/certificate.pem.crt',
      );
      ByteData privateKey = await rootBundle.load(
        'assets/c_certs/private.pem.key',
      );
      // =====================================

      // Configure TLS security context
      SecurityContext context = SecurityContext.defaultContext;
      context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
      context.useCertificateChainBytes(deviceCert.buffer.asUint8List());
      context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

      // Configure MQTT client
      client.securityContext = context;
      client.logging(on: true);
      client.keepAlivePeriod = 20;
      client.port = 8883; // AWS IoT secure MQTT port
      client.secure = true;
      client.onConnected = onConnected;
      client.onDisconnected = onDisconnected;
      client.pongCallback = pong;

      // Connection message with unique client ID
      final MqttConnectMessage connMess = MqttConnectMessage()
          .withClientIdentifier(randomClientID)
          .startClean();
      client.connectionMessage = connMess;

      // Attempt connection
      await client.connect();

      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        logDebug("Connected to AWS Successfully!");

        // Subscribe to all topics for all buses
        topics.forEach((_, topicMap) {
          for (var topic in topicMap.values) {
            client.subscribe(topic, MqttQos.atMostOnce);
          }
        });

        // Listen for incoming messages
        client.updates!.listen(_onMessage);
        return true;
      } else {
        logDebug("Failed to connect, status: ${client.connectionStatus}");
        return false;
      }
    } catch (e) {
      logDebug("Exception during connection: $e");
      return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Handles incoming MQTT messages and routes them to the
  // correct bus/data type

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    final recMess = messages![0].payload as MqttPublishMessage;
    final topic = messages[0].topic;
    final payload = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    // Match topic to bus and data type
    topics.forEach((busId, topicMap) {
      topicMap.forEach((type, topicName) {
        if (topic == topicName) {
          _processMessage(busId, type, payload);
        }
      });
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // Safely retrieves a value from a JSON map, returning a default if missing

  String _safeGet(
    Map<String, dynamic> data,
    String key, {
    String defaultValue = '',
  }) {
    return data.containsKey(key) ? data[key].toString() : defaultValue;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Processes a decoded MQTT message for a specific bus and data type
  // Updates the corresponding [ValueNotifier] in [BusData] so the UI refreshes

  void _processMessage(int busId, String type, String payload) {
    try {
      final data = jsonDecode(payload);

      switch (type) {
        case 'time':
          ConnectMQTT.buses[busId]!.time.value = _safeGet(data, 'Time');
          break;
        case 'speed':
          ConnectMQTT.buses[busId]!.speed.value =
              double.tryParse(_safeGet(data, 'speed_kmPh')) ?? 0;
          break;
        case 'loc':
          // Parse latitude and longitude from the payload
          final lat = double.tryParse(_safeGet(data, 'lat')) ?? 0;
          final lon = double.tryParse(_safeGet(data, 'lon')) ?? 0;

          // Update the bus's location ValueNotifier so the map marker moves
          ConnectMQTT.buses[busId]!.location.value = LatLng(lat, lon);
          break;

        case 'stop':
          // Update the next bus stop name
          ConnectMQTT.buses[busId]!.stop.value = _safeGet(
            data,
            'next_bus_stop',
          );
          break;

        case 'eta':
          // Extract ETA minutes and seconds
          final min = _safeGet(data, 'eta_minutes');
          final sec = _safeGet(data, 'eta_seconds');

          // Handle special cases for ETA display
          ConnectMQTT.buses[busId]!.eta.value =
              (min == 'Calculating...' || sec == 'Calculating...')
              ? 'Calculating...'
              : (min == 'N/A' || sec == 'N/A')
              ? 'N/A'
              : '${min}mins ${sec}secs';
          break;

        case 'count':
          // Update passenger count
          ConnectMQTT.buses[busId]!.count.value =
              int.tryParse(_safeGet(data, 'passenger_count')) ?? 0;
          break;
      }
    } catch (e) {
      logDebug('Error processing $type for bus $busId: $e');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Updates the connection status text in the UI

  void setStatus(String content) {
    // Always keep the internal value up to date
    statusText = content;

    // If not mounted yet, store for later and skip setState
    if (!mounted) {
      _pendingStatus = content;
      return;
    }

    // Only call setState when safe
    setState(() {
      statusText = content;
    });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Called when the MQTT client successfully connects to the broker

  void onConnected() {
    logDebug("MQTT connection established.");
    // we may also set isConnected here if needed
    isConnected = true;
    setStatus("Client connection was successful");
  }

  //////////////////////////////////////////////////////////////////////////////
  // Called when the MQTT client disconnects from the broker
  // Also attempts to auto-reconnect after 5 seconds if still disconnected

  void onDisconnected() {
    logDebug("MQTT connection lost.");
    isConnected = false;
    setStatus("Client Disconnected");

    // Auto-reconnect after a delay; ensure we don't start connect loops while unmounted
    Future.delayed(const Duration(seconds: 5), () {
      if (!isConnected && mounted) {
        logDebug("Attempting to reconnect...");
        _connect();
      } else if (!isConnected && !mounted) {
        // optional: schedule reconnect later or let parent handle it
        logDebug("Skipped reconnect because widget is not mounted");
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // Called when a PING RESP (pong) is received from the broker

  void pong() {
    logDebug('Ping response client callback invoked');
  }
}
