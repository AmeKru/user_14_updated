import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

///////////////////////////////////////////////////////////////
// A service class to handle saving, retrieving, and clearing
// booking-related data using [SharedPreferences].
//
// This allows the app to persist small pieces of data locally
//  so they remain available between app launches.

class SharedPreferenceService {
  // Key constant for saving DarkMode
  static const String _kDarkMode = 'darkMode';

  // Key constants for saving booking
  static const String _kBookingID = 'bookingID';
  static const String _kSelectedBox = 'selectedBox';
  static const String _kBookedTripIndexKAP = 'bookedTripIndexKAP';
  static const String _kBookedTripIndexCLE = 'bookedTripIndexCLE';
  static const String _kBusStop = 'busStop';
  static const String _kBusIndex = 'busIndex';
  static const String _kBookedDepartureTime = 'bookedDepartureTime';

  // Cache SharedPreferences instance to reduce async churn
  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  ///////////////////////////////////////////////////////////////
  // Save/load dark Mode, so user does not have to turn it one every time
  // the App reopens

  Future<void> saveDarkMode(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_kDarkMode, value);
  }

  Future<bool> loadDarkMode() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_kDarkMode) ?? false;
  }

  ///////////////////////////////////////////////////////////////
  // Saves booking data to [SharedPreferences].
  //
  // Expected keys:
  // - 'bookingID' String?
  // - 'selectedBox' int
  // - 'bookedTripIndexKAP' int?
  // - 'bookedTripIndexCLE' int?
  // - 'busStop' String?
  // - 'BusIndex' int
  // - 'bookedDepartureTime' String? (ISO)
  //
  // Validate-then-write: only commit if all required keys are present and valid
  // Returns true on success, false if validation failed (no writes performed)

  Future<bool> saveBookingData(Map<String, dynamic> data) async {
    final requiredSpec = <String, Type>{
      'bookingID': String,
      'selectedBox': int,
      'busStop': String,
      'busIndex': int,
      'bookedDepartureTime': DateTime,
    };

    for (final entry in requiredSpec.entries) {
      final key = entry.key;
      final expected = entry.value;

      if (!data.containsKey(key)) {
        if (kDebugMode) print('saveBookingData: missing key $key');
        return false;
      }

      final val = data[key];
      if (val == null) {
        if (kDebugMode) print('saveBookingData: null for key $key');
        return false;
      }

      final isTypeMatch =
          (expected == int && val is int) ||
          (expected == String && val is String) ||
          (expected == double && val is double) ||
          (expected == bool && val is bool) ||
          (expected == DateTime && val is DateTime);

      if (!isTypeMatch) {
        if (kDebugMode) {
          print('saveBookingData: wrong type for $key, got ${val.runtimeType}');
        }
        return false;
      }
    }

    final prefs = await _getPrefs();

    try {
      if (kDebugMode) {
        print('Saving booking data: $data');
      }

      await prefs.setString(_kBookingID, data['bookingID'] as String);
      await prefs.setInt(_kSelectedBox, data['selectedBox'] as int);

      if (data['bookedTripIndexKAP'] != null) {
        await prefs.setInt(
          _kBookedTripIndexKAP,
          data['bookedTripIndexKAP'] as int,
        );
      } else {
        await prefs.remove(_kBookedTripIndexKAP);
      }

      if (data['bookedTripIndexCLE'] != null) {
        await prefs.setInt(
          _kBookedTripIndexCLE,
          data['bookedTripIndexCLE'] as int,
        );
      } else {
        await prefs.remove(_kBookedTripIndexCLE);
      }

      await prefs.setString(_kBusStop, data['busStop'] as String);
      await prefs.setInt(_kBusIndex, data['busIndex'] as int);

      // safe DateTime handling: cast then store ISO in UTC
      final dt = data['bookedDepartureTime'] as DateTime;
      final isoUtc = dt.toUtc().toIso8601String();
      await prefs.setString(_kBookedDepartureTime, isoUtc);

      return true;
    } catch (e) {
      if (kDebugMode) print('saveBookingData: commit failed: $e');
      return false;
    }
  }

  ///////////////////////////////////////////////////////////////
  // Retrieves booking data from [SharedPreferences].
  //
  // Returns a `Map<String, dynamic>` containing:
  // - `selectedBox`
  // - `bookedTripIndexKAP` (null if no booking)
  // - `bookedTripIndexCLE` (null if no booking)
  // - `busStop`
  // - `bookingID`
  // - `bookedDepartureTime`
  // - `bookedDirection`
  //
  // Returns `null` if required data is missing.

  Future<Map<String, dynamic>?> getBookingData() async {
    final prefs = await _getPrefs();

    final String? bookingID = prefs.getString(_kBookingID);
    final int? selectedBox = prefs.getInt(_kSelectedBox);
    final int? bookedTripIndexKAP = prefs.getInt(_kBookedTripIndexKAP);
    final int? bookedTripIndexCLE = prefs.getInt(_kBookedTripIndexCLE);
    final String? busStop = prefs.getString(_kBusStop);
    final int? busIndex = prefs.getInt(_kBusIndex);
    final String? bookedDepartureTime = prefs.getString(_kBookedDepartureTime);

    // If no station chosen at all, treat as "no booking"
    if (selectedBox == null || selectedBox == 0) {
      if (kDebugMode) print('Loaded booking data: none (no station selected)');
      return null;
    }

    // Allow partial state so UI can render BookingService without flipping to null.
    // If there is a bookingID, treat as a confirmed booking snapshot.
    // If not, return partial state to continue selection flow.

    DateTime? bookedDepartureParsed;
    if (bookedDepartureTime != null && bookedDepartureTime.isNotEmpty) {
      try {
        // Parse ISO (stored in UTC). Convert to UTC+8 for returned value.
        // Stored value was saved as dt.toUtc().toIso8601String()
        final parsed = DateTime.parse(bookedDepartureTime);
        // Ensure we work from UTC then add 8 hours to get UTC+8 for Singapore time
        final parsedUtc = parsed.isUtc ? parsed : parsed.toUtc();
        bookedDepartureParsed = parsedUtc.add(const Duration(hours: 8));
      } catch (_) {
        bookedDepartureParsed = null; // invalid format => treat as missing
      }
    }

    final result = {
      'bookingID': bookingID,
      'selectedBox': selectedBox,
      'bookedTripIndexKAP': bookedTripIndexKAP,
      'bookedTripIndexCLE': bookedTripIndexCLE,
      'busStop': busStop,
      'busIndex': busIndex,
      'bookedDepartureTime': bookedDepartureParsed,
    };

    if (kDebugMode) {
      print('Loaded booking data: $result');
    }

    return result;
  }

  ///////////////////////////////////////////////////////////////
  // Clears all booking data from [SharedPreferences].
  //
  // Removes only booking-related keys to avoid wiping unrelated preferences.
  // Also logs the removal status of each key in debug mode.
  Future<bool> clearBookingData() async {
    try {
      final prefs = await _getPrefs();

      await Future.wait([
        prefs.remove(_kBookingID),
        prefs.remove(_kBookedDepartureTime),
        prefs.remove(_kBookedTripIndexKAP),
        prefs.remove(_kBookedTripIndexCLE),
        prefs.remove(_kSelectedBox),
        prefs.remove(_kBusStop),
        prefs.remove(_kBusIndex),
      ]);

      // verify
      final ok =
          prefs.getInt(_kSelectedBox) == null &&
          prefs.getInt(_kBookedTripIndexKAP) == null &&
          prefs.getInt(_kBookedTripIndexCLE) == null &&
          prefs.getString(_kBusStop) == null &&
          prefs.getString(_kBookingID) == null &&
          prefs.getString(_kBookedDepartureTime) == null &&
          prefs.getInt(_kBusIndex) == null;

      if (kDebugMode) {
        print('Clearing saved booking Data; success: $ok');
        print('Current values after clear:');
        print('  bookingID: ${prefs.getString(_kBookingID)}');
        print(
          '  bookedDepartureTime: ${prefs.getString(_kBookedDepartureTime)}',
        );
        print('  bookedTripIndexKAP: ${prefs.getInt(_kBookedTripIndexKAP)}');
        print('  bookedTripIndexCLE: ${prefs.getInt(_kBookedTripIndexCLE)}');
        print('  selectedBox: ${prefs.getInt(_kSelectedBox)}');
        print('  busStop: ${prefs.getString(_kBusStop)}');
        print('  busIndex: ${prefs.getInt(_kBusIndex)}');
      }

      return ok;
    } catch (e) {
      if (kDebugMode) print('clearBookingData failed: $e');
      return false;
    }
  }
}
