import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/SharedPreference.dart';
import 'package:user_14_updated/services/eveningService.dart';
import 'package:user_14_updated/utils/loading.dart';
import 'package:user_14_updated/utils/styling.dart';
import 'package:user_14_updated/utils/textStyles.dart';

class BookingConfirmation extends StatefulWidget {
  final int selectedBox;
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;
  final List<DateTime> Function() getDepartureTimes;
  final VoidCallback onCancel;
  String? BusStop;
  final List<DateTime> KAPDepartureTime;
  final List<DateTime> CLEDepartureTime;
  final int eveningService;
  final bool isDarkMode;

  BookingConfirmation({
    required this.selectedBox,
    this.bookedTripIndexKAP,
    this.bookedTripIndexCLE,
    required this.getDepartureTimes,
    required this.onCancel,
    this.BusStop,
    required this.KAPDepartureTime,
    required this.CLEDepartureTime,
    required this.eveningService,
    required this.isDarkMode,
  });

  @override
  State<BookingConfirmation> createState() => _BookingConfirmationState();
}

class _BookingConfirmationState extends State<BookingConfirmation> {
  late Map<String, String?> ColorValues;
  int random_num = 1;
  late Timer timer;
  bool _loading = true;
  int departureSeconds = 0;
  Duration timeUpdateInterval = Duration(seconds: 1);
  Duration apiFetchInterval = Duration(minutes: 3);
  int secondsElapsed = 0;
  Timer? _clocktimer;
  SharedPreferenceService prefsService = SharedPreferenceService();

  @override
  void initState() {
    super.initState();
    widget.KAPDepartureTime;
    widget.CLEDepartureTime;
    getTime().then((_) {
      _clocktimer = Timer.periodic(timeUpdateInterval, (timer) {
        updateTimeManually();
        secondsElapsed += timeUpdateInterval.inSeconds;
        if (secondsElapsed >= apiFetchInterval.inSeconds) {
          getTime();
          secondsElapsed = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _clocktimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Color? generateColor(DateTime departureTime, int selectedTripNo) {
    List<Color?> colors = [
      Colors.red[100],
      Colors.yellow[200],
      Colors.white,
      Colors.tealAccent[100],
      Colors.orangeAccent[200],
      Colors.greenAccent[100],
      Colors.indigo[100],
      Colors.purpleAccent[100],
      Colors.grey[400],
      Colors.limeAccent[100],
    ];

    int departureSeconds =
        departureTime.hour * 3600 + departureTime.minute * 60;
    int combinedSeconds = time_now!.second + departureSeconds;
    int roundedSeconds = (combinedSeconds ~/ 10) * 10;
    DateTime roundedTime = DateTime(
      time_now!.year,
      time_now!.month,
      time_now!.day,
      time_now!.hour,
      time_now!.minute,
      roundedSeconds,
    );
    int seed = roundedTime.millisecondsSinceEpoch ~/ (1000 * 10);
    Random random = Random(seed);
    int syncedRandomNum = random.nextInt(10);
    return colors[syncedRandomNum];
  }

  Future<void> getTime() async {
    try {
      final uri = Uri.parse(
        'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE',
      );
      // final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
      print("Printing URI");
      print(uri);
      final response = await get(
        Uri.parse(
          'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE',
        ),
      );
      // final response = await get(Uri.parse('https://worldtimeapi.org/api/timezone/Singapore'));
      print("Printing response");
      print(response);

      print(response.body);
      Map data = jsonDecode(response.body);
      print(data);
      String datetime =
          data['dateTime']; // timeapi.io is dateTime instead of datetime
      //String offset = data['utc_offset'].substring(1, 3);
      setState(() {
        time_now = DateTime.parse(datetime);
        //time_now = time_now!.add(Duration(hours: int.parse(offset)));
      });
    } catch (e) {
      print('caught error: $e');
    }
  }

  void updateTimeManually() {
    setState(() {
      time_now = time_now!.add(timeUpdateInterval);
    });
  }

  void showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Cancel Booking"),
          content: Text("Are you sure you want to cancel this booking?"),
          actions: <Widget>[
            TextButton(
              child: Text("No"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Yes"),
              onPressed: () {
                widget.onCancel();
                prefsService.clearBookingData();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color darkText = widget.isDarkMode ? Colors.white : Colors.black;
    final int? bookedTripIndex = widget.selectedBox == 1
        ? widget.bookedTripIndexKAP
        : widget.bookedTripIndexCLE;
    final DateTime bookedTime = widget.getDepartureTimes()[bookedTripIndex!];
    final String station = widget.selectedBox == 1 ? 'KAP' : 'CLE';
    DateTime currentTime = DateTime.now();
    bool isAfter3pm = currentTime.hour >= 15 ? true : false;
    prefsService.saveBookingData(
      widget.selectedBox,
      widget.bookedTripIndexKAP,
      widget.bookedTripIndexCLE,
      widget.BusStop,
    );

    if (bookedTime != null) {
      if (time_now == null) {
        print('time now = $time_now');
        return Container(child: LoadingScroll(isDarkMode: widget.isDarkMode));
      } else {
        return Container(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  color: generateColor(bookedTime, bookedTripIndex),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              color: Colors.blueAccent,
                            ),
                            Text(
                              'Booking Confirmation:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            SizedBox(width: 10),
                          ],
                        ),
                        SizedBox(height: 10),
                        BookingConfirmationText(
                          label: 'Trip Number',
                          value: '${bookedTripIndex + 1}',
                          size: 0.5,
                        ),
                        DrawLine(),
                        BookingConfirmationText(
                          label: 'Time',
                          value:
                              '${bookedTime.hour.toString().padLeft(2, '0')}:${bookedTime.minute.toString().padLeft(2, '0')}',
                          size: 0.5,
                        ),
                        DrawLine(),
                        BookingConfirmationText(
                          label: 'Station',
                          value: '$station',
                          size: 0.5,
                        ),
                        DrawLine(),
                        BookingConfirmationText(
                          label: 'Bus Stop',
                          value: '${widget.BusStop}',
                          size: 0.5,
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.65,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                              child: ElevatedButton(
                                onPressed: showCancelDialog,
                                child: Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              time_now!.hour > startEveningService
                  ? EveningStartPoint.getBusTime(widget.selectedBox, context)
                  : SizedBox(height: 20),
            ],
          ),
        );
      } // closed else bracket osdhfkasklvjsokdvno
    } else
      return SizedBox();
  }
}
