import 'dart:async';

import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

//////////////////////////////////////////////////////////////
// Class for Afternoon start point display and helpers

class AfternoonStartPoint {
  // Builds a single row widget showing:
  // - Bus stop name
  // - Time until the upcoming bus
  // - Time until the next bus after that

  static Widget buildRowWidget(
    BuildContext context,
    String busStop, // Name of the bus stop
    int nextBusTimeDiff, // Minutes until the next bus
    int nextNextBusTimeDiff, // Minutes until the bus after the next
    int index, // Index of the bus stop in the list
    double multiplier, // Time increment multiplier per stop
  ) {
    final adjustedNext = (nextBusTimeDiff + (multiplier * (index - 2))).round();
    final adjustedNextNext = nextNextBusTimeDiff < 0
        ? -1
        : (nextNextBusTimeDiff + (multiplier * (index - 1))).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Space in between
            SizedBox(width: MediaQuery.of(context).size.width * 0.02),

            // Vertical coloured line
            Container(
              height: TextSizing.fontSizeText(context) * 2.5,
              width: MediaQuery.of(context).size.width * 0.01,
              color: isDarkMode ? Colors.cyanAccent : Colors.lightBlue[600],
            ),

            // Bus stop name container
            Flexible(child:
            Container(
              width: MediaQuery.of(context).size.width * 0.35,
              color: isDarkMode
                  ? Colors.blueGrey[800]
                  : const Color(0xff014689),
              child: Padding(
                padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
                child: Text(
                  busStop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.cyanAccent : Colors.white,
                    fontSize: TextSizing.fontSizeText(context),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),),
              ),
            ),

            // Space in between
            SizedBox(width: MediaQuery.of(context).size.width * 0.01),

            // Upcoming bus time container
            Flexible(child:
            Container(
              width: MediaQuery.of(context).size.width * 0.275,
              color: isDarkMode ? Colors.blueGrey[600] : Colors.lightBlue[50],
              child: Padding(
                padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
                child: Text(
                  adjustedNext <= 0
                      ? (adjustedNext == 0 ? 'Arr' : '-')
                      : '$adjustedNext',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeText(context),
                    fontFamily: 'Roboto',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),),
              ),
            ),

            // Space in between
            SizedBox(width: MediaQuery.of(context).size.width * 0.01),

            // Next-next bus time container
            Flexible(child:
            Container(
              width: MediaQuery.of(context).size.width * 0.275,
              color: isDarkMode ? Colors.blueGrey[600] : Colors.lightBlue[50],
              child: Padding(
                padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
                child: Text(
                  adjustedNextNext < 0 ? '-' : '$adjustedNextNext',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeText(context),
                    fontFamily: 'Roboto',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),),
            ),

            // Space in between
            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
          ],
        ),

