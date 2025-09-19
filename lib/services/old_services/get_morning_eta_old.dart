import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/utils/get_time.dart';

class CalculateMorningBus {
  static Widget buildMorningETADisplay(String text, {String eta = ''}) {
    return SizedBox(
      width: 350,
      child: Card(
        color: Colors.lightBlue[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.0)),
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Column(
            children: [
              Icon(Icons.directions_bus_outlined),
              Text(
                eta.isNotEmpty ? 'Upcoming bus: $eta minutes' : text,
                style: TextStyle(
                  fontSize: 15.0,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget getMorningETA(List<DateTime> busArrivalTimes) {
    final timeService = TimeService();
    DateTime currentTime = timeService.timeNow ?? DateTime.now();
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

    List<DateTime> upcomingArrivalTimes = busArrivalTimes
        .where((time) => time.isAfter(currentTime))
        .toList();

    if (kDebugMode) {
      print('Upcoming Arrival Times: $upcomingArrivalTimes');
      print(upcomingArrivalTimes.isEmpty);
    }

    if (upcomingArrivalTimes.isEmpty) {
      if (selectedMRT == 1) {
        return Column(
          children: [
            buildMorningETADisplay('No upcoming buses available.'),
            buildMorningETADisplay('No upcoming buses available'),
          ],
        );
      } else if (selectedMRT == 2) {
        return Column(
          children: [buildMorningETADisplay('No upcoming buses available.')],
        );
      }
    } else {
      String upcomingBus = upcomingArrivalTimes[0]
          .difference(currentTime)
          .inMinutes
          .toString();
      String nextUpcomingBus = upcomingArrivalTimes.length > 1
          ? upcomingArrivalTimes[1].difference(currentTime).inMinutes.toString()
          : ' - ';
      if (selectedMRT == 1) {
        return Column(
          children: [
            buildMorningETADisplay('Upcoming bus:', eta: upcomingBus),
            buildMorningETADisplay('Next bus:', eta: nextUpcomingBus),
          ],
        );
      } else if (selectedMRT == 2) {
        return Column(
          children: [buildMorningETADisplay('Upcoming bus:', eta: upcomingBus)],
        );
      }
    }
    return Column();
  }
}

// Widget to retrieve and display bus times
class GetMorningETA extends StatelessWidget {
  final List<DateTime> busArrivalTimes;

  const GetMorningETA(this.busArrivalTimes, {super.key});

  @override
  Widget build(BuildContext context) {
    return CalculateMorningBus.getMorningETA(busArrivalTimes);
  }
}
