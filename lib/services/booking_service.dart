import 'dart:async'; // For Timer functionality

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/global.dart'; // contains shared global variables/constants
import '../services/get_afternoon_eta.dart'; // Service for Afternoon bus logic
import '../utils/get_time.dart';
import '../utils/loading.dart'; // Custom loading widget
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Booking Service ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// BookingService class
// used for booking trips in the afternoon

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

  // Callbacks to update booking status for KAP and CLE trips
  final Function(int index, bool newValue) updateBookingStatusKAP;
  final Function(int index, bool newValue) updateBookingStatusCLE;

  // Function to count bookings for a given MRT station and trip index
  final Future<int?> Function(String mrt, int index) countBooking;

  // Function to show the bus stop selection bottom sheet
  final Function showBusStopSelectionBottomSheet;

  // Selected BusStop
  final String selectedBusStop;

  const BookingService({
    super.key,
    required this.departureTimes,
    required this.selectedBox,
    required this.bookedTripIndexKAP,
    required this.bookedTripIndexCLE,
    required this.onPressedConfirm,
    required this.countBooking,
    required this.updateBookingStatusKAP,
    required this.updateBookingStatusCLE,
    required this.showBusStopSelectionBottomSheet,
    required this.selectedBusStop,
  });

  @override
  State<BookingService> createState() => BookingServiceState();
}

class BookingServiceState extends State<BookingService> {
  Future<void> refreshFromParent(bool refreshBecauseTripFull) async {
    if (kDebugMode) {
      print('booking service is being refreshed by parent');
    }
    if (refreshBecauseTripFull == true) {
      if (!mounted) return;
      setState(() {
        _loading = true;
        bookingCounts = {};
      });
    }
    await setTime();
    await _updateBookingCounts();
  }

  // Default color for UI elements before availability is determined
  Color finalColor = Colors.grey;

  // needed to use getTime()
  TimeService updateTime = TimeService();

  // Stores booking counts for each trip index
  // Key: trip index, Value: number of bookings (nullable if not yet fetched)
  late Map<int, int?> bookingCounts;

  // Whether booking data is still loading
  bool _loading = true;

  // prevents overlapping refreshes
  bool _updating = false;

  // Thresholds for vacancy color coding
  int vacancyGreen = (busMaxCapacity / 2).floor(); // Below this count = green
  int vacancyYellow = (busMaxCapacity / 2)
      .floor(); // above/including this, below maxCapacity yellow and red inclusive = yellow
  int vacancyRed = busMaxCapacity; // At this count = red (full)

  // Current time snapshot (may be used for filtering trips)
  DateTime now = DateTime.now();

  // To prevent pressing confirm multiple times
  bool confirmingBooking = false;

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  // Checks if the user can confirm a booking.
  // Returns true if a trip index is selected for the current station.
  bool canConfirm() {
    if (widget.selectedBox == 1
        ? widget.bookedTripIndexKAP == null
        : widget.bookedTripIndexCLE == null) {
      busIndex.value = 0;
    }
    return widget.selectedBox == 1
        ? widget.bookedTripIndexKAP != null && busIndex.value != 0
        : widget.bookedTripIndexCLE != null && busIndex.value != 0;
  }

  ///////////////////////////////////////////////////////////////
  // If the selected station changes, reset loading state and booking counts

  @override
  void didUpdateWidget(covariant BookingService oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool timesChanged =
        oldWidget.departureTimes.length != widget.departureTimes.length ||
        !_listsEqual(oldWidget.departureTimes, widget.departureTimes);
    if (oldWidget.selectedBox != widget.selectedBox || timesChanged) {
      if (!mounted) return;
      setState(() {
        _loading = true;
        bookingCounts = {};
      });
      _updateBookingCounts();
    }
  }

