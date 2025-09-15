import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/utils/get_time.dart';

//////////////////////////////////////////////////////////////
// Utility class for calculating and displaying morning bus ETAs.

class CalculateMorningBus {
  //////////////////////////////////////////////////////////////
  // Builds a styled card widget showing either:
  // - A static message (`text`), OR
  // - An ETA message if `ETA` is provided.

  static Widget buildMorningETADisplay(
    String text,
    bool isDarkMode, {
    String ETA = '',
  }) {
    return SizedBox(
      width: 350,
      child: Card(
        color: ETA.isNotEmpty
            ? (isDarkMode ? Colors.blueGrey[700] : const Color(0xff014689))
            : (isDarkMode ? Colors.blueGrey[800] : Colors.grey[300]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.0)),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Icon(
                Icons.directions_bus,
                color: ETA.isNotEmpty
                    ? (isDarkMode ? Colors.blueGrey[50] : Colors.black)
                    : (isDarkMode ? Colors.blueGrey[200] : Colors.grey[600]),
              ),
              Text(
                ETA.isNotEmpty ? '$text $ETA minutes' : text,
                style: TextStyle(
                  fontSize: 15.0,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                  color: ETA.isNotEmpty
                      ? (isDarkMode ? Colors.blueGrey[50] : Colors.black)
                      : (isDarkMode ? Colors.blueGrey[200] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  // Calculates and returns a widget displaying the upcoming bus ETAs.
  //
  // - Uses [TimeService] to get the current time (or system time if unavailable).
  // - Filters the provided [busArrivalTimes] to only include times after now.
  // - Displays:
  //   - "No upcoming buses available" if none remain.
  //   - The next bus ETA (and second next if `selectedMRT == 1`).

  static Widget getMorningETA(List<DateTime> busArrivalTimes, bool darkMode) {
    final timeService = TimeService();
    final isDarkMode =
        darkMode; // CHANGED: explicitly store darkMode in local var
    DateTime currentTime = timeService.timeNow ?? DateTime.now();

    // Truncate seconds for minute-level comparison
    currentTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      currentTime.hour,
      currentTime.minute,
    );

    if (kDebugMode) {
      print('Current Time: $currentTime');
      print('Bus Timing List: $busArrivalTimes');
    }

    // Filter to only upcoming bus times
    final upcomingArrivalTimes = busArrivalTimes
        .where((time) => time.isAfter(currentTime))
        .toList();

    // Helper to build "no buses" message
    Widget noBusCard() =>
        buildMorningETADisplay('No upcoming buses available.', isDarkMode);

    // Helper to calculate minutes until a bus
    String minutesUntil(DateTime time) =>
        time.difference(currentTime).inMinutes.toString();

    // CASE 1: No upcoming buses
    if (upcomingArrivalTimes.isEmpty) {
      return Column(
        children: selectedMRT == 1 ? [noBusCard(), noBusCard()] : [noBusCard()],
      );
    }

    // CASE 2: At least one upcoming bus
    final upcomingBus = minutesUntil(upcomingArrivalTimes[0]);
    final nextUpcomingBus = (upcomingArrivalTimes.length > 1)
        ? minutesUntil(upcomingArrivalTimes[1])
        : ' - ';

    return Column(
      children: [
        buildMorningETADisplay('Upcoming bus:', ETA: upcomingBus, isDarkMode),
        if (selectedMRT == 1)
          buildMorningETADisplay('Next bus:', ETA: nextUpcomingBus, isDarkMode),
      ],
    );
  }
}

//////////////////////////////////////////////////////////////
// Live-updating wrapper for [CalculateMorningBus.getMorningETA],
// synced to the start of each minute so the countdown stays accurate.

class GetMorningETA extends StatefulWidget {
  final List<DateTime> busArrivalTimes;

  // CHANGED: Added isDarkMode parameter so we can pass it down to CalculateMorningBus
  final bool isDarkMode; // CHANGED: new field

  const GetMorningETA(
    this.busArrivalTimes, {
    super.key,
    required this.isDarkMode,
  }); // CHANGED: require isDarkMode

  @override
  State<GetMorningETA> createState() => _GetMorningETAState();
}

class _GetMorningETAState extends State<GetMorningETA> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextMinuteTick();
  }

  //////////////////////////////////////////////////////////////
  // Schedules the first update exactly at the start of the next minute,
  // then switches to a periodic 1-minute timer.

  void _scheduleNextMinuteTick() {
    final now = DateTime.now();
    final msUntilNextMinute =
        60000 - (now.second * 1000 + now.millisecond); // ms to next minute

    // Wait until the next minute starts
    Future.delayed(Duration(milliseconds: msUntilNextMinute), () {
      if (mounted) setState(() {});

      // Then update every minute exactly on the minute
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Clean up timer when widget is removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// CHANGED: Pass widget.isDarkMode to getMorningETA so it can style accordingly
    return CalculateMorningBus.getMorningETA(
      widget.busArrivalTimes,
      widget.isDarkMode, // CHANGED: now passing dark mode flag
    );
  }
}
