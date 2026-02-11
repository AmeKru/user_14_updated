import 'dart:convert';
import 'dart:io' show SecurityContext; // only used on mobile/desktop

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_core/amplify_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_imports/mqtt_neither.dart'
    if (dart.library.io) 'mqtt_imports/mqtt_io.dart'
    if (dart.library.html) 'mqtt_imports/mqtt_web.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- MQTT ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// data model for storing MQTT-related values for a single bus
//
// each property is wrapped in a [ValueNotifier] so that UI widgets
// can listen for changes and update automatically when new data arrives

class BusData {
  final ValueNotifier<LatLng?> location = ValueNotifier(
    null,
  ); // current GPS location
  final ValueNotifier<String?> time = ValueNotifier(''); // last reported time
  final ValueNotifier<double?> speed = ValueNotifier(
    0,
  ); // current speed in km/h
  final ValueNotifier<String?> stop = ValueNotifier(''); // next bus stop name
  final ValueNotifier<String?> eta = ValueNotifier(''); // ETA to next stop
  final ValueNotifier<int?> count = ValueNotifier(0); // passenger count
}

////////////////////////////////////////////////////////////////////////////////
// widget that connects to an MQTT broker and listens for bus telemetry.

class ConnectMQTT extends StatefulWidget {
  const ConnectMQTT({super.key});

  //////////////////////////////////////////////////////////////////////////////
  // static map of bus IDs to their [BusData] instances.
  // this allows easy access to bus data from anywhere in the app.

  static final Map<int, BusData> buses = {
    1: BusData(),
    2: BusData(),
    3: BusData(),
  };

  @override
  ConnectMQTTState createState() => ConnectMQTTState();
}

class ConnectMQTTState extends State<ConnectMQTT> {
  String statusText = "Status Text";
  String? _pendingStatus; // stores a status set before mount
  bool isConnected = false; // tracks connection state

  late dynamic client;

  //////////////////////////////////////////////////////////////////////////////
  // topics for each bus and data type.  (=°^°=)
  //
  // keys: bus ID → Map of data type → MQTT topic name.

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

  // unique client ID for this MQTT session
  final randomClientID = 'MooRideApp_${DateTime.now().millisecondsSinceEpoch}';

  // toggle debug logging
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

