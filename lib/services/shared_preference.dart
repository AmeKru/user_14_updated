import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

///////////////////////////////////////////////////////////////
// A service class to handle saving, retrieving, and clearing
// booking-related data using [SharedPreferences].
//
// This allows the app to persist small pieces of data locally
//  so they remain available between app launches.

class SharedPreferenceService {
  // Key for storing booking data (not directly used in this implementation)
  static const String bookingDataKey = 'bookingData';

  ///////////////////////////////////////////////////////////////
  // Saves booking data to [SharedPreferences].
  //
  // - [selectedBox]: The MRT selection (1 = KAP, 2 = CLE)
  // - [bookedTripIndexKAP]: Index of booked trip for KAP (nullable)
  // - [bookedTripIndexCLE]: Index of booked trip for CLE (nullable)
  // - [busStop]: Name of the selected bus stop
  //
  // If a trip index is null, it is stored as -1 to indicate "no booking".

  Future<void> saveBookingData(
    selectedBox,
    bookedTripIndexKAP,
    bookedTripIndexCLE,
    busStop,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Save each value to persistent storage
    await prefs.setInt('selectedBox', selectedBox);
    await prefs.setInt('bookedTripIndexKAP', bookedTripIndexKAP ?? -1);
    await prefs.setInt('bookedTripIndexCLE', bookedTripIndexCLE ?? -1);
    await prefs.setString('busStop', busStop);
  }

  ///////////////////////////////////////////////////////////////
  // Retrieves booking data from [SharedPreferences].
  //
  // Returns a `Map<String, dynamic>` containing:
  // - `selectedBox`
  // - `bookedTripIndexKAP` (null if no booking)
  // - `bookedTripIndexCLE` (null if no booking)
  // - `busStop`
  //
  // Returns `null` if required data is missing or incomplete.

  Future<Map<String, dynamic>?> getBookingData() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch stored values from SharedPreferences
    int? selectedBox = prefs.getInt('selectedBox');
    int? bookedTripIndexKAP = prefs.getInt('bookedTripIndexKAP');
    int? bookedTripIndexCLE = prefs.getInt('bookedTripIndexCLE');
    String? busStop = prefs.getString('busStop');

    // Only return data if the essential fields are present
    if (selectedBox != null && busStop != null) {
      return {
        'selectedBox': selectedBox,
        // Convert -1 back to null for easier handling in the app
        'bookedTripIndexKAP': bookedTripIndexKAP == -1
            ? null
            : bookedTripIndexKAP,
        'bookedTripIndexCLE': bookedTripIndexCLE == -1
            ? null
            : bookedTripIndexCLE,
        'busStop': busStop,
      };
    } else {
      // Data is incomplete or missing
      return null;
    }
  }

  // Clears all booking data from [SharedPreferences].
  //
  // Also logs the removal status of each key in debug mode.
  Future<void> clearBookingData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Clear all stored preferences
    await prefs.clear();

    // Verify that all keys are removed
    bool isSelectedBoxRemoved = prefs.getInt('selectedBox') == null;
    await prefs.remove('selectedBox'); // Redundant after clear(), but explicit
    bool isBookedTripIndexKAPRemoved =
        prefs.getInt('bookedTripIndexKAP') == null;
    bool isBookedTripIndexCLERemoved =
        prefs.getInt('bookedTripIndexCLE') == null;
    bool isBusStopRemoved = prefs.getString('busStop') == null;

    // Debug logging to verify removal
    if (kDebugMode) {
      print('Clearing saved booking Data');
      print('selectedBox removed: $isSelectedBoxRemoved');
      print('bookedTripIndexKAP removed: $isBookedTripIndexKAPRemoved');
      print('bookedTripIndexCLE removed: $isBookedTripIndexCLERemoved');
      print('busStop removed: $isBusStopRemoved');
    }
  }
}