        // Space in between rows
        SizedBox(height: TextSizing.fontSizeText(context) * 0.2),
      ],
    );
  }

  // Returns a widget showing the bus arrival times for a given MRT start point (KAP or CLE)
  // No separate polling here — this method reads BusData state when called by the parent.
  static Widget getBusTime(int box, BuildContext context) {
    final DateTime currentTime = DateTime.now(); // Current time
    final double timeBetweenBusStops =
        2; // minutes per stop multiplier (adjustable)

    final BusData busData = BusData(); // Data source for bus stops and times
    List<DateTime> busArrivalTimes; // Holds the relevant departure times
    final List<String> busStops = busData.busStop; // List of bus stop names

    // Select departure times based on the box value
    if (box == 1) {
      busArrivalTimes = busData.departureTimeKAP;
    } else {
      busArrivalTimes = busData.departureTimeCLE;
    }

    //if (kDebugMode) {
    //  print('AfternoonStartPoint: bus stops: $busStops');
    //  print('AfternoonStartPoint: bus arrival times: $busArrivalTimes');
    //}

    // Filter to keep recent and upcoming times.
    // Keep buses that are after (currentTime - travel buffer)
    final travelBufferMinutes = ((busStops.length - 4) * timeBetweenBusStops)
        .round();
    final upcomingArrivalTimes = busArrivalTimes.where((time) {
      return time.isAfter(
        currentTime.subtract(Duration(minutes: travelBufferMinutes)),
      );
    }).toList();

    // If there are no upcoming buses, show a message
    if (upcomingArrivalTimes.isEmpty) {
      return Column(
        children: [
          Text(
            'NO UPCOMING BUSES',
            softWrap: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[600],
              fontFamily: 'Roboto',
              fontSize: TextSizing.fontSizeText(context),
            ),
          ),
          SizedBox(height: TextSizing.fontSizeText(context)),
        ],
      );
    } else {
      // Calculate minutes until the next bus
      final int nextBusTimeDiff = upcomingArrivalTimes.isNotEmpty
          ? upcomingArrivalTimes[0].difference(currentTime).inMinutes
          : 0;

      // Calculate minutes until the bus after the next
      final int nextNextBusTimeDiff = upcomingArrivalTimes.length > 1
          ? upcomingArrivalTimes[1].difference(currentTime).inMinutes
          : -1;

      // Build the UI showing the MRT name, headers, and each bus stop row
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title row showing MRT station
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    TextSizing.fontSizeText(context),
                    0,
                    TextSizing.fontSizeText(context),
                    TextSizing.fontSizeMiniText(context),
                  ),
                  child: Text(
                    TextSizing.isTabletOrLandscapeMode(context)
                        ? 'Estimated Time of Arrival at Bus Stops'
                        : 'ETAs at Bus Stops',
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: TextSizing.fontSizeHeading(context),
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: TextSizing.fontSizeMiniText(context)),
          // Header row for the table
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment:
                    MainAxisAlignment.center, // Distributes items evenly
                children: [
                  // Space before
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),

                  //Size of bar on left
                  SizedBox(width: MediaQuery.of(context).size.width * 0.01),

                  Flexible(child:
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.35,
                    child: Text(
                      'Bus stop',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),),

                  // Space in between
                  SizedBox(width: MediaQuery.of(context).size.width * 0.01),

                  Flexible(child:
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.275,
                    child: Text(
                      'Upcoming bus (min)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),),
                  ),

                  // Space in between
                  SizedBox(width: MediaQuery.of(context).size.width * 0.01),

                  Flexible(child:
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.275,
                    child: Text(
                      'Next bus (min)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),),
                  ),

                  // Space after
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                ],
              ),
              // Space in between rows
              SizedBox(height: TextSizing.fontSizeText(context) * 0.2),
            ],
          ),

          // Loop through bus stops (skipping first 2 and last 2 stops)
          for (int i = 2; i < (busData.busStop.length) - 2; i++)
            buildRowWidget(
              context,
              busData.busStop[i], // Bus stop name
              nextBusTimeDiff, // Minutes until next bus
              nextNextBusTimeDiff, // Minutes until next-next bus
              i, // Index of the stop
              timeBetweenBusStops, // Multiplier for travel time between stops
            ),
          SizedBox(height: TextSizing.fontSizeHeading(context)),
        ],
      );
    }
  }
}

// Can use to count down every 0.5 minutes, redundant at the moment
class AfternoonStartPointAutoRefresh extends StatefulWidget {
  final int box;
  final Duration interval;

  const AfternoonStartPointAutoRefresh({
    super.key,
    required this.box,
    this.interval = const Duration(seconds: 30),
  });

  @override
  State<AfternoonStartPointAutoRefresh> createState() =>
      _AfternoonStartPointAutoRefreshState();
}

class _AfternoonStartPointAutoRefreshState
    extends State<AfternoonStartPointAutoRefresh> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Immediate build already happens; schedule periodic rebuilds.
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant AfternoonStartPointAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If polling interval changes, restart timer
    if (oldWidget.interval != widget.interval) {
      _timer?.cancel();
      _timer = Timer.periodic(widget.interval, (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AfternoonStartPoint.getBusTime(widget.box, context);
  }
}