    // if a status was assigned prior to mounting, apply it now without extra logic
    if (_pendingStatus != null) {
      statusText = _pendingStatus!;
      _pendingStatus = null;
    }
    _connect(); // Attempt connection on widget load
  }

  @override
  Widget build(BuildContext context) {
    // dynamically render markers for all buses based on their live location
    return SizedBox();
  }

  //////////////////////////////////////////////////////////////////////////////
  // initiates connection to the MQTT broker.

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
      if (!kIsWeb) {
        client = MqttClientDef(
          'azhwphql7mbha-ats.iot.ap-southeast-1.amazonaws.com',
          '',
        );

        // ===== Mobile/Desktop: TLS Certificates =====
        ByteData rootCA = await rootBundle.load(
          'assets/c_certs/AmazonRootCA1.pem',
        );
        ByteData deviceCert = await rootBundle.load(
          'assets/c_certs/certificate.pem',
        );
        ByteData privateKey = await rootBundle.load(
          'assets/c_certs/private.pem',
        );

        // Configure TLS security context (mobile/desktop only)
        SecurityContext context = SecurityContext.defaultContext;
        context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
        context.useCertificateChainBytes(deviceCert.buffer.asUint8List());
        context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

        client.securityContext = context;
        client.port = 8883; // AWS IoT secure MQTT port
        client.secure = true;
      } else {
        // Web: TLS handled by browser, no SecurityContext
        final session =
            await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
        final creds = session.credentialsResult.value;

        final signedUrl = buildSignedUrl(
          accessKeyId: creds.accessKeyId,
          secretAccessKey: creds.secretAccessKey,
          sessionToken: creds.sessionToken!,
          region: "ap-southeast-1",
          endpoint: "azhwphql7mbha-ats.iot.ap-southeast-1.amazonaws.com",
        );

        // Instantiate browser client with the signed URL string
        client = MqttClientDef(signedUrl, randomClientID);
        client.port = 443;
      }

      // Common MQTT client configuration
      client.logging(on: true);
      client.keepAlivePeriod = 20;
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

        // Subscribe to topics
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

  String buildSignedUrl({
    required String accessKeyId,
    required String secretAccessKey,
    required String sessionToken,
    required String region,
    required String endpoint,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);

    final service = "iotdevicegateway";
    final algorithm = "AWS4-HMAC-SHA256";
    final credentialScope = "$dateStamp/$region/$service/aws4_request";

    final canonicalUri = "/mqtt";
    final canonicalQuerystring =
        "X-Amz-Algorithm=$algorithm&X-Amz-Credential=${Uri.encodeComponent("$accessKeyId/$credentialScope")}"
        "&X-Amz-Date=$amzDate&X-Amz-SignedHeaders=host";

    final canonicalHeaders = "host:$endpoint\n";
    final signedHeaders = "host";
    final payloadHash = sha256.convert(utf8.encode("")).toString();

    final canonicalRequest =
        "GET\n$canonicalUri\n$canonicalQuerystring\n$canonicalHeaders\n$signedHeaders\n$payloadHash";

    final stringToSign =
        "$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}";

    final signingKey = _getSignatureKey(
      secretAccessKey,
      dateStamp,
      region,
      service,
    );
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    final finalQuerystring =
        "$canonicalQuerystring&X-Amz-Signature=$signature&X-Amz-Security-Token=${Uri.encodeComponent(sessionToken)}";

    return "wss://$endpoint$canonicalUri?$finalQuerystring";
  }

  String _formatAmzDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}"
        "${dt.month.toString().padLeft(2, '0')}"
        "${dt.day.toString().padLeft(2, '0')}T"
        "${dt.hour.toString().padLeft(2, '0')}"
        "${dt.minute.toString().padLeft(2, '0')}"
        "${dt.second.toString().padLeft(2, '0')}Z";
  }

  String _formatDateStamp(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}"
        "${dt.month.toString().padLeft(2, '0')}"
        "${dt.day.toString().padLeft(2, '0')}";
  }

  Uint8List _getSignatureKey(
    String key,
    String dateStamp,
    String region,
    String service,
  ) {
    final kDate = Hmac(
      sha256,
      utf8.encode("AWS4$key"),
    ).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    final kSigning = Hmac(
      sha256,
      kService,
    ).convert(utf8.encode("aws4_request")).bytes;
    return Uint8List.fromList(kSigning);
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

    // match topic to bus and data type
    topics.forEach((busId, topicMap) {
      topicMap.forEach((type, topicName) {
        if (topic == topicName) {
          _processMessage(busId, type, payload);
        }
      });
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // safely retrieves a value from a JSON map, returning a default if missing

  String _safeGet(
    Map<String, dynamic> data,
    String key, {
    String defaultValue = '',
  }) {
    return data.containsKey(key) ? data[key].toString() : defaultValue;
  }

  //////////////////////////////////////////////////////////////////////////////
  // processes a decoded MQTT message for a specific bus and data type
  // updates the corresponding [ValueNotifier] in [BusData] so the UI refreshes

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
          // parse latitude and longitude from the payload
          final lat = double.tryParse(_safeGet(data, 'lat')) ?? 0;
          final lon = double.tryParse(_safeGet(data, 'lon')) ?? 0;

          // update the bus's location ValueNotifier so the map marker moves
          ConnectMQTT.buses[busId]!.location.value = LatLng(lat, lon);
          break;

        case 'stop':
          // update the next bus stop name
          ConnectMQTT.buses[busId]!.stop.value = _safeGet(
            data,
            'next_bus_stop',
          );
          break;

        case 'eta':
          // extract ETA minutes and seconds
          final min = _safeGet(data, 'eta_minutes');
          final sec = _safeGet(data, 'eta_seconds');

          // handle special cases for ETA display
          ConnectMQTT.buses[busId]!.eta.value =
              (min == 'Calculating...' || sec == 'Calculating...')
              ? 'Calculating...'
              : (min == 'N/A' || sec == 'N/A')
              ? 'N/A'
              : '${min}mins ${sec}secs';
          break;

        case 'count':
          // update passenger count
          ConnectMQTT.buses[busId]!.count.value =
              int.tryParse(_safeGet(data, 'passenger_count')) ?? 0;
          break;
      }
    } catch (e) {
      logDebug('Error processing $type for bus $busId: $e');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // updates the connection status text in the UI

  void setStatus(String content) {
    // always keep the internal value up to date
    statusText = content;

    // if not mounted yet, store for later and skip setState
    if (!mounted) {
      _pendingStatus = content;
      return;
    }

    // only call setState when safe
    setState(() {
      statusText = content;
    });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // called when the MQTT client successfully connects to the broker

  void onConnected() {
    logDebug("MQTT connection established.");
    // we may also set isConnected here if needed
    isConnected = true;
    setStatus("Client connection was successful");
  }

  //////////////////////////////////////////////////////////////////////////////
  // called when the MQTT client disconnects from the broker
  // also attempts to auto-reconnect after 5 seconds if still disconnected

  void onDisconnected() {
    logDebug("MQTT connection lost.");
    isConnected = false;
    setStatus("Client Disconnected");

    // auto-reconnect after a delay; ensure we don't start connect loops while unmounted
    Future.delayed(const Duration(seconds: 5), () {
      if (!isConnected && mounted) {
        logDebug("Attempting to reconnect...");
        _connect();
      } else if (!isConnected && !mounted) {
        logDebug("Skipped reconnect because widget is not mounted");
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // called when a PING RESP (pong) is received from the broker

  void pong() {
    logDebug('Ping response client callback invoked');
  }
}
