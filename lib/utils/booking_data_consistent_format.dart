// Class to help unify booking format
// => loaded/saved booking locally will have a different format then the information loaded from server
// => Returns same format for both, easier to work with in afternoon screen

class BookingData {
  final String id; // bookingID
  final String station; // "KAP" or "CLE"
  final int tripIndex; // 0-based index
  final String busStop;
  final int busIndex;
  final DateTime? departure; // can be null when no concrete departure found

  BookingData({
    required this.id,
    required this.station,
    required this.tripIndex,
    required this.busStop,
    required this.busIndex,
    required this.departure,
  });

  /// Construct from locally saved prefs
  factory BookingData.fromPrefs(Map<String, dynamic> data) {
    final id = data['bookingID'] as String;
    final selectedBox = data['selectedBox'] as int;
    final station = selectedBox == 1 ? 'KAP' : 'CLE';

    final tripIndex = selectedBox == 1
        ? (data['bookedTripIndexKAP'] as int?) ?? -1
        : (data['bookedTripIndexCLE'] as int?) ?? -1;

    final busStop = data['busStop'] as String? ?? '';
    final busIndex = data['busIndex'] as int? ?? -1;

    final departure = data['bookedDepartureTime'] is DateTime
        ? data['bookedDepartureTime'] as DateTime
        : null;

    return BookingData(
      id: id,
      station: station,
      tripIndex: tripIndex,
      busStop: busStop,
      busIndex: busIndex,
      departure: departure,
    );
  }

  /// Construct from server booking (BookingDetails.toMap())
  factory BookingData.fromServer(
    Map<String, dynamic> data,
    List<DateTime> departures,
    List<String> busStops,
  ) {
    final id = data['id'] as String;
    final station = data['MRTStation'] as String;
    final tripNo = data['TripNo'] as int; // server gives 1-based
    final tripIndex = tripNo - 1;
    final busStop = data['BusStop'] as String? ?? '';

    // Resolve busIndex by looking up busStop in your busStops list
    final busIndex = busStops.indexOf(busStop);

    final departure = (tripIndex >= 0 && tripIndex < departures.length)
        ? departures[tripIndex]
        : null; // fallback to null

    return BookingData(
      id: id,
      station: station,
      tripIndex: tripIndex,
      busStop: busStop,
      busIndex: busIndex,
      departure: departure,
    );
  }

  Map<String, Object?> toMapExplicit() => {
    'id': id, // String
    'station': station, // String
    'tripIndex': tripIndex, // int
    'busStop': busStop, // String
    'busIndex': busIndex, // int
    'departure': departure, // DateTime? (use Object? to allow null)
  };
}
