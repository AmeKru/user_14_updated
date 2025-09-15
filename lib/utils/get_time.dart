import 'dart:async'; // For Timer and asynchronous operations
import 'dart:convert'; // For decoding JSON responses from the API

import 'package:flutter/foundation.dart'; // For ChangeNotifier and kDebugMode
import 'package:http/http.dart'; // For making HTTP requests

///////////////////////////////////////////////////////////////
// A singleton service that fetches and maintains the current time
// from an online API, and updates it periodically.
//
// Uses [ChangeNotifier] so that widgets can listen for updates.

class TimeService with ChangeNotifier {
  // --- Singleton setup ---
  static final TimeService _instance =
      TimeService._internal(); // Single instance
  factory TimeService() =>
      _instance; // Factory constructor returns the same instance

  // --- State variables ---
  DateTime? timeNow; // Holds the current time
  Duration timeUpdateInterval = Duration(
    minutes: 1,
  ); // How often to update time
  Timer? _clockTimer; // Timer for periodic updates

  // Private constructor for singleton
  TimeService._internal() {
    // Start automatic updates when the service is created
    _startTimer();
  }

  ///////////////////////////////////////////////////////////////
  // Fetches the current time from the API and updates [timeNow].
  // Notifies listeners when the time changes.

  Future<DateTime?> getTime() async {
    try {
      // API endpoint for Singapore time (timeapi.io)
      final uri = Uri.parse(
        'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE',
      );
      // Alternative API (commented out):
      // final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');

      // Make GET request to the API
      final response = await get(uri);

      if (kDebugMode) {
        print("Printing response: $response");
      }

      // If request was successful
      if (response.statusCode == 200) {
        // Decode JSON response into a Map
        Map<String, dynamic> data = jsonDecode(response.body);

        // Extract the datetime string (timeapi.io uses 'dateTime' key)
        String datetime = data['dateTime'];

        // Parse the datetime string into a DateTime object
        timeNow = DateTime.parse(datetime);

        if (kDebugMode) {
          print("Updated Time: $timeNow");
        }

        // Notify any listeners (e.g., widgets) that the time has changed
        notifyListeners();

        return timeNow;
      } else {
        // If request failed, log the status code
        if (kDebugMode) {
          print(
            "Failed to get time data from the API. Status Code: ${response.statusCode}",
          );
        }
      }
    } catch (e) {
      // Catch and log any errors during the request or parsing
      if (kDebugMode) {
        print('Caught error: $e');
      }
    }
    return null; // Return null if time could not be fetched
  }

  ///////////////////////////////////////////////////////////////
  // Starts a periodic timer that updates the time.
  // Calls [updateTimeManually] every [timeUpdateInterval],
  // and fetches fresh time from the API at the same interval.

  void _startTimer() {
    _clockTimer = Timer.periodic(timeUpdateInterval, (timer) {
      // Increment the stored time manually
      updateTimeManually();

      // Every full interval, fetch the actual time from the API
      if (timer.tick % (timeUpdateInterval.inMinutes) == 0) {
        getTime();
      }
    });
  }

  ///////////////////////////////////////////////////////////////
  // Manually increments [timeNow] by [timeUpdateInterval].
  // Useful between API fetches to keep the clock moving.

  void updateTimeManually() {
    if (timeNow != null) {
      // Add the interval to the current time
      timeNow = timeNow!.add(timeUpdateInterval);

      if (kDebugMode) {
        print("Manually updated time: $timeNow");
      }

      // Notify listeners that the time has changed
      notifyListeners();
    } else {
      // If timeNow is null, log a warning in debug mode
      if (kDebugMode) {
        print("Time is null, please fetch the time first.");
      }
    }
  }

  ///////////////////////////////////////////////////////////////
  // Cancels the timer when the service is disposed.

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
