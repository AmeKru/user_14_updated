import 'package:flutter/material.dart';
import 'package:user_14_updated/data/getData.dart';

class EveningStartPoint {
  static Widget buildRowWidget(
    BuildContext context,
    String busstop,
    int nextBusTimeDiff,
    int nextNextBusTimeDiff,
    int index,
    double multiplier,
  ) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 10),
            Container(height: 45, width: 5, color: Colors.white),
            Container(
              width: MediaQuery.of(context).size.width * 0.4,
              color: Colors.lightBlue[500],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                child: Text(
                  busstop,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            SizedBox(width: 10),
            Container(
              width: MediaQuery.of(context).size.width * 0.23,
              color: Colors.lightBlue[50],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                child: Text(
                  '${nextBusTimeDiff + (multiplier * index)}',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            SizedBox(width: 10),
            Container(
              width: MediaQuery.of(context).size.width * 0.23,
              color: Colors.lightBlue[50],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                child: Text(
                  '${nextNextBusTimeDiff + (multiplier * index)}',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
      ],
    );
  }

  static Widget getBusTime(int box, BuildContext context) {
    DateTime currentTime = DateTime.now();
    double busInterval = 1.5;
    BusData _BusData = BusData();
    List<DateTime> busArrivalTimes = [];
    List<String> _busstops = _BusData.BusStop;
    print('Printing busstops: $_busstops');
    String? MRT;

    if (box == 1) {
      busArrivalTimes = _BusData.KAPDepartureTime;
      MRT = 'KAP';
    } else {
      busArrivalTimes = _BusData.CLEDepartureTime;
      MRT = 'CLE';
    }
    print('printing bus arrival times');
    print(busArrivalTimes);

    List<DateTime> upcomingArrivalTimes = busArrivalTimes
        .where((time) => time.isAfter(currentTime))
        .toList();

    if (upcomingArrivalTimes.isEmpty) {
      return Text('NO UPCOMING BUSES');
    } else {
      int nextBusTimeDiff = upcomingArrivalTimes.isNotEmpty
          ? upcomingArrivalTimes[0].difference(currentTime).inMinutes
          : 0;
      int nextNextBusTimeDiff = upcomingArrivalTimes.length > 1
          ? upcomingArrivalTimes[1].difference(currentTime).inMinutes
          : 0;

      return Column(
        children: [
          Row(
            children: [
              SizedBox(width: 10),
              Text(
                'Estimated Arrivng Time at $MRT',
                style: TextStyle(
                  fontSize: 23,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          SizedBox(height: 5),
          Row(
            children: [
              SizedBox(width: MediaQuery.of(context).size.width * 0.05),
              Text(
                'Bus Stop',
                style: TextStyle(fontSize: 10, color: Colors.black),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.32),
              Text(
                'Upcoming bus(min)',
                style: TextStyle(fontSize: 10, color: Colors.black),
              ),
              SizedBox(width: 20),
              Text(
                'Next bus(min)',
                style: TextStyle(fontSize: 10, color: Colors.black),
              ),
            ],
          ),
          for (int i = 2; i < (_BusData.BusStop.length) - 2; i++)
            buildRowWidget(
              context,
              _BusData.BusStop[i],
              nextBusTimeDiff,
              nextNextBusTimeDiff,
              i,
              1.5,
            ),
        ],
      );
    }
  }
}
