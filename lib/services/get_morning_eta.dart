import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/utils/get_time.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

//////////////////////////////////////////////////////////////
// Utility class for calculating and displaying morning bus ETAs.

class CalculateMorningBus {
  //////////////////////////////////////////////////////////////
  // Builds a styled card widget showing either:
  // - A static message (`text`), OR
  // - An ETA message if `eta` is provided.

  static Widget buildMorningETADisplay(
    BuildContext context,
    String text, {
    String eta = '',
  }) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: TextSizing.fontSizeText(context) * 0.5,
              height: TextSizing.fontSizeText(context) * 4,
              color: eta.isNotEmpty
                  ? (isDarkMode ? Colors.cyanAccent : Color(0xff014689))
                  : (isDarkMode ? Colors.blueGrey[700] : Colors.grey[400]),
            ),
            Card(
              color: eta.isNotEmpty
                  ? (isDarkMode ? Colors.blueGrey[600] : Colors.blue[50])
                  : (isDarkMode ? Colors.blueGrey[800] : Colors.grey[300]),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0.0),
              ),
              elevation: 0,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Padding(
                  padding: EdgeInsets.all(TextSizing.fontSizeText(context)),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_bus,
                        size: TextSizing.fontSizeHeading(context),
                        color: eta.isNotEmpty
                            ? (isDarkMode ? Colors.cyanAccent : Colors.black)
                            : (isDarkMode
                                  ? Colors.blueGrey[300]
                                  : Colors.grey[600]),
                      ),
                      Text(
                        eta.isNotEmpty ? '$text $eta minutes' : text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: TextSizing.fontSizeText(context),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          color: eta.isNotEmpty
                              ? (isDarkMode ? Colors.white : Colors.black)
                              : (isDarkMode
                                    ? Colors.blueGrey[300]
                                    : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: TextSizing.fontSizeText(context) * 0.5,
              height: TextSizing.fontSizeText(context) * 4,
              color: eta.isNotEmpty
                  ? (isDarkMode ? Colors.cyanAccent : Color(0xff014689))
                  : (isDarkMode ? Colors.blueGrey[700] : Colors.grey[400]),
            ),
          ],
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

  static Widget getMorningETA(
    List<DateTime> busArrivalTimes,
    BuildContext context,
  ) {
    final timeService = TimeService();
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
        buildMorningETADisplay(context, 'No upcoming buses available.');

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
        : ' ';

    return Column(
      children: [
        buildMorningETADisplay(context, 'Upcoming bus:', eta: upcomingBus),
        (selectedMRT == 1)
            ? (nextUpcomingBus == ' ')
                  ? noBusCard()
                  : buildMorningETADisplay(
                      context,
                      'Next bus:',
                      eta: nextUpcomingBus,
                    )
            : SizedBox(),
      ],
    );
  }
}

//////////////////////////////////////////////////////////////
// Live-updating wrapper for [CalculateMorningBus.getMorningETA],
// synced to the start of each minute so the countdown stays accurate.

class GetMorningETA extends StatefulWidget {
  final List<DateTime> busArrivalTimes;

  const GetMorningETA(this.busArrivalTimes, {super.key});

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

  @override
  void didUpdateWidget(covariant GetMorningETA oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the provided list changed (added/removed trips), trigger a rebuild
    final oldList = oldWidget.busArrivalTimes;
    final newList = widget.busArrivalTimes;
    if (!_listsEqual(oldList, newList)) {
      // Re-schedule to ensure timer alignment remains correct
      _timer?.cancel();
      _scheduleNextMinuteTick();
      if (mounted) setState(() {});
    }
  }

  //////////////////////////////////////////////////////////////
  // Schedules the first update exactly at the start of the next minute,
  // then switches to a periodic 1-minute timer.

  void _scheduleNextMinuteTick() {
    // Cancel any existing timer
    _timer?.cancel();

    final now = DateTime.now();
    final msUntilNextMinute =
        60000 - (now.second * 1000 + now.millisecond); // ms to next minute

    // Edge case: if msUntilNextMinute is 0 or negative, schedule immediate tick
    final initialDelay = Duration(
      milliseconds: msUntilNextMinute > 0 ? msUntilNextMinute : 0,
    );

    // Wait until the next minute starts
    Future.delayed(initialDelay, () {
      if (!mounted) return;
      setState(() {});

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
    return Column(
      children: [
        // Text above ETA
        Text(
          'Bus to NP Campus',
          softWrap: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: TextSizing.fontSizeHeading(context),
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          selectedMRT == 1
              ? 'Departure times from King Albert Park'
              : 'Departure times from Clementi',
          softWrap: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: TextSizing.fontSizeText(context),
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: TextSizing.fontSizeText(context)),

        // ETA displays
        CalculateMorningBus.getMorningETA(widget.busArrivalTimes, context),
      ],
    );
  }

  // helper to compare DateTime lists
  bool _listsEqual(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
