import 'dart:async'; // For Timer functionality

import 'package:flutter/material.dart';
import 'package:user_14_updated/data/global.dart'; // contains shared global variables/constants
import 'package:user_14_updated/services/evening_service.dart'; // Service for evening bus logic
import 'package:user_14_updated/utils/loading.dart'; // Custom loading widget
import 'package:user_14_updated/utils/text_sizing.dart';

///////////////////////////////////////////////////////////////
// Booking Service
// A stateful widget that manages and displays booking availability for bus trips.
// It periodically checks booking counts and updates the UI accordingly

class BookingService extends StatefulWidget {
  // List of departure times for the currently selected station
  final List<DateTime> departureTimes;

  // Indicates which station is selected: 1 for KAP, otherwise CLE
  final int selectedBox;

  // Index of the booked trip for KAP (if any)
  final int? bookedTripIndexKAP;

  // Index of the booked trip for CLE (if any)
  final int? bookedTripIndexCLE;

  // Callback when the confirm button is pressed
  final VoidCallback onPressedConfirm;

  // Whether the confirmation button has already been pressed
  final bool confirmationPressed;

  // Callbacks to update booking status for KAP and CLE trips
  final Function(int index, bool newValue) updateBookingStatusKAP;
  final Function(int index, bool newValue) updateBookingStatusCLE;

  // Function to count bookings for a given MRT station and trip index
  final Future<int?> Function(String mrt, int index) countBooking;

  // Function to show the bus stop selection bottom sheet
  final Function showBusStopSelectionBottomSheet;

  // Full departure time lists for both stations
  final List<DateTime> departureTimeKAP;
  final List<DateTime> departureTimeCLE;

  // Evening service start time or identifier
  final int eveningService;

  // Whether the app is in dark mode
  final bool isDarkMode;

  // Selected BusStop
  final String selectedBusStop;

  const BookingService({
    super.key,
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
    required this.departureTimeKAP,
    required this.departureTimeCLE,
    required this.eveningService,
    required this.isDarkMode,
    required this.selectedBusStop,
  });

  @override
  State<BookingService> createState() => _BookingServiceState();
}

class _BookingServiceState extends State<BookingService> {
  // Default color for UI elements before availability is determined
  Color finalColor = Colors.grey;

  // Timer to periodically refresh booking counts
  late Timer _timer;

  // Stores booking counts for each trip index
  // Key: trip index, Value: number of bookings (nullable if not yet fetched)
  late Map<int, int?> bookingCounts;

  // Whether booking data is still loading
  bool _loading = true;

  // Thresholds for vacancy color coding
  int vacancyGreen = 3; // Below this count = green
  int vacancyYellow = 4; // Between green and yellow inclusive = yellow
  int vacancyRed = 5; // At or above this count = red (full)

  // Current time snapshot (may be used for filtering trips)
  DateTime now = DateTime.now();

  // Checks if the user can confirm a booking.
  // Returns true if a trip index is selected for the current station.
  bool canConfirm() {
    if (widget.selectedBox == 1
        ? widget.bookedTripIndexKAP == null
        : widget.bookedTripIndexCLE == null) {
      busIndex = 0;
    }
    return widget.selectedBox == 1
        ? widget.bookedTripIndexKAP != null && busIndex != 0
        : widget.bookedTripIndexCLE != null && busIndex != 0;
  }

  ///////////////////////////////////////////////////////////////
  // If the selected station changes, reset loading state and booking counts

