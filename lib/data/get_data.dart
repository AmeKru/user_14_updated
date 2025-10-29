import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

////////////////////////////////////////////////////////////////////////////////

/// ////////////////////////////////////////////////////////////////////////////
/// --- Get Data From AWS (NOW: Using polling, checks every time interval that is set) ---
/// (Make server automatically push changes, if any were made)
///  ///////////////////////////////////////////////////////////////////////////

// Keep the singleton pattern but extend ChangeNotifier
class BusData extends ChangeNotifier {
  static final BusData _instance = BusData._internal();
  factory BusData() => _instance;
  BusData._internal();

  // Public read-only lists (still mutable but replaced atomically)
  final List<DateTime> arrivalTimeKAP = [];
  final List<DateTime> arrivalTimeCLE = [];
  final List<DateTime> departureTimeKAP = [];
  final List<DateTime> departureTimeCLE = [];
  final List<String> busStop = [];
  String news = '';
  bool isDataLoaded = false;

  // Polling timer
  Timer? _pollTimer;
  Duration pollInterval = const Duration(seconds: 30);
  bool _loadingInProgress = false;

  // --- Change emission controls ---
  String? _lastEmissionSignature;
  Timer? _notifyDebounce;

  //////////////////////////////////////////////////////////////////////////////

  /// //////////////////////////////////////////////////////////////////////////
  /// ---  Helper fetch methods that returns selected Data on the Server ---
  ///  /////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of DateTime with all Trip times for KAP Morning

