import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class BusData {
  static final BusData _instance = BusData._internal();
  factory BusData() => _instance;
  BusData._internal();

  final List<DateTime> arrivalTimeKAP = [];
  final List<DateTime> arrivalTimeCLE = [];
  final List<DateTime> departureTimeKAP = [];
  final List<DateTime> departureTimeCLE = [];
  final List<String> busStop = [];
  String news = '';
  bool isDataLoaded = false;

  Future<void> busStops() async {
    try {
      Response response = await get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/busstop?info=BusStops',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> positions = data['positions'];
      for (var position in positions) {
        String id = position['id'];
        busStop.add(id);
        if (kDebugMode) {
          print(id);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error2: $e');
      }
    }
  }

  Future<void> npAnnouncements() async {
    try {
      Response response = await get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/news?info=News',
        ),
      );
      dynamic data = jsonDecode(response.body);
      String newsContent = data['news'];
      news = newsContent;
    } catch (e) {
      if (kDebugMode) {
        print('caught error3: $e');
      }
    }
  }

  Future<void> arrivalTimesKAP() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=KAP_MorningBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        arrivalTimeKAP.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error4: $e');
      }
    }
  }

  Future<void> arrivalTimesCLE() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=CLE_MorningBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        arrivalTimeCLE.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error5: $e');
      }
    }
  }

  Future<void> departureTimesKAP() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=KAP_AfternoonBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        departureTimeKAP.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error6: $e');
      }
    }
  }

  Future<void> departureTimesCLE() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=CLE_AfternoonBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        departureTimeCLE.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error7: $e');
      }
    }
  }

  Future<void> loadData() async {
    if (!isDataLoaded) {
      await arrivalTimesKAP();
      await arrivalTimesCLE();
      await departureTimesKAP();
      await departureTimesCLE();
      await npAnnouncements();
      await busStops();
      BusData();
      isDataLoaded = true;
    }
  }
}
