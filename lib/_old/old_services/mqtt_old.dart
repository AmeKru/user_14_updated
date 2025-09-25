import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt;

class ConnectMQTT extends StatefulWidget {
  const ConnectMQTT({super.key});
  // BUS 1 - KAP
  static ValueNotifier<LatLng?> bus1LocationNotifier = ValueNotifier<LatLng?>(
    null,
  );
  static ValueNotifier<String?> bus1TimeNotifier = ValueNotifier<String?>('');
  static ValueNotifier<double?> bus1SpeedNotifier = ValueNotifier<double?>(0);
  static ValueNotifier<String?> bus1StopNotifier = ValueNotifier<String?>('');
  static ValueNotifier<String?> bus1ETANotifier = ValueNotifier<String?>('');
  static ValueNotifier<int?> bus1CountNotifier = ValueNotifier<int?>(0);
  // BUS 1 - KAP

  // BUS 2 - KAP
  static ValueNotifier<LatLng?> bus2LocationNotifier = ValueNotifier<LatLng?>(
    null,
  );
  static ValueNotifier<String?> bus2TimeNotifier = ValueNotifier<String?>('');
  static ValueNotifier<double?> bus2SpeedNotifier = ValueNotifier<double?>(0);
  static ValueNotifier<String?> bus2StopNotifier = ValueNotifier<String?>('');
  static ValueNotifier<String?> bus2ETANotifier = ValueNotifier<String?>('');
  static ValueNotifier<int?> bus2CountNotifier = ValueNotifier<int?>(0);
  //BUS 2 - KAP

  //BUS 3 - CLE
  static ValueNotifier<LatLng?> bus3LocationNotifier = ValueNotifier<LatLng?>(
    null,
  );
  static ValueNotifier<String?> bus3TimeNotifier = ValueNotifier<String?>('');
  static ValueNotifier<double?> bus3SpeedNotifier = ValueNotifier<double?>(0);
  static ValueNotifier<String?> bus3StopNotifier = ValueNotifier<String?>('');
  static ValueNotifier<String?> bus3ETANotifier = ValueNotifier<String?>('');
  static ValueNotifier<int?> bus3CountNotifier = ValueNotifier<int?>(0);
  //BUS 3 - CLE

  @override
  ConnectMQTTState createState() => ConnectMQTTState();
}

class ConnectMQTTState extends State<ConnectMQTT> {
  String uniqueID = 'MyPC_24092024'; //MR HUI
  //String uniqueID = 'moobus-id'; //chelsters

  // Chelsters
  final mqtt.MqttServerClient client = mqtt.MqttServerClient(
    'a2a1gb4ur9migt-ats.iot.ap-southeast-2.amazonaws.com',
    '',
  );
  // Chelsters

  // Mr Huis
  // final MqttServerClient client = mqtt.MqttServerClient('avkbwu51u3x1o-ats.iot.us-east-2.amazonaws.com', '');
  // Mr Huis

  // Aqils
  // final MqttServerClient client = mqtt.MqttServerClient('a3czpldm2v11ov-ats.iot.ap-southeast-2.amazonaws.com', ''); //Aqils one
  // Aqils

  String statusText = "Status Text";
  bool isConnected = false;
  // BUS 1
  String topicBus1Loc = 'Bus1Loc';
  String topicBus1Time = 'Bus1Tim';
  String topicBus1Speed = 'Bus1Spd';
  String topicBus1Stop = 'Bus1Stp';
  String topicBus1ETA = 'Bus1Eta';
  String topicBus1Cnt = 'Bus1Cnt';
  // BUS 1

  // BUS 2
  String topicBus2Loc = 'Bus2Loc';
  String topicBus2Time = 'Bus2Tim';
  String topicBus2Speed = 'Bus2Spd';
  String topicBus2Stop = 'Bus2Stp';
  String topicBus2ETA = 'Bus2Eta';
  String topicBus2Cnt = 'Bus2Cnt';
  //BUS 2

  //BUS 3
  String topicBus3Loc = 'Bus3Loc';
  String topicBus3Time = 'Bus3Tim';
  String topicBus3Speed = 'Bus3Spd';
  String topicBus3Stop = 'Bus3Stp';
  String topicBus3ETA = 'Bus3Eta';
  String topicBus3Cnt = 'Bus3Cnt';
  //BUS 3

