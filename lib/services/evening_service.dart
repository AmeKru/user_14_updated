import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';

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
            Container(
              height: 45,
              width: MediaQuery.of(context).size.width * 0.01,
              color: isDarkMode ? Colors.cyanAccent : Colors.blue,
            ), // Vertical separator line
            // Bus stop name container
            Container(
              width: MediaQuery.of(context).size.width * 0.4,
              color: isDarkMode
                  ? Colors.blueGrey[800]
                  : const Color(0xff014689),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                child: Text(
                  busStop,
                  style: TextStyle(
                    color: isDarkMode ? Colors.cyanAccent : Colors.white,
                    fontSize: 20,
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
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                child: Text(
                  // Add (multiplier * index) to simulate travel time from MRT to this stop
                  '${nextBusTimeDiff + (multiplier * index)}',
                  style: TextStyle(
                    fontSize: 20,
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
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                child: Text(
                  '${nextNextBusTimeDiff + (multiplier * index)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Roboto',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Space in between rows
        SizedBox(height: MediaQuery.of(context).size.width * 0.005),
      ],
    );
  }

  // Returns a widget showing the bus arrival times for a given MRT start point (KAP or CLE)
  static Widget getBusTime(int box, BuildContext context, bool isDarkMode) {
    DateTime currentTime = DateTime.now(); // Current time
    double busInterval =
        1.5; // Interval between buses in minutes (used for estimation)
    BusData _BusData = BusData(); // Data source for bus stops and times
    List<DateTime> busArrivalTimes = []; // Holds the relevant departure times
    List<String> _busstops = _BusData.busStop; // List of bus stop names

    if (kDebugMode) {
      print('Printing busstops: $_busstops');
    }

    String? MRT; // Name of the MRT station (KAP or CLE)

    // Select departure times and MRT name based on the box value
    if (box == 1) {
      busArrivalTimes = _BusData.KAPDepartureTime;
      MRT = 'KAP';
    } else {
      busArrivalTimes = _BusData.CLEDepartureTime;
      MRT = 'CLE';
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
              color: isDarkMode ? Colors.blueGrey[300] : Colors.blueGrey[600],
              fontFamily: 'Roboto',
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.width * 0.05),
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
          SizedBox(height: MediaQuery.of(context).size.width * 0.025),
          // Title row showing MRT station
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Estimated Arriving Time at $MRT',
                style: TextStyle(
                  fontSize: 23,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).size.width * 0.02),
          // Header row for the table
          Container(
            width: double.infinity, // Ensures full horizontal stretch
            padding: EdgeInsets.symmetric(
              horizontal: 8,
            ), // Optional: adds side spacing
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Distributes items evenly
              children: [
                SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                Text(
                  'Bus Stop',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.23),
                Text(
                  'Upcoming bus(min)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                Text(
                  'Next bus(min)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.1),
              ],
            ),
          ),

          // Loop through bus stops (skipping first 2 and last 2 stops)
          for (int i = 2; i < (_BusData.busStop.length) - 2; i++)
            buildRowWidget(
              context,
              _BusData.busStop[i], // Bus stop name
              nextBusTimeDiff, // Minutes until next bus
              nextNextBusTimeDiff, // Minutes until next-next bus
              i, // Index of the stop
              1.5, // Multiplier for travel time between stops
              isDarkMode,
            ),
        ],
      );
    }
  }
}