  @override
  void didUpdateWidget(covariant BookingService oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedBox != widget.selectedBox) {
      setState(() {
        _loading = true;
        bookingCounts = {};
      });
      _updateBookingCounts(); // Fetch counts for the new station
    }
  }

  @override
  void initState() {
    super.initState();
    bookingCounts = {};
    // Timer that runs every 0.5 s
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateBookingCounts();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Stop the timer to prevent memory leaks
    super.dispose();
  }

  // Fetches booking counts for all departure times and updates state.
  void _updateBookingCounts() async {
    for (int i = 0; i < widget.departureTimes.length; i++) {
      // Determine station code based on selectedBox
      int tripNumber = i + 1; // Trip numbers are 1-based
      int? count = await widget.countBooking(
        widget.selectedBox == 1 ? 'KAP' : 'CLE',
        tripNumber,
      );

      if (mounted) {
        setState(() {
          bookingCounts[i] = count;
        });
      }
    }

    // Once all counts are fetched, mark loading as complete
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // Returns true if the given count meets or exceeds the "full" threshold.
  bool _isFull(int? count) {
    return count != null && count >= vacancyRed;
  }

  ///////////////////////////////////////////////////////////////
  // Returns a color based on the number of bookings:
  // - Green: plenty of space
  // - Yellow: limited space
  // - Red: full

  Color _getColor(int count) {
    if (count < vacancyGreen) {
      return Colors.green[400]!;
    } else if (count >= vacancyGreen && count <= vacancyYellow) {
      return Colors.yellow[600]!;
    } else {
      return Colors.red[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine text color based on dark mode setting
    Color darkText = widget.isDarkMode ? Colors.white : Colors.black;

    // If still loading booking data, show a loading widget
    return _loading == true
        ? LoadingScroll(isDarkMode: widget.isDarkMode)
        : Column(
            children: [
              SizedBox(height: TextSizing.fontSizeMiniText(context) * 0.8),
              Text(
                widget.selectedBox == 1
                    ? 'Bus to King Albert Park'
                    : 'Bus to Clementi',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: TextSizing.fontSizeHeading(context),
                  color: darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: TextSizing.fontSizeMiniText(context)),

              // === Capacity Indicator Title ===
              Text(
                'Capacity Indicator',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: TextSizing.fontSizeText(context),
                  color: darkText,
                ),
              ),

              SizedBox(height: TextSizing.fontSizeMiniText(context)),

              // === Legend Row: Available & Half Full ===
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Available indicator
                  Container(
                    width: MediaQuery.of(context).size.width * 0.1,
                    height: TextSizing.fontSizeText(context) * 0.25,
                    color: Colors.green,
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.015),
                  Text(
                    'Available',
                    style: TextStyle(
                      color: darkText,
                      fontSize: TextSizing.fontSizeMiniText(context),
                      fontFamily: 'Roboto',
                    ),
                  ),

                  // spacing in between
                  SizedBox(width: MediaQuery.of(context).size.width * 0.06),

                  // Half full indicator
                  Container(
                    width: MediaQuery.of(context).size.width * 0.1,
                    height: TextSizing.fontSizeText(context) * 0.25,
                    color: Colors.yellow[600],
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                  Text(
                    'Half Full',
                    style: TextStyle(
                      color: darkText,
                      fontSize: TextSizing.fontSizeMiniText(context),
                      fontFamily: 'Roboto',
                    ),
                  ),

                  // spacing in between
                  SizedBox(width: MediaQuery.of(context).size.width * 0.06),

                  // Full indicator
                  Container(
                    width: MediaQuery.of(context).size.width * 0.1,
                    height: TextSizing.fontSizeText(context) * 0.25,
                    color: Colors.red, // Full indicator
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                  Text(
                    'FULL',
                    style: TextStyle(
                      color: darkText,
                      fontSize: TextSizing.fontSizeMiniText(context),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),

              SizedBox(height: TextSizing.fontSizeText(context) * 1.5),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      textAlign: TextAlign.center,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      TextSizing.isTablet(context)
                          ? '* Departure time stated refers to bus stop at entrance (ENT). Check below for more information about the other stops.'
                          : '* Departure time stated refers to bus stop at entrance (ENT).\nCheck below for more information about the other stops.',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        color: (widget.isDarkMode
                            ? Colors.white
                            : Colors.black),
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),

              // === List of Departure Trips ===
              ListView.builder(
                shrinkWrap: true,
                // Allow list to size itself within Column
                physics: const NeverScrollableScrollPhysics(),
                // Disable scrolling (parent scrolls)
                itemCount: widget.departureTimes.length,
                itemBuilder: (context, index) {
                  final time = widget.departureTimes[index];

                  // Whether this trip is currently booked for each station
                  bool isBookedKAP =
                      (index == widget.bookedTripIndexKAP) && busIndex != 0;
                  bool isBookedCLE =
                      (index == widget.bookedTripIndexCLE) && busIndex != 0;

                  // Current booking count for this trip
                  int? count = bookingCounts[index];

                  // Whether this trip is full
                  bool isFull = _isFull(count);

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      TextSizing.fontSizeText(context),
                      0.0,
                      TextSizing.fontSizeText(context),
                      0.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // === Trip Card ===
                            Expanded(
                              child: Card(
                                color: isFull
                                    ? (widget.isDarkMode
                                          ? Colors.blueGrey[800]
                                          : Colors.grey[300])
                                    : (widget.isDarkMode
                                          ? Colors.blueGrey[600]
                                          : Colors.blue[50]),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    0.0,
                                  ), // Square corners
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    0,
                                    TextSizing.fontSizeText(context),
                                    0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Capacity color bar (only if count known)
                                      if (count != null)
                                        Container(
                                          width:
                                              TextSizing.fontSizeText(context) *
                                              0.5,
                                          height:
                                              TextSizing.fontSizeText(context) *
                                              4,
                                          color: _getColor(count),
                                        ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,

                                          children: [
                                            Text(
                                              'Trip ${index + 1}',
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontWeight: FontWeight.bold,
                                                fontSize:
                                                    TextSizing.fontSizeText(
                                                      context,
                                                    ),
                                                color: isFull
                                                    ? (widget.isDarkMode
                                                          ? Colors.blueGrey[400]
                                                          : Colors.grey[600])
                                                    : (widget.isDarkMode
                                                          ? Colors.white
                                                          : Colors.black),
                                              ),
                                            ),

                                            // Vertical divider
                                            Padding(
                                              padding: EdgeInsets.all(
                                                TextSizing.fontSizeText(
                                                  context,
                                                ),
                                              ),
                                              child: Container(
                                                width:
                                                    TextSizing.fontSizeText(
                                                      context,
                                                    ) *
                                                    0.1,
                                                height:
                                                    TextSizing.fontSizeHeading(
                                                      context,
                                                    ) *
                                                    1.2,
                                                color: isFull
                                                    ? (widget.isDarkMode
                                                          ? Colors.blueGrey[500]
                                                          : Colors.grey[600])
                                                    : (widget.isDarkMode
                                                          ? Colors.blueGrey[200]
                                                          : Colors
                                                                .blueGrey[500]),
                                              ),
                                            ),

                                            // Departure time
                                            Text(
                                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} *',
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontWeight: FontWeight.bold,
                                                fontSize:
                                                    TextSizing.fontSizeText(
                                                      context,
                                                    ),
                                                color: isFull
                                                    ? (widget.isDarkMode
                                                          ? Colors.blueGrey[400]
                                                          : Colors.grey[600])
                                                    : (widget.isDarkMode
                                                          ? Colors.white
                                                          : Colors.black),
                                              ),
                                            ),

                                            // Vertical divider
                                            Padding(
                                              padding: EdgeInsets.all(
                                                TextSizing.fontSizeText(
                                                  context,
                                                ),
                                              ),
                                              child: Container(
                                                width:
                                                    TextSizing.fontSizeText(
                                                      context,
                                                    ) *
                                                    0.1,
                                                height:
                                                    TextSizing.fontSizeHeading(
                                                      context,
                                                    ) *
                                                    1.2,
                                                color: isFull
                                                    ? (widget.isDarkMode
                                                          ? Colors.blueGrey[500]
                                                          : Colors.grey[600])
                                                    : (widget.isDarkMode
                                                          ? Colors.blueGrey[200]
                                                          : Colors
                                                                .blueGrey[500]),
                                              ),
                                            ),

                                            if (canConfirm())
                                              Text(
                                                widget.selectedBusStop,
                                                style: TextStyle(
                                                  fontFamily: 'Roboto',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      TextSizing.fontSizeText(
                                                        context,
                                                      ),
                                                  color: isFull
                                                      ? (widget.isDarkMode
                                                            ? Colors
                                                                  .blueGrey[400]
                                                            : Colors.grey[600])
                                                      : (widget.isDarkMode
                                                            ? Colors.white
                                                            : Colors.black),
                                                ),
                                              ),
                                            if (!canConfirm())
                                              Text(
                                                ' ---- ',
                                                style: TextStyle(
                                                  fontSize:
                                                      TextSizing.fontSizeText(
                                                        context,
                                                      ),
                                                  color: isFull
                                                      ? (widget.isDarkMode
                                                            ? Colors
                                                                  .blueGrey[400]
                                                            : Colors.grey[600])
                                                      : (widget.isDarkMode
                                                            ? Colors.white
                                                            : Colors.black),
                                                  fontFamily: 'Roboto',
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // === Booking Checkbox Icon ===
                            GestureDetector(
                              onTap: isFull
                                  ? null // Disable tap if full
                                  : () {
                                      if (!isFull) {
                                        if (widget.selectedBox == 1) {
                                          // KAP station booking logic
                                          if (!isBookedKAP) {
                                            widget.updateBookingStatusKAP(
                                              index,
                                              true,
                                            );
                                            if (busIndex == 0) {
                                              widget
                                                  .showBusStopSelectionBottomSheet(
                                                    context,
                                                  );
                                            }
                                          } else {
                                            widget.updateBookingStatusKAP(
                                              index,
                                              false,
                                            );
                                          }
                                        } else {
                                          // CLE station booking logic
                                          if (!isBookedCLE) {
                                            widget.updateBookingStatusCLE(
                                              index,
                                              true,
                                            );
                                            if (busIndex == 0) {
                                              widget
                                                  .showBusStopSelectionBottomSheet(
                                                    context,
                                                  );
                                            }
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
                                color: isFull
                                    ? (widget.isDarkMode
                                          ? Colors.blueGrey[500]
                                          : Colors.grey[400])
                                    : (widget.isDarkMode
                                          ? Colors.blueGrey[50]
                                          : const Color(0xff014689)),
                                size: TextSizing.fontSizeHeading(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // === Confirm Button (only if a trip is selected) ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canConfirm())
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.all(
                              TextSizing.fontSizeText(context),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (widget.isDarkMode
                                    ? Colors.blueGrey[50]
                                    : const Color(
                                        0xff014689,
                                      )), // Button background color
                                foregroundColor: (widget.isDarkMode
                                    ? Colors.blueGrey[900]
                                    : Colors.white),
                              ), // Text color
                              onPressed: widget.onPressedConfirm,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  TextSizing.fontSizeText(context) * 0.33,
                                ),
                                child: Text(
                                  'Confirm',
                                  style: TextStyle(
                                    fontSize: TextSizing.fontSizeText(context),
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!canConfirm())
                        SizedBox(width: TextSizing.fontSizeText(context) * 6),
                      SizedBox(
                        width: TextSizing.fontSizeText(context),
                        height: TextSizing.fontSizeText(context) * 4,
                      ),
                    ],
                  ),
                ],
              ),

              // === Evening Service Info ===
              now.hour >= startEveningService
                  ? Column(
                      children: [
                        SizedBox(height: TextSizing.fontSizeHeading(context)),
                        EveningStartPoint.getBusTime(
                          widget.selectedBox,
                          context,
                          widget.isDarkMode,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: TextSizing.fontSizeMiniText(context)),
                        Text(
                          'ETAs will be shown in the afternoon',
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.blueGrey[400]
                                : Colors.blueGrey[600],
                            fontFamily: 'Roboto',
                            fontSize: TextSizing.fontSizeText(context),
                          ),
                        ),
                        SizedBox(height: TextSizing.fontSizeText(context)),
                      ],
                    ),
            ],
          );
  }
}
