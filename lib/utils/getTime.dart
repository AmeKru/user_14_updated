// import 'dart:async';
// import 'dart:convert';
// import 'package:http/http.dart';
// import 'package:flutter/foundation.dart';
//
// class TimeService with ChangeNotifier {
//   static final TimeService _instance = TimeService._internal();
//   factory TimeService() => _instance;
//
//   DateTime? time_now;
//   Duration timeUpdateInterval = Duration(minutes: 1);
//   Timer? _clockTimer;
//
//   TimeService._internal() {
//     // Start automatic updates
//     _startTimer();
//   }
//
//   Future<DateTime?> getTime() async {
//     try {
//       final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
//       final response = await get(uri);
//       print("Printing response: $response");
//
//       if (response.statusCode == 200) {
//         Map<String, dynamic> data = jsonDecode(response.body);
//         String datetime = data['datetime'];
//         String offset = data['utc_offset'].substring(1, 3);
//
//         time_now = DateTime.parse(datetime).add(Duration(hours: int.parse(offset)));
//         print("Updated Time: $time_now");
//         notifyListeners(); // Notify listeners of the update
//         return time_now;
//       } else {
//         print("Failed to get time data from the API. Status Code: ${response.statusCode}");
//       }
//     } catch (e) {
//       print('Caught error: $e');
//     }
//   }
//
//   void _startTimer() {
//     _clockTimer = Timer.periodic(timeUpdateInterval, (timer) {
//       updateTimeManually();
//       if (timer.tick % (timeUpdateInterval.inMinutes) == 0) {
//         getTime(); // Fetch new time from the API every few minutes
//       }
//     });
//   }
//
//   void updateTimeManually() {
//     if (time_now != null) {
//       time_now = time_now!.add(timeUpdateInterval);
//       print("Manually updated time: $time_now");
//       notifyListeners(); // Notify listeners of the manual update
//     } else {
//       print("Time is null, please fetch the time first.");
//     }
//   }
//
//   void dispose() {
//     _clockTimer?.cancel();
//     super.dispose();
//   }
// }


// ORIGINAL CODE ABOVE^^^^^^

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:flutter/foundation.dart';

class TimeService with ChangeNotifier {
  static final TimeService _instance = TimeService._internal();
  factory TimeService() => _instance;

  DateTime? time_now;
  Duration timeUpdateInterval = Duration(minutes: 1);
  Timer? _clockTimer;

  TimeService._internal() {
    // Start automatic updates
    _startTimer();
  }

  Future<DateTime?> getTime() async {
    try {
      final uri = Uri.parse('https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE');
      // final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
      final response = await get(uri);
      print("Printing response: $response");

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        String datetime = data['dateTime']; // timeapi.io uses dateTime
        //String offset = data['utc_offset'].substring(1, 3);

        time_now =DateTime.parse(datetime);
        //time_now = DateTime.parse(datetime).add(Duration(hours: int.parse(offset)));
        print("Updated Time: $time_now");
        notifyListeners(); // Notify listeners of the update
        return time_now;
      } else {
        print("Failed to get time data from the API. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      print('Caught error: $e');
    }
  }

  void _startTimer() {
    _clockTimer = Timer.periodic(timeUpdateInterval, (timer) {
      updateTimeManually();
      if (timer.tick % (timeUpdateInterval.inMinutes) == 0) {
        getTime(); // Fetch new time from the API every few minutes
      }
    });
  }

  void updateTimeManually() {
    if (time_now != null) {
      time_now = time_now!.add(timeUpdateInterval);
      print("Manually updated time: $time_now");
      notifyListeners(); // Notify listeners of the manual update
    } else {
      print("Time is null, please fetch the time first.");
    }
  }

  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
