import 'dart:async';
import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Get Data From AWS ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Keep the singleton pattern but extend ChangeNotifier

class BusData extends ChangeNotifier {
  static final BusData _instance = BusData._internal();
  factory BusData() => _instance;
  BusData._internal();

  // Public read-only lists (still mutable but replaced atomically)
  final List<DateTime> morningTimesKAP = [];
  final List<DateTime> morningTimesCLE = [];
  final List<DateTime> afternoonTimesKAP = [];
  final List<DateTime> afternoonTimesCLE = [];
  final List<String> busStop = [];
  String announcements = '';
  bool isDataLoaded = false;

  // just so can change when sub of countTripList is informed of change and notify listeners can be called
  int countTrip = 0;

  // To prevent multiple calls at once
  bool _loadingInProgress = false;
  Timer? _notifyDebounce;

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// ---  Helper fetch methods that returns selected Data on the Server ---
  ///  /////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of DateTime with all Trip times for a given station + timeOfDay
  // Results are sorted chronologically by DepartureTime

  Future<List<DateTime>> fetchTripTimes({
    required String station,
    required String timeOfDay, // "MORNING" or "AFTERNOON"
  }) async {
    final List<DateTime> loaded = [];
    try {
      const graphQLDocument = '''
      query ListTrips(\$station: String!, \$timeOfDay: TripTimeOfDay!) {
        listTripLists(
          filter: {
            and: [
              { MRTStation: { eq: \$station } }
              { TripTime: { eq: \$timeOfDay } }
            ]
          }
        ) {
          items {
            TripNo
            DepartureTime
          }
        }
      }
    ''';

      final request = GraphQLRequest<String>(
        document: graphQLDocument,
        variables: {
          'station': station,
          'timeOfDay':
              timeOfDay, // must be enum string: "MORNING" or "AFTERNOON"
        },
        authorizationMode: APIAuthorizationType.iam, // unauth read
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.data != null) {
        final data = jsonDecode(response.data!);
        final List<dynamic> items = data['listTripLists']['items'] ?? [];

        // Sort items by TripNo
        items.sort((a, b) {
          final aNo = a['TripNo'] as int? ?? 0;
          final bNo = b['TripNo'] as int? ?? 0;
          return aNo.compareTo(bNo);
        });

        for (var item in items) {
          final departureStr = item['DepartureTime'] as String;

          // Parse into UTC
          final departureUtc = DateTime.parse(departureStr);

          // Convert to Singapore time (UTC+8)
          final departureSingapore = departureUtc.add(const Duration(hours: 8));

          loaded.add(departureSingapore);
        }
      }
    } catch (e) {
      safePrint('fetchTripTimes error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of String of the Bus Stop Names

  Future<List<String>> fetchBusStops() async {
    final List<String> loaded = [];
    try {
      const graphQLDocument = '''
      query ListBusStops {
        listBusStops {
          items {
            id
            BusStop
            StopNo
          }
        }
      }
    ''';

      final request = GraphQLRequest<String>(
        document: graphQLDocument,
        authorizationMode: APIAuthorizationType.iam,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.data != null) {
        final data = jsonDecode(response.data!);
        final List<dynamic> items = data['listBusStops']['items'] ?? [];

        // Sort items by StopNo
        items.sort((a, b) {
          final aNo = a['StopNo'] as int? ?? 0;
          final bNo = b['StopNo'] as int? ?? 0;
          return aNo.compareTo(bNo);
        });

        for (var item in items) {
          final busStop = item['BusStop'] as String;
          loaded.add(busStop);
        }
      }
    } catch (e) {
      safePrint('fetchBusStops error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches the Announcement

  Future<String> fetchAnnouncements() async {
    try {
      const graphQLDocument = '''
      query ListAnnouncements {
        listAnnouncements {
          items {
            Announcement
          }
        }
      }
    ''';

      final request = GraphQLRequest<String>(
        document: graphQLDocument,
        // Force unauthorized app to use Identity Pool (IAM) auth
        authorizationMode: APIAuthorizationType.iam,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.data != null) {
        final data = jsonDecode(response.data!);
        final List<dynamic> items = data['listAnnouncements']['items'] ?? [];

        if (items.isNotEmpty) {
          return items.first['Announcement'] as String? ?? '';
        }
      }
    } catch (e) {
      safePrint('fetchAnnouncements error: $e');
    }
    return '';
  }

  //////////////////////////////////////////////////////////////////////////////
  /// --- Atomic load method that updates public lists and notifies ---
  //////////////////////////////////////////////////////////////////////////////

  Future<void> _loadAll() async {
    if (_loadingInProgress) return;
    _loadingInProgress = true;
    try {
      // Fix #4: add timeout to prevent indefinite hang
      final results = await Future.wait([
        fetchTripTimes(station: 'KAP', timeOfDay: 'MORNING'),
        fetchTripTimes(station: 'CLE', timeOfDay: 'MORNING'),
        fetchTripTimes(station: 'KAP', timeOfDay: 'AFTERNOON'),
        fetchTripTimes(station: 'CLE', timeOfDay: 'AFTERNOON'),
        fetchBusStops(),
        fetchAnnouncements(),
      ], eagerError: true).timeout(const Duration(seconds: 15));

      // Fix #6: safer casting with type checks
      final newMorningTimesKAP = (results[0] as List<DateTime>? ?? []);
      final newMorningTimesCLE = (results[1] as List<DateTime>? ?? []);
      final newAfternoonTimesKAP = (results[2] as List<DateTime>? ?? []);
      final newAfternoonTimesCLE = (results[3] as List<DateTime>? ?? []);
      final newBusStops = (results[4] as List<String>? ?? []);
      final newAnnouncements = (results[5] as String? ?? '');

      if (kDebugMode) {
        print('loadAll in get_data: Announcements: $newAnnouncements');
      }

      // Replace content atomically
      morningTimesKAP
        ..clear()
        ..addAll(newMorningTimesKAP);
      morningTimesCLE
        ..clear()
        ..addAll(newMorningTimesCLE);
      afternoonTimesKAP
        ..clear()
        ..addAll(newAfternoonTimesKAP);
      afternoonTimesCLE
        ..clear()
        ..addAll(newAfternoonTimesCLE);
      busStop
        ..clear()
        ..addAll(newBusStops);
      announcements = newAnnouncements;
      isDataLoaded = true;

      // Short debounce to prevent multiple notifications within a tight window
      _notifyDebounce?.cancel();
      _notifyDebounce = Timer(const Duration(milliseconds: 150), () {
        // notify listeners of change
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) print('BusData _loadAll error: $e');
    } finally {
      _loadingInProgress = false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Public method to perform a one-shot load
  //////////////////////////////////////////////////////////////////////////////

  Future<void> loadData() async {
    await _loadAll();
  }

  //////////////////////////////////////////////////////////////////////////////
  // Dispose timer and subscriptions properly
  //////////////////////////////////////////////////////////////////////////////

  @override
  void dispose() {
    _notifyDebounce?.cancel();
    super.dispose();
  }
}
