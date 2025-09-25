import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

class EveningStartPoint {
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
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Vertical coloured line
            Container(
              height: TextSizing.fontSizeText(context) * 2.5,
              width: MediaQuery.of(context).size.width * 0.01,
              color: isDarkMode ? Colors.cyanAccent : Colors.blue,
            ),

            // Bus stop name container
            Container(
              width: MediaQuery.of(context).size.width * 0.4,
              color: isDarkMode
                  ? Colors.blueGrey[800]
                  : const Color(0xff014689),
              child: Padding(
                padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
                child: Text(
                  busStop,
                  style: TextStyle(
                    color: isDarkMode ? Colors.cyanAccent : Colors.white,
                    fontSize: TextSizing.fontSizeText(context),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),

            // Space in between
            SizedBox(width: MediaQuery.of(context).size.width * 0.01),

            // Upcoming bus time container
            Container(
              width: MediaQuery.of(context).size.width * 0.25,
              color: isDarkMode ? Colors.blueGrey[600] : Colors.lightBlue[50],
              child: Padding(
                padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
                child: Text(
                  // Add (multiplier * index) to simulate travel time from MRT to this stop
                  '${nextBusTimeDiff + (multiplier * index)}',
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeText(context),
                    fontFamily: 'Roboto',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),

            // Space in between
            SizedBox(width: MediaQuery.of(context).size.width * 0.01),

            // Next-next bus time container
            Container(
              width: MediaQuery.of(context).size.width * 0.25,
              color: isDarkMode ? Colors.blueGrey[600] : Colors.lightBlue[50],
              child: Padding(
                padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
                child: Text(
                  '${nextNextBusTimeDiff + (multiplier * index)}',
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeText(context),
                    fontFamily: 'Roboto',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Space in between rows
        SizedBox(height: TextSizing.fontSizeText(context) * 0.2),
      ],
    );
  }

  // Returns a widget showing the bus arrival times for a given MRT start point (KAP or CLE)
  static Widget getBusTime(int box, BuildContext context, bool isDarkMode) {
    DateTime currentTime = DateTime.now(); // Current time

    BusData busData = BusData(); // Data source for bus stops and times
    List<DateTime> busArrivalTimes = []; // Holds the relevant departure times
    List<String> busStops = busData.busStop; // List of bus stop names

    if (kDebugMode) {
      print('Printing bus stops: $busStops');
    }

    // Select departure times and MRT name based on the box value
    if (box == 1) {
      busArrivalTimes = busData.departureTimeKAP;
      //  mrt = 'KAP';
    } else {
      busArrivalTimes = busData.departureTimeCLE;
      //  mrt = 'CLE';
    }
    if (kDebugMode) {
      print('printing bus arrival times');
      print(busArrivalTimes);
    }

    // Filter out past times, keeping only upcoming buses
    List<DateTime> upcomingArrivalTimes = busArrivalTimes
        .where((time) => time.isAfter(currentTime))
        .toList();

    // If there are no upcoming buses, show a message

    if (upcomingArrivalTimes.isEmpty) {
      return Column(
        children: [
          Text(
            'NO UPCOMING BUSES',
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
      int nextBusTimeDiff = upcomingArrivalTimes.isNotEmpty
          ? upcomingArrivalTimes[0].difference(currentTime).inMinutes
          : 0;

      // Calculate minutes until the bus after the next
      int nextNextBusTimeDiff = upcomingArrivalTimes.length > 1
          ? upcomingArrivalTimes[1].difference(currentTime).inMinutes
          : 0;

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
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    TextSizing.fontSizeText(context),
                    0,
                    TextSizing.fontSizeText(context),
                    TextSizing.fontSizeMiniText(context),
                  ),
                  child: Text(
                    textAlign: TextAlign.center,
                    TextSizing.isTablet(context)
                        ? 'Estimated Time of Arrival at Bus Stops'
                        : 'ETAs at Bus Stops',
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
          Container(
            width: double.infinity, // Ensures full horizontal stretch
            padding: EdgeInsets.symmetric(
              horizontal: 8,
            ), // Optional: adds side spacing
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment:
                  MainAxisAlignment.center, // Distributes items evenly
              children: [
                SizedBox(width: MediaQuery.of(context).size.width * 0.01),

                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Text(
                    'Bus stop',
                    style: TextStyle(
                      fontSize: TextSizing.fontSizeMiniText(context),
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                SizedBox(width: MediaQuery.of(context).size.width * 0.01),

                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: Text(
                    'Upcoming bus (min)',
                    style: TextStyle(
                      fontSize: TextSizing.fontSizeMiniText(context),
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                SizedBox(width: MediaQuery.of(context).size.width * 0.01),

                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: Text(
                    'Next bus (min)',
                    style: TextStyle(
                      fontSize: TextSizing.fontSizeMiniText(context),
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loop through bus stops (skipping first 2 and last 2 stops)
          for (int i = 2; i < (busData.busStop.length) - 2; i++)
            buildRowWidget(
              context,
              busData.busStop[i], // Bus stop name
              nextBusTimeDiff, // Minutes until next bus
              nextNextBusTimeDiff, // Minutes until next-next bus
              i, // Index of the stop
              1.5, // Multiplier for travel time between stops
              isDarkMode,
            ),
          SizedBox(height: TextSizing.fontSizeHeading(context)),
        ],
      );
    }
  }
}
