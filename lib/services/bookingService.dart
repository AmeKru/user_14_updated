import 'dart:async';

import 'package:flutter/material.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/eveningService.dart';
import 'package:user_14_updated/utils/loading.dart';

class BookingService extends StatefulWidget {
  final List<DateTime> departureTimes;
  final int selectedBox;
  final int? bookedTripIndexKAP;
  final int? bookedTripIndexCLE;
  final VoidCallback onPressedConfirm;
  final bool confirmationPressed;
  final Function(int index, bool newValue) updateBookingStatusKAP;
  final Function(int index, bool newValue) updateBookingStatusCLE;
  final Future<int?> Function(String MRT, int index) countBooking;
  final Function showBusStopSelectionBottomSheet;
  final List<DateTime> KAPDepartureTime;
  final List<DateTime> CLEDepartureTime;
  final int eveningService;
  final bool isDarkMode;

  BookingService({
    required this.departureTimes,
    required this.selectedBox,
    required this.bookedTripIndexKAP,
    required this.bookedTripIndexCLE,
    required this.onPressedConfirm,
    required this.confirmationPressed,
    required this.countBooking,
    required this.updateBookingStatusKAP,
    required this.updateBookingStatusCLE,
    required this.showBusStopSelectionBottomSheet,
    required this.KAPDepartureTime,
    required this.CLEDepartureTime,
    required this.eveningService,
    required this.isDarkMode,
  });

  @override
  State<BookingService> createState() => _BookingServiceState();
}

class _BookingServiceState extends State<BookingService> {
  Color finalColor = Colors.grey;
  late Timer _timer;
  late Map<int, int?> bookingCounts; //store count
  bool _loading = true;
  int Vacancy_Green = 3;
  int Vacancy_Yellow = 4;
  int Vacancy_Red = 5;
  DateTime now = DateTime.now();

  bool canConfirm() {
    return widget.selectedBox == 1
        ? widget.bookedTripIndexKAP != null
        : widget.bookedTripIndexCLE != null;
  }

  @override
  void didUpdateWidget(covariant BookingService oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBox != widget.selectedBox) {
      setState(() {
        _loading = true;
        bookingCounts = {};
      });
      _updateBookingCounts();
    }
  }

  @override
  void initState() {
    super.initState();
    bookingCounts = {};
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _updateBookingCounts();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateBookingCounts() async {
    for (int i = 0; i < widget.departureTimes.length; i++) {
      int? count = await widget.countBooking(
        widget.selectedBox == 1 ? 'KAP' : 'CLE',
        i + 1,
      );
      if (mounted) {
        setState(() {
          bookingCounts[i] = count;
        });
      }
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  bool _isFull(int? count) {
    return count != null && count >= Vacancy_Red;
  }

  Color _getColor(int _count) {
    if (_count < Vacancy_Green)
      return Colors.green;
    else if (_count >= Vacancy_Green && _count <= Vacancy_Yellow)
      return Colors.yellowAccent;
    else
      return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    Color darkText = widget.isDarkMode ? Colors.white : Colors.black;

    return _loading == true
        ? LoadingScroll(isDarkMode: widget.isDarkMode)
        : Column(
            children: [
              SizedBox(height: 20),
              Text(
                'Capacity Indicator',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 25,
                  color: darkText,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(width: MediaQuery.of(context).size.width * 0.1),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.15,
                    height: 5,
                    color: Colors.green,
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Text('Available', style: TextStyle(color: darkText)),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.2),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.15,
                    height: 5,
                    color: Colors.yellowAccent,
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Text('Half Full', style: TextStyle(color: darkText)),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(width: MediaQuery.of(context).size.width * 0.4),
                  Text('FULL', style: TextStyle(color: darkText)),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.15,
                    height: 5,
                    color: Colors.red,
                  ),
                ],
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.departureTimes.length,
                itemBuilder: (context, index) {
                  final time = widget.departureTimes[index];
                  List KAPDepartureTIME = widget.KAPDepartureTime;
                  List CLEDepartureTIME = widget.CLEDepartureTime;
                  bool isBookedKAP = index == widget.bookedTripIndexKAP;
                  bool isBookedCLE = index == widget.bookedTripIndexCLE;
                  bool canBook = widget.selectedBox == 1
                      ? widget.bookedTripIndexKAP == null
                      : widget.bookedTripIndexCLE == null;
                  int? count = bookingCounts[index];
                  bool isFull = _isFull(count);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                color: isFull == true
                                    ? Colors.grey[300]
                                    : Colors.lightBlue[50],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    0.0,
                                  ), // Set to 0.0 for 90-degree corners
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    0,
                                    8,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      if (count != null)
                                        Container(
                                          width: 8,
                                          height: 57,
                                          color: _getColor(count),
                                        ),
                                      Text(
                                        ' Departure Trip ${index + 1}',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(width: 70),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          width: 2,
                                          height: 40,
                                          color: Colors
                                              .black, // Adjust color as needed
                                        ),
                                      ),
                                      SizedBox(width: 30),
                                      Text(
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: isFull
                                  ? null
                                  : () {
                                      if (!isFull) {
                                        if (widget.selectedBox == 1) {
                                          // Check the current state and decide whether to show the bottom sheet
                                          if (!isBookedKAP) {
                                            widget.updateBookingStatusKAP(
                                              index,
                                              true,
                                            );
                                            widget
                                                .showBusStopSelectionBottomSheet(
                                                  context,
                                                );
                                          } else {
                                            widget.updateBookingStatusKAP(
                                              index,
                                              false,
                                            );
                                          }
                                        } else {
                                          // Check the current state and decide whether to show the bottom sheet
                                          if (!isBookedCLE) {
                                            widget.updateBookingStatusCLE(
                                              index,
                                              true,
                                            );
                                            widget
                                                .showBusStopSelectionBottomSheet(
                                                  context,
                                                );
                                          } else {
                                            widget.updateBookingStatusCLE(
                                              index,
                                              false,
                                            );
                                          }
                                        }
                                      }
                                    },
                              child: Icon(
                                widget.selectedBox == 1
                                    ? (isBookedKAP
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank)
                                    : (isBookedCLE
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank),
                                color: isFull ? Colors.grey : Colors.blue,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (canConfirm())
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: widget.onPressedConfirm,
                      child: Text('Confirm'),
                    ),
                  ),
                ),
              SizedBox(height: 20),
              now!.hour > startEveningService
                  ? EveningStartPoint.getBusTime(widget.selectedBox, context)
                  : SizedBox(height: 20),
            ],
          );
  }
}