  Future<List<DateTime>> _fetchTripTimesMorningKAP() async {
    final List<DateTime> loaded = [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=KAP_MorningBus',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      final List<dynamic> times = data['times'] ?? [];
      for (var time in times) {
        final timeStr = time['time'] as String;
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        loaded.add(
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
      if (kDebugMode) print('fetchTripTimesMorningKAP error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of DateTime with all Trip times for CLE Morning

  Future<List<DateTime>> _fetchTripTimesMorningCLE() async {
    final List<DateTime> loaded = [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=CLE_MorningBus',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      final List<dynamic> times = data['times'] ?? [];
      for (var time in times) {
        final timeStr = time['time'] as String;
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        loaded.add(
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
      if (kDebugMode) print('fetchTripTimesMorningCLE error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of DateTime with all Trip times for KAP Afternoon

  Future<List<DateTime>> _fetchTripTimesAfternoonKAP() async {
    final List<DateTime> loaded = [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=KAP_AfternoonBus',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      final List<dynamic> times = data['times'] ?? [];
      for (var time in times) {
        final timeStr = time['time'] as String;
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        loaded.add(
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
      if (kDebugMode) print('fetchTripTimesAfternoonKAP error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of DateTime with all Trip times for CLE Afternoon

  Future<List<DateTime>> _fetchTripTimesAfternoonCLE() async {
    final List<DateTime> loaded = [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=CLE_AfternoonBus',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      final List<dynamic> times = data['times'] ?? [];
      for (var time in times) {
        final timeStr = time['time'] as String;
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        loaded.add(
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
      if (kDebugMode) print('fetchTripTimesAfternoonCLE error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches a List of String of the Bus Stop Names

  Future<List<String>> _fetchBusStops() async {
    final List<String> loaded = [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/busstop?info=BusStops',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      final List<dynamic> positions = data['positions'] ?? [];
      for (var position in positions) {
        final id = position['id'] as String;
        loaded.add(id);
      }
    } catch (e) {
      if (kDebugMode) print('fetchBusStops error: $e');
    }
    return loaded;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Fetches the Announcement

  Future<String> _fetchAnnouncements() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/news?info=News',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body);
      return data['news'] as String? ?? '';
    } catch (e) {
      if (kDebugMode) print('fetchAnnouncements error: $e');
      return '';
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  /// //////////////////////////////////////////////////////////////////////////
  /// ---  Atomic load method that updates public lists and notifies ---
  ///  /////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////

  Future<void> _loadAll() async {
    if (_loadingInProgress) return;
    _loadingInProgress = true;
    try {
      final results = await Future.wait([
        _fetchTripTimesMorningKAP(),
        _fetchTripTimesMorningCLE(),
        _fetchTripTimesAfternoonKAP(),
        _fetchTripTimesAfternoonCLE(),
        _fetchBusStops(),
        _fetchAnnouncements(),
      ]);

      final List<DateTime> newArrivalKAP = results[0] as List<DateTime>;
      final List<DateTime> newArrivalCLE = results[1] as List<DateTime>;
      final List<DateTime> newDepartureKAP = results[2] as List<DateTime>;
      final List<DateTime> newDepartureCLE = results[3] as List<DateTime>;
      final List<String> newBusStops = results[4] as List<String>;
      final String newNews = results[5] as String;

      // Replace content atomically
      arrivalTimeKAP
        ..clear()
        ..addAll(newArrivalKAP);
      arrivalTimeCLE
        ..clear()
        ..addAll(newArrivalCLE);
      departureTimeKAP
        ..clear()
        ..addAll(newDepartureKAP);
      departureTimeCLE
        ..clear()
        ..addAll(newDepartureCLE);
      busStop
        ..clear()
        ..addAll(newBusStops);
      news = newNews;
      isDataLoaded = true;

      // Notify listeners once after full replacement
      // Only notify if data actually changed (signature comparison)
      final signature = _buildSignature(
        arrivalTimeKAP,
        arrivalTimeCLE,
        departureTimeKAP,
        departureTimeCLE,
        busStop,
        news,
      );
      if (signature != _lastEmissionSignature) {
        _lastEmissionSignature = signature;

        // Short debounce to prevent multiple notifications within a tight window
        _notifyDebounce?.cancel();
        _notifyDebounce = Timer(const Duration(milliseconds: 150), () {
          notifyListeners();
        });
      }
    } catch (e) {
      if (kDebugMode) print('BusData _loadAll error: $e');
    } finally {
      _loadingInProgress = false;
    }
  }

  // Build a lightweight signature from lengths and edges to avoid heavy deep-equality
  String _buildSignature(
    List<DateTime> aKAP,
    List<DateTime> aCLE,
    List<DateTime> dKAP,
    List<DateTime> dCLE,
    List<String> stops,
    String newsText,
  ) {
    DateTime? edge(List<DateTime> l) => l.isEmpty ? null : l.first;
    DateTime? tail(List<DateTime> l) => l.isEmpty ? null : l.last;
    String? sEdge(List<String> l) => l.isEmpty ? null : l.first;
    String? sTail(List<String> l) => l.isEmpty ? null : l.last;

    return [
      aKAP.length,
      aCLE.length,
      dKAP.length,
      dCLE.length,
      stops.length,
      edge(aKAP)?.millisecondsSinceEpoch,
      tail(aKAP)?.millisecondsSinceEpoch,
      edge(aCLE)?.millisecondsSinceEpoch,
      tail(aCLE)?.millisecondsSinceEpoch,
      edge(dKAP)?.millisecondsSinceEpoch,
      tail(dKAP)?.millisecondsSinceEpoch,
      edge(dCLE)?.millisecondsSinceEpoch,
      tail(dCLE)?.millisecondsSinceEpoch,
      sEdge(stops),
      sTail(stops),
      newsText.hashCode,
    ].join('|');
  }

  //////////////////////////////////////////////////////////////////////////////
  // Public method to perform a one-shot load

  Future<void> loadData() async {
    await _loadAll();
  }

  //////////////////////////////////////////////////////////////////////////////

  /// //////////////////////////////////////////////////////////////////////////
  /// --- Polling control---
  ///  /////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////

  void startPolling({Duration? interval}) {
    if (interval != null) pollInterval = interval;
    _pollTimer?.cancel();

    // Immediately run a load, then schedule periodic loads
    // Ensure we don’t overlap the immediate load with the first timer tick
    _loadAll().whenComplete(() {
      _pollTimer = Timer.periodic(pollInterval, (_) async {
        await _loadAll();
      });
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _notifyDebounce?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