  // helper to compare DateTime lists
  bool _listsEqual(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    bookingCounts = {};
    confirmingBooking = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  @override
  void dispose() {
    super.dispose();
    confirmingBooking = false;
  }

  // Fetches booking counts for all departure times and updates state.
  Future<void> _updateBookingCounts() async {
    if (_updating) return; // avoid overlapping calls
    _updating = true;

    try {
      final expectedCount = widget.departureTimes.length;
      final expectedIndices = List<int>.generate(expectedCount, (i) => i);

      // Remove stale entries (indices >= current length)
      final staleKeys = bookingCounts.keys
          .where((k) => k >= expectedCount)
          .toList();
      if (staleKeys.isNotEmpty) {
        // If a stale booked index exists, clear booking selection
        if (staleKeys.contains(widget.bookedTripIndexKAP ?? -1) &&
            widget.bookedTripIndexKAP != null) {
          widget.updateBookingStatusKAP(widget.bookedTripIndexKAP!, false);
        }
        if (staleKeys.contains(widget.bookedTripIndexCLE ?? -1) &&
            widget.bookedTripIndexCLE != null) {
          widget.updateBookingStatusCLE(widget.bookedTripIndexCLE!, false);
        }
        if (!mounted) return;
        setState(() {
          for (final k in staleKeys) {
            bookingCounts.remove(k);
          }
        });
      }

      // Find indices that need fetching (missing or null)
      final toFetch = <int>[];
      for (final i in expectedIndices) {
        if (!bookingCounts.containsKey(i) || bookingCounts[i] == null) {
          toFetch.add(i);
        }
      }

      if (toFetch.isEmpty) {
        if (_loading && mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      // Fire parallel requests for only needed indices
      final results = <int, int?>{};
      final futures = toFetch.map((i) async {
        final tripNumber = i + 1; // server uses 1-based numbering
        try {
          final count = await widget.countBooking(
            widget.selectedBox == 1 ? 'KAP' : 'CLE',
            tripNumber,
          );
          results[i] = count;
        } catch (_) {
          // keep null on error so it will retry next cycle
          results[i] = null;
        }
      }).toList();

      await Future.wait(futures);

      // Batch apply updates once
      if (mounted) {
        setState(() {
          results.forEach((i, c) => bookingCounts[i] = c);
          _loading = false;
        });
      } else {
        results.forEach((i, c) => bookingCounts[i] = c);
        _loading = false;
      }
    } finally {
      _updating = false;
    }
  }

  // Set time through timeAPI
  Future<void> setTime() async {
    now = (await updateTime.getTime()) ?? DateTime.now();
  }

  ///////////////////////////////////////////////////////////////
  // Returns a color based on the number of bookings:
  // - Green: plenty of space left
  // - Yellow: more than half full already
  // - Red: full

  Color _getColor(int count) {
    if (count < vacancyGreen) {
      return Colors.green[400]!;
    } else if (count >= vacancyGreen && count < busMaxCapacity) {
      return Color(0xfffeb041);
    } else {
      return Colors.red[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine text color based on dark mode setting
    if (kDebugMode) debugPrint('booking_service built');
    Color darkText = isDarkMode ? Colors.white : Colors.black;

    // If still loading booking data, show a loading widget
    return _loading == true
        ? LoadingScroll()
        : Column(
            children: [
              SizedBox(height: fontSizeMiniText * 0.8),
              Text(
                widget.selectedBox == 1
                    ? 'Bus to King Albert Park'
                    : 'Bus to Clementi',
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: fontSizeHeading,
                  color: darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // === Capacity Indicator Title ===
              Text(
                'Capacity Indicator',
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: fontSizeText,
                  color: darkText,
                ),
              ),

              SizedBox(height: fontSizeMiniText),

              // === Legend Row: Available & Half Full ===
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Available indicator
                  Container(
                    width: MediaQuery.of(context).size.width * 0.1,
                    height: fontSizeText * 0.25,
                    color: Colors.green[400],
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.015),
                  Flexible(
                    child: Text(
                      'Available',
                      maxLines: 1, //  limits to 1 lines
                      overflow:
                          TextOverflow.ellipsis, // clips text if not fitting
                      style: TextStyle(
                        color: darkText,
                        fontSize: fontSizeMiniText,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),

                  // spacing in between
                  Flexible(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.06,
                    ),
                  ),

                  // Half full indicator
                  Container(
                    width: MediaQuery.of(context).size.width * 0.1,
                    height: fontSizeText * 0.25,
                    color: Color(0xfffeb041),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                  Flexible(
                    child: Text(
                      '> Half Full',
                      maxLines: 1, //  limits to 1 lines
                      overflow:
                          TextOverflow.ellipsis, // clips text if not fitting
                      style: TextStyle(
                        color: darkText,
                        fontSize: fontSizeMiniText,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),

                  // spacing in between
                  Flexible(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.06,
                    ),
                  ),

                  // Full indicator
                  Container(
                    width: MediaQuery.of(context).size.width * 0.1,
                    height: fontSizeText * 0.25,
                    color: Colors.red, // Full indicator
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                  Flexible(
                    child: Text(
                      'FULL',
                      maxLines: 1, //  limits to 1 lines
                      overflow:
                          TextOverflow.ellipsis, // clips text if not fitting
                      style: TextStyle(
                        color: darkText,
                        fontSize: fontSizeMiniText,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: fontSizeText * 1.5),

              if (widget.departureTimes.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        TextSizing.isLandscapeMode(context)
                            ? '* Departure time stated refers to bus stop at entrance (ENT). Check below for more information about the other stops.'
                            : '* Departure time stated refers to bus stop at entrance (ENT).\nCheck below for more information about the other stops.',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          color: (isDarkMode ? Colors.white : Colors.black),
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),

              if (widget.departureTimes.isEmpty)
                Column(
                  children: [
                    SizedBox(height: fontSizeHeading * 2),
                    Text(
                      'no Trips found - check Internet connection',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.blueGrey[400]
                            : Colors.blueGrey[600],
                        fontFamily: 'Roboto',
                        fontSize: fontSizeText,
                      ),
                    ),
                  ],
                ),

              // === List of Departure Trips ===
              if (widget.departureTimes.isNotEmpty)
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
                        (index == widget.bookedTripIndexKAP) &&
                        busIndex.value != 0;
                    bool isBookedCLE =
                        (index == widget.bookedTripIndexCLE) &&
                        busIndex.value != 0;

                    // Current booking count for this trip
                    int? count = bookingCounts[index];

                    // Whether this trip is full
                    bool isFull = (count != null && count >= vacancyRed);

                    // cannot book if its way then trip time
                    return (time.hour > now.hour ||
                            time.hour == now.hour && time.minute > now.minute)
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              fontSizeText,
                              0.0,
                              fontSizeText,
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
                                    // if time now > trip time, trip wont be offered to book anymore
                                    Expanded(
                                      child: Card(
                                        elevation: 0,
                                        color: count!= null ? isFull
                                            ? (isDarkMode
                                                  ? Colors.blueGrey[800]
                                                  : Colors.grey[300])
                                            : (isDarkMode
                                                  ? Colors.blueGrey[600]
                                                  : Colors.blue[50]) : isDarkMode
                                            ? Colors.blueGrey[700]
                                            : Colors.grey[200],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            0.0,
                                          ), // Square corners
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            0,
                                            fontSizeText,
                                            0,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Capacity color bar (only if count known)
                                              Container(
                                                width:
                                                    TextSizing.fontSizeText(
                                                      context,
                                                    ) *
                                                    0.5,
                                                height:
                                                TextSizing.fontSizeText(
                                                      context,
                                                    ) *
                                                    4,
                                                color: count != null
                                                    ? _getColor(count)
                                                    : (isDarkMode
                                                          ? Colors.blueGrey[400]
                                                          : Colors
                                                                .blueGrey[300]),
                                              ),
                                              Expanded(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    Text(
                                                      '  Trip ${index + 1}',
                                                      textAlign:
                                                          TextAlign.center,
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines:
                                                          1, //  limits to 1 lines
                                                      style: TextStyle(
                                                        fontFamily: 'Roboto',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            TextSizing.fontSizeText(
                                                              context,
                                                            ),
                                                        color: isFull
                                                            ? (isDarkMode
                                                                  ? Colors
                                                                        .blueGrey[400]
                                                                  : Colors
                                                                        .grey[600])
                                                            : (isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black),
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
                                                            ? (isDarkMode
                                                                  ? Colors
                                                                        .blueGrey[500]
                                                                  : Colors
                                                                        .grey[600])
                                                            : (isDarkMode
                                                                  ? Colors
                                                                        .blueGrey[200]
                                                                  : Colors
                                                                        .blueGrey[500]),
                                                      ),
                                                    ),

                                                    // Departure time
                                                    Flexible(
                                                      child: Text(
                                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} *',

                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines:
                                                            1, //  limits to 1 lines
                                                        style: TextStyle(
                                                          fontFamily: 'Roboto',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize:
                                                              TextSizing.fontSizeText(
                                                                context,
                                                              ),
                                                          color: isFull
                                                              ? (isDarkMode
                                                                    ? Colors
                                                                          .blueGrey[400]
                                                                    : Colors
                                                                          .grey[600])
                                                              : (isDarkMode
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black),
                                                        ),
                                                      ),
                                                    ),
                                                    // Vertical divider
                                                    Flexible(
                                                      child: Padding(
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
                                                              ? (isDarkMode
                                                                    ? Colors
                                                                          .blueGrey[500]
                                                                    : Colors
                                                                          .grey[600])
                                                              : (isDarkMode
                                                                    ? Colors
                                                                          .blueGrey[200]
                                                                    : Colors
                                                                          .blueGrey[500]),
                                                        ),
                                                      ),
                                                    ),

                                                    if (canConfirm())
                                                      Flexible(
                                                        child: Text(
                                                          widget
                                                              .selectedBusStop,
                                                          textAlign:
                                                              TextAlign.center,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines:
                                                              1, //  limits to 1 lines
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Roboto',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize:
                                                                TextSizing.fontSizeText(
                                                                  context,
                                                                ),
                                                            color: isFull
                                                                ? (isDarkMode
                                                                      ? Colors
                                                                            .blueGrey[400]
                                                                      : Colors
                                                                            .grey[600])
                                                                : (isDarkMode
                                                                      ? Colors
                                                                            .white
                                                                      : Colors
                                                                            .black),
                                                          ),
                                                        ),
                                                      ),
                                                    if (!canConfirm())
                                                      Flexible(
                                                        child: Text(
                                                          ' ---- ',
                                                          textAlign:
                                                              TextAlign.center,
                                                          overflow:
                                                              TextOverflow.clip,
                                                          maxLines:
                                                              1, //  limits to 1 lines
                                                          style: TextStyle(
                                                            fontSize:
                                                                TextSizing.fontSizeText(
                                                                  context,
                                                                ),
                                                            color: isFull
                                                                ? (isDarkMode
                                                                      ? Colors
                                                                            .blueGrey[400]
                                                                      : Colors
                                                                            .grey[600])
                                                                : (isDarkMode
                                                                      ? Colors
                                                                            .white
                                                                      : Colors
                                                                            .black),
                                                            fontFamily:
                                                                'Roboto',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
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
                                      onTap:
                                          (isFull ||
                                              count == null ||
                                              confirmingBooking) // prevent taps when necessary
                                          ? null // Disable tap if full
                                          : () {
                                              if (!isFull) {
                                                if (widget.selectedBox == 1) {
                                                  // KAP station booking logic
                                                  if (!isBookedKAP) {
                                                    widget
                                                        .updateBookingStatusKAP(
                                                          index,
                                                          true,
                                                        );
                                                    if (busIndex.value == 0) {
                                                      widget
                                                          .showBusStopSelectionBottomSheet(
                                                            context,
                                                          );
                                                    }
                                                  } else {
                                                    busIndex.value = 0;
                                                    widget
                                                        .updateBookingStatusKAP(
                                                          index,
                                                          false,
                                                        );
                                                  }
                                                } else {
                                                  // CLE station booking logic
                                                  if (!isBookedCLE) {
                                                    widget
                                                        .updateBookingStatusCLE(
                                                          index,
                                                          true,
                                                        );
                                                    if (busIndex.value == 0) {
                                                      widget
                                                          .showBusStopSelectionBottomSheet(
                                                            context,
                                                          );
                                                    }
                                                  } else {
                                                    busIndex.value = 0;
                                                    widget
                                                        .updateBookingStatusCLE(
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
                                                  : Icons
                                                        .check_box_outline_blank)
                                            : (isBookedCLE
                                                  ? Icons.check_box
                                                  : Icons
                                                        .check_box_outline_blank),
                                        color: count != null ? isFull
                                            ? (isDarkMode
                                                  ? Colors.blueGrey[500]
                                                  : Colors.grey[400])
                                            : (isDarkMode
                                                  ? Colors.blueGrey[50]
                                                  : const Color(0xff014689)) : (isDarkMode
                                            ? Colors.blueGrey[400]
                                            : Colors
                                            .blueGrey[300]),
                                        size: fontSizeHeading,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : SizedBox();
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
                            padding: EdgeInsets.all(fontSizeText),
                            child: confirmingBooking
                                ? LoadingScreen()
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: (isDarkMode
                                          ? Colors.blueGrey[50]
                                          : const Color(
                                              0xff014689,
                                            )), // Button background color
                                      foregroundColor: (isDarkMode
                                          ? Colors.blueGrey[900]
                                          : Colors.white),
                                    ), // Text color
                                    onPressed: () {
                                      setState(() {
                                        confirmingBooking = true;
                                      });
                                      widget.onPressedConfirm();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        fontSizeText * 0.33,
                                      ),
                                      child: Text(
                                        softWrap: true,
                                        textAlign: TextAlign.center,
                                        'Confirm',
                                        style: TextStyle(
                                          fontSize: TextSizing.fontSizeText(
                                            context,
                                          ),
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      if (!canConfirm()) SizedBox(width: fontSizeText * 6),
                      SizedBox(width: fontSizeText, height: fontSizeText * 4),
                    ],
                  ),
                ],
              ),

              // === Afternoon Service Info ===
              if (widget.departureTimes.isNotEmpty)
                now.hour >= startAfternoonETA
                    ? Column(
                        children: [
                          SizedBox(height: fontSizeHeading),
                          AfternoonETAsAutoRefresh(box: widget.selectedBox),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(height: fontSizeMiniText),
                          Text(
                            'ETAs will be shown in the afternoon',
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.blueGrey[400]
                                  : Colors.blueGrey[600],
                              fontFamily: 'Roboto',
                              fontSize: fontSizeText,
                            ),
                          ),
                          SizedBox(height: fontSizeText),
                        ],
                      ),
            ],
          );
  }
}