  double latitude = 0;
  double longitude = 0;

  final randomClientID = 'MooRideApp_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _connect(); // Call the async connection method in initState
  }

  // void initializeConnection() {
  // _connect();
  // }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<LatLng?>(
          valueListenable: ConnectMQTT.bus1LocationNotifier,
          builder: (context, bus1Location, _) {
            if (bus1Location != null) {
              return MarkerLayer(
                markers: [
                  Marker(
                    point: bus1Location,
                    child: const Icon(Icons.add_circle),
                  ),
                ],
              );
            } else {
              return Container(); // Return an empty container if location is null
            }
          },
        ),
      ],
    );
  }

  Future<void> _connect() async {
    try {
      if (kDebugMode) {
        print("Connecting to MQTT server...");
      }
      isConnected = await mqttConnect();
      if (mounted) {
        setState(() {
          statusText = isConnected ? "Connected to MQTT" : "Failed to connect";
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error during connection: $e");
      }
      if (mounted) {
        setState(() {
          statusText = "Error during connection";
        });
      }
    }
  }

  Future<bool> mqttConnect() async {
    if (kDebugMode) {
      print('MQTT Connect');
    }
    try {
      //  =====MR HUI CERTS=====
      // ByteData rootCA = await rootBundle.load('assets/cert/AmazonRootCA1.pem');
      // ByteData deviceCert = await rootBundle.load('assets/cert/SurfacePC.cert.pem');
      // ByteData privateKey = await rootBundle.load('assets/cert/SurfacePC.private.key');
      // =====MR HUI CERTS=====

      // =====CHELSTER CERT=====
      ByteData rootCA = await rootBundle.load(
        'assets/c_certs/AmazonRootCA1.pem',
      );
      ByteData deviceCert = await rootBundle.load(
        'assets/c_certs/certificate.pem.crt',
      );
      ByteData privateKey = await rootBundle.load(
        'assets/c_certs/private.pem.key',
      );
      // =====CHELSTER CERT=====

      // =====CHELSTERS OLD CERTS=====
      // ByteData rootCA = await rootBundle.load('assets/c_certs_old/AmazonRootCA1.pem');
      // ByteData deviceCert = await rootBundle.load('assets/c_certs_old/certificate.cert.pem');
      // ByteData privateKey = await rootBundle.load('assets/c_certs_old/c_cert.private.key');
      // =====CHELSTERS OLD CERTS=====

      SecurityContext context = SecurityContext.defaultContext;
      context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
      context.useCertificateChainBytes(deviceCert.buffer.asUint8List());
      context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

      client.securityContext = context;
      client.logging(on: true);
      client.keepAlivePeriod = 20;
      client.port = 8883;
      client.secure = true;
      client.onConnected = onConnected;
      client.onDisconnected = onDisconnected;
      client.pongCallback = pong;

      if (kDebugMode) {
        print('printing client port: ${client.port}');

        print('printing client.update: ${client.updates}');
        print('printing client status1: ${client.connectionStatus}');
      }

      if (client.updates != null) {
        client.updates!.listen(_onMessage);
      }

      final MqttConnectMessage connMess = MqttConnectMessage()
          .withClientIdentifier(randomClientID)
          .startClean();
      client.connectionMessage = connMess;

      if (kDebugMode) {
        print('printing connMess: $connMess');
        print('printing client status2: ${client.connectionStatus}');
        print('waiting client connect');
        print('printing client status3: ${client.connectionStatus}');
      }

      await client.connect();
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        if (kDebugMode) {
          print("Connected to AWS Successfully!");
        }
        // BUS 1
        client.subscribe(topicBus1Loc, MqttQos.atMostOnce);
        client.subscribe(topicBus1Speed, MqttQos.atMostOnce);
        client.subscribe(topicBus1Time, MqttQos.atMostOnce);
        client.subscribe(topicBus1Stop, MqttQos.atMostOnce);
        client.subscribe(topicBus1ETA, MqttQos.atMostOnce);
        client.subscribe(topicBus1Cnt, MqttQos.atMostOnce);
        // BUS 1

        // BUS 2
        client.subscribe(topicBus2Loc, MqttQos.atMostOnce);
        client.subscribe(topicBus2Speed, MqttQos.atMostOnce);
        client.subscribe(topicBus2Time, MqttQos.atMostOnce);
        client.subscribe(topicBus2Stop, MqttQos.atMostOnce);
        client.subscribe(topicBus2ETA, MqttQos.atMostOnce);
        client.subscribe(topicBus2Cnt, MqttQos.atMostOnce);
        // BUS 2

        // BUS 3
        client.subscribe(topicBus3Loc, MqttQos.atMostOnce);
        client.subscribe(topicBus3Speed, MqttQos.atMostOnce);
        client.subscribe(topicBus3Time, MqttQos.atMostOnce);
        client.subscribe(topicBus3Stop, MqttQos.atMostOnce);
        client.subscribe(topicBus3ETA, MqttQos.atMostOnce);
        client.subscribe(topicBus3Cnt, MqttQos.atMostOnce);
        // BUS 3
        client.updates!.listen(_onMessage); // Listen for incoming messages
        return true;
      } else {
        if (kDebugMode) {
          print("Failed to connect, status: ${client.connectionStatus}");
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Exception during connection: $e");
      }
      return false;
    }
  }

  // TODO: IF GOT ISSUES WITH MULTIPLE BUSES MQTT THEN MAYBE THIS IS THE ISSUE

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (kDebugMode) {
      print('Inside _onMessage function');
    }
    final MqttPublishMessage recMess =
        messages![0].payload as MqttPublishMessage;
    if (kDebugMode) {
      print('Printing recMess: $recMess');
    }
    final String topic1 = messages[0].topic;
    if (kDebugMode) {
      print('Printing topic: $topic1');
    }

    // Extract the payload as a String
    final String payload = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );
    if (kDebugMode) {
      print('Printing payload: $payload');
    }

    // BUS 1
    if (topic1 == topicBus1Loc) {
      _processBus1LocationMessage(payload);
    } else if (topic1 == topicBus1Time) {
      _processBus1TimeMessage(payload);
    } else if (topic1 == topicBus1Speed) {
      _processBus1SpeedMessage(payload);
    } else if (topic1 == topicBus1Stop) {
      _processBus1StopMessage(payload);
    } else if (topic1 == topicBus1ETA) {
      _processBus1ETAMessage(payload);
    } else if (topic1 == topicBus1Cnt) {
      _processBus1CountMessage(payload);
    }
    // BUS 1
    // BUS 2
    else if (topic1 == topicBus2Loc) {
      _processBus2LocationMessage(payload);
    } else if (topic1 == topicBus2Time) {
      _processBus2TimeMessage(payload);
    } else if (topic1 == topicBus2Speed) {
      _processBus2SpeedMessage(payload);
    } else if (topic1 == topicBus2Stop) {
      _processBus2StopMessage(payload);
    } else if (topic1 == topicBus2ETA) {
      _processBus2ETAMessage(payload);
    } else if (topic1 == topicBus2Cnt) {
      _processBus2CountMessage(payload);
    }
    // BUS 2
    // BUS 3
    else if (topic1 == topicBus3Loc) {
      _processBus3LocationMessage(payload);
    } else if (topic1 == topicBus3Time) {
      _processBus3TimeMessage(payload);
    } else if (topic1 == topicBus3Speed) {
      _processBus3SpeedMessage(payload);
    } else if (topic1 == topicBus3Stop) {
      _processBus3StopMessage(payload);
    } else if (topic1 == topicBus3ETA) {
      _processBus3ETAMessage(payload);
    } else if (topic1 == topicBus3Cnt) {
      _processBus3CountMessage(payload);
    }
    // BUS 3
  }

  // ============== BUS 1 ==============
  // ============== BUS 1 ==============
  // ============== BUS 1 ==============

  void _processBus1TimeMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus1TimeMessage function');
    }

    try {
      //Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String time = data['Time'];
      if (kDebugMode) {
        print('Printing bus1time: $time');
      }

      ConnectMQTT.bus1TimeNotifier.value = time;
      if (kDebugMode) {
        print('Updating bus1time: ${ConnectMQTT.bus1TimeNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus1SpeedMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus1SpeedMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String speed = data['speed_kmph'];
      if (kDebugMode) {
        print('Printing bus1speed: $speed');
      }

      ConnectMQTT.bus1SpeedNotifier.value = double.parse(speed);
      if (kDebugMode) {
        print('Updating bus1speed: ${ConnectMQTT.bus1SpeedNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus1LocationMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus1LocationMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);

      // Extract latitude and longitude
      latitude = double.parse(data['lat']);
      longitude = double.parse(data['lon']);

      LatLng bus1Location = LatLng(latitude, longitude);

      // Update the ValueNotifier with the new bus location
      ConnectMQTT.bus1LocationNotifier.value = bus1Location;

      if (kDebugMode) {
        print("Updated Bus1 Location: $bus1Location");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processing location message: $e");
      }
    }
  }

  void _processBus1StopMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus1StopMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String stop = data['next_bus_stop']; //if chelster change need change
      if (kDebugMode) {
        print('Printing bus1stop: $stop');
      }

      ConnectMQTT.bus1StopNotifier.value = stop;
      if (kDebugMode) {
        print('Updating bus1stop: ${ConnectMQTT.bus1StopNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus1ETAMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus1ETAMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String etaMin = data['eta_minutes'];
      String etaSec = data['eta_seconds'];
      String eta = '';
      if (etaMin == 'Calculating...' || etaSec == 'Calculating...') {
        eta = 'Calculating...';
      } else if (etaMin == 'N/A' || etaSec == 'N/A') {
        eta = 'N/A';
      } else {
        eta = '${etaMin}mins ${etaSec}secs';
      }
      if (kDebugMode) {
        print('Printing bus1eta: $eta');
      }

      ConnectMQTT.bus1ETANotifier.value = eta;
      if (kDebugMode) {
        print('Updating bus1eta: ${ConnectMQTT.bus1ETANotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus1CountMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus1CountMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      int count = int.parse(data['passenger_count']);
      if (kDebugMode) {
        print('Printing bus1count: $count');
      }

      ConnectMQTT.bus1CountNotifier.value = count;
      if (kDebugMode) {
        print('Updating bus1count: ${ConnectMQTT.bus1CountNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  // ============== BUS 1 ==============
  // ============== BUS 1 ==============
  // ============== BUS 1 ==============

  // ============== BUS 2 ==============
  // ============== BUS 2 ==============
  // ============== BUS 2 ==============

  void _processBus2TimeMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2TimeMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String time = data['Time'];
      if (kDebugMode) {
        print('Printing bus2time: $time');
      }

      ConnectMQTT.bus2TimeNotifier.value = time;
      if (kDebugMode) {
        print('Updating bus2time: ${ConnectMQTT.bus2TimeNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus2SpeedMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2SpeedMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String speed = data['speed_kmph'];
      if (kDebugMode) {
        print('Printing bus2speed: $speed');
      }

      ConnectMQTT.bus2SpeedNotifier.value = double.parse(speed);
      if (kDebugMode) {
        print('Updating bus2speed: ${ConnectMQTT.bus2SpeedNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus2LocationMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2LocationMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);

      // Extract latitude and longitude
      latitude = double.parse(data['lat']);
      longitude = double.parse(data['lon']);

      LatLng bus2Location = LatLng(latitude, longitude);

      // Update the ValueNotifier with the new bus location
      ConnectMQTT.bus2LocationNotifier.value = bus2Location;

      if (kDebugMode) {
        print("Updated Bus2 Location: $bus2Location");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processing location message: $e");
      }
    }
  }

  void _processBus2StopMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2StopMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String stop = data['next_bus_stop']; //if chelster change need change
      if (kDebugMode) {
        print('Printing bus2stop: $stop');
      }

      ConnectMQTT.bus2StopNotifier.value = stop;
      if (kDebugMode) {
        print('Updating bus2stop: ${ConnectMQTT.bus2StopNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus2ETAMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2ETAMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String etaMin = data['eta_minutes'];
      String etaSec = data['eta_seconds'];
      String eta = '';
      if (etaMin == 'Calculating...' || etaSec == 'Calculating...') {
        eta = 'Calculating...';
      } else if (etaMin == 'N/A' || etaSec == 'N/A') {
        eta = 'N/A';
      } else {
        eta = '${etaMin}mins ${etaSec}secs';
      }
      if (kDebugMode) {
        print('Printing bus2eta: $eta');
      }

      ConnectMQTT.bus2ETANotifier.value = eta;
      if (kDebugMode) {
        print('Updating bus2eta: ${ConnectMQTT.bus2ETANotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus2CountMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2CountMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      int count = int.parse(data['passenger_count']);
      if (kDebugMode) {
        print('Printing bus2count: $count');
      }

      ConnectMQTT.bus2CountNotifier.value = count;
      if (kDebugMode) {
        print('Updating bus2count: ${ConnectMQTT.bus2CountNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }
  // ============== BUS 2 ==============
  // ============== BUS 2 ==============
  // ============== BUS 2 ==============

  // ============== BUS 3 ==============
  // ============== BUS 3 ==============
  // ============== BUS 3 ==============
  void _processBus3TimeMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus3TimeMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String time = data['Time'];
      if (kDebugMode) {
        print('Printing bus3time: $time');
      }

      ConnectMQTT.bus3TimeNotifier.value = time;
      if (kDebugMode) {
        print('Updating bus3time: ${ConnectMQTT.bus3TimeNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus3SpeedMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus3SpeedMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String speed = data['speed_kmph'];
      if (kDebugMode) {
        print('Printing bus3speed: $speed');
      }

      ConnectMQTT.bus3SpeedNotifier.value = double.parse(speed);
      if (kDebugMode) {
        print('Updating bus2speed: ${ConnectMQTT.bus3SpeedNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus3LocationMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus3LocationMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);

      // Extract latitude and longitude
      latitude = double.parse(data['lat']);
      longitude = double.parse(data['lon']);

      LatLng bus3Location = LatLng(latitude, longitude);

      // Update the ValueNotifier with the new bus location
      ConnectMQTT.bus3LocationNotifier.value = bus3Location;

      if (kDebugMode) {
        print("Updated Bus3 Location: $bus3Location");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processing location message: $e");
      }
    }
  }

  void _processBus3StopMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus2StopMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String stop = data['next_bus_stop']; //if chelster change need change
      if (kDebugMode) {
        print('Printing bus3stop: $stop');
      }

      ConnectMQTT.bus3StopNotifier.value = stop;
      if (kDebugMode) {
        print('Updating bus3stop: ${ConnectMQTT.bus3StopNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus3ETAMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus3ETAMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String etaMin = data['eta_minutes'];
      String etaSec = data['eta_seconds'];
      String eta = '';
      if (etaMin == 'Calculating...' || etaSec == 'Calculating...') {
        eta = 'Calculating...';
      } else if (etaMin == 'N/A' || etaSec == 'N/A') {
        eta = 'N/A';
      } else {
        eta = '${etaMin}mins ${etaSec}secs';
      }
      if (kDebugMode) {
        print('Printing bus3eta: $eta');
      }

      ConnectMQTT.bus3ETANotifier.value = eta;
      if (kDebugMode) {
        print('Updating bus3eta: ${ConnectMQTT.bus3ETANotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }

  void _processBus3CountMessage(String payload) {
    if (kDebugMode) {
      print('Inside _processBus3CountMessage function');
    }

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      int count = int.parse(data['passenger_count']);
      if (kDebugMode) {
        print('Printing bus3count: $count');
      }

      ConnectMQTT.bus3CountNotifier.value = count;
      if (kDebugMode) {
        print('Updating bus3count: ${ConnectMQTT.bus3CountNotifier.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught error : $e');
      }
    }
  }
  // ============== BUS 3 ==============
  // ============== BUS 3 ==============
  // ============== BUS 3 ==============

  void setStatus(String content) {
    setState(() {
      statusText = content;
    });
  }

  void onConnected() {
    setStatus("Client connection was successful");
  }

  void onDisconnected() {
    setStatus("Client Disconnected");
    isConnected = false;
  }

  void pong() {
    if (kDebugMode) {
      print('Ping response client callback invoked');
    }
  }
}
