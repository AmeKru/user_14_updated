import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceService {
  static const String bookingDataKey = 'bookingData';

  // Save booking data
  Future<void> saveBookingData(selectedBox, bookedTripIndexKAP, bookedTripIndexCLE, busStop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedBox', selectedBox);
    await prefs.setInt('bookedTripIndexKAP', bookedTripIndexKAP ?? -1);
    await prefs.setInt('bookedTripIndexCLE', bookedTripIndexCLE ?? -1);
    await prefs.setString('busStop', busStop );
  }

  // Retrieve booking data
  Future<Map<String, dynamic>?> getBookingData() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch stored values from SharedPreferences
    int? selectedBox = prefs.getInt('selectedBox');
    int? bookedTripIndexKAP = prefs.getInt('bookedTripIndexKAP');
    int? bookedTripIndexCLE = prefs.getInt('bookedTripIndexCLE');
    String? busStop = prefs.getString('busStop');

    // Check if any of the required values are missing
    if (selectedBox != null && busStop != null) {
      // Create a map to return the values
      return {
        'selectedBox': selectedBox,
        'bookedTripIndexKAP': bookedTripIndexKAP == -1 ? null : bookedTripIndexKAP, // Handle the null value using -1
        'bookedTripIndexCLE': bookedTripIndexCLE == -1 ? null : bookedTripIndexCLE, // Handle the null value using -1
        'busStop': busStop,
      };
    } else {
      // If the data is incomplete or missing, return null
      return null;
    }
  }
  Future<void> clearBookingData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Clear all data
    await prefs.clear();

    // Verify that all keys are removed
    bool isSelectedBoxRemoved = prefs.getInt('selectedBox') == null;
    await prefs.remove('selectedBox');
    bool isBookedTripIndexKAPRemoved = prefs.getInt('bookedTripIndexKAP') == null;
    bool isBookedTripIndexCLERemoved = prefs.getInt('bookedTripIndexCLE') == null;
    bool isBusStopRemoved = prefs.getString('busStop') == null;

    print('Clearing saved booking Data');
    print('selectedBox removed: $isSelectedBoxRemoved');
    print('bookedTripIndexKAP removed: $isBookedTripIndexKAPRemoved');
    print('bookedTripIndexCLE removed: $isBookedTripIndexCLERemoved');
    print('busStop removed: $isBusStopRemoved');
  }

}



