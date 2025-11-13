import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/global.dart';
import '../services/get_afternoon_eta.dart';
import '../utils/get_time.dart';
import '../utils/loading.dart';
import '../utils/styling_line_and_buttons.dart';
import '../utils/text_styles_booking_confirmation.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Afternoon Screen ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Booking Confirmation class
// used to show the booking confirmation when user books a trip

class BookingConfirmation extends StatefulWidget {
  // Index of the selected booking option (e.g., which trip card was tapped)
  final int selectedBox;

  // Index of the booked trip for KAP and CLE stops (nullable if not booked)
  final int? bookedTripIndexKAP;
  final int? bookedTripIndexCLE;

  // Booked departure time (nullable)
  final DateTime? bookedDepartureTime;

  // Async callback to execute when booking is cancelled
  final Future<void> Function()? onCancel;

  // Name of the bus stop
  final String? busStop;

  // for sizing
  final double fontSizeMiniText;
  final double fontSizeText;
  final double fontSizeHeading;

  const BookingConfirmation({
    super.key,
    required this.selectedBox,
    required this.bookedTripIndexKAP,
    required this.bookedTripIndexCLE,
    required this.bookedDepartureTime,
    required this.onCancel,
    required this.busStop,
    required this.fontSizeMiniText,
    required this.fontSizeText,
    required this.fontSizeHeading,
  });

  @override
  State<BookingConfirmation> createState() => _BookingConfirmationState();
}

class _BookingConfirmationState extends State<BookingConfirmation> {
  final Duration timeUpdateInterval = const Duration(seconds: 1);
  final Duration apiFetchInterval = const Duration(minutes: 1);

  int secondsElapsed = 0;
  Timer? _clockTimer;

  // Added loading flag to track time fetch status
  bool _loading = true;

  // If trip has started/was in the past no cancel option should be given
  bool canCancel = true;

  //////////////////////////////////////////////////////////////////////////////
  // initState

  @override
  void initState() {
    super.initState();

    // Start initialization flow that is allowed to be asynchronous.
    // We don't mark initState as async; use a fire-and-forget helper.
    _initializeTimeAndTimers();
  }

  //////////////////////////////////////////////////////////////////////////////
  // Async initializer started from initState.

  Future<void> _initializeTimeAndTimers() async {
    // Fetch the current time from the API first. getTime must be implemented
    // to avoid calling setState when !mounted.
    final TimeService timeService = TimeService();
    if (!mounted) return;

    // Mark loading complete once time is fetched (or attempted)
    setState(() {
      _loading = false;
    });

    // Start a periodic timer to update the time every second.
    timeService.getTime().then((_) {
      _clockTimer = Timer.periodic(timeUpdateInterval, (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // Increment local time representation synchronously
        updateTimeManually();
        secondsElapsed += timeUpdateInterval.inSeconds;

        // Every [apiFetchInterval], refresh the time from the API as a fire-and-forget Future.
        if (secondsElapsed >= apiFetchInterval.inSeconds) {
          secondsElapsed = 0;
        }
      });
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // dispose to cancel timers

  @override
  void dispose() {
    // Cancel timer to prevent callbacks after disposal
    _clockTimer?.cancel();
    _clockTimer = null;
    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to generate 'random' colors based on booked trip

  Color? generateColor(DateTime? departureTime, int selectedTripNo) {
    if (timeNow == null || departureTime == null) return null;

    final List<Color?> colors = [
      Colors.red[100],
      Colors.red[200],
      Colors.orange[200],
      Colors.orange[100],
      Colors.yellow[200],
      Colors.green[200],
      Colors.blue[200],
      Colors.indigo[100],
      Colors.deepPurple[200],
      Colors.purple[200],
    ];

    // Seconds since midnight for both times.
    final int departureSeconds =
        departureTime.hour * 3600 +
        departureTime.minute * 60 +
        departureTime.second;

    final int nowSeconds =
        timeNow!.hour * 3600 + timeNow!.minute * 60 + timeNow!.second;

    // Day index to vary deterministically day by day.
    final int dayIndex =
        DateTime(
          timeNow!.year,
          timeNow!.month,
          timeNow!.day,
        ).millisecondsSinceEpoch ~/
        (1000 * 60 * 60 * 24);

    // Combine components; bucket by 10 seconds for coarse stability.
    final int combined =
        (departureSeconds + nowSeconds + dayIndex) & 0x7fffffff;
    final int seed = combined ~/ 10;

    final Random random = Random(seed);
    final int index = random.nextInt(colors.length);

    return colors[index];
  }

  void updateTimeManually() {
    if (timeNow == null || !mounted) return;
    setState(() {
      timeNow = timeNow!.add(timeUpdateInterval);
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // Shows a confirmation dialog before cancelling the booking.
  // If the user confirms, it triggers the onCancel callback and
  // clears booking data from shared preferences.

  void showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
          actionsAlignment: MainAxisAlignment.center,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    color: Colors.redAccent,
                    size: widget.fontSizeHeading,
                  ),
                  SizedBox(width: widget.fontSizeMiniText),
                  Flexible(
                    child: Text(
                      'Cancel Booking',
                      softWrap: true,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: widget.fontSizeHeading,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.fontSizeText,
              vertical: widget.fontSizeMiniText,
            ),
            child: Text(
              softWrap: true,
              "Are you sure you want to cancel this booking?",
              style: TextStyle(
                fontFamily: 'Roboto',
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: widget.fontSizeText,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "No",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  fontSize: widget.fontSizeText,
                  color: isDarkMode
                      ? Colors.tealAccent
                      : const Color(0xff014689),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                "Yes",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  fontSize: widget.fontSizeText,
                  color: isDarkMode
                      ? Colors.tealAccent
                      : const Color(0xff014689),
                ),
              ),
              onPressed: () async {
                // Close the dialog synchronously to avoid using the dialog BuildContext across async gaps
                Navigator.of(context).pop();

                // Let the parent handle cancellation, persistence, and state updates.
                if (widget.onCancel != null) {
                  try {
                    await widget.onCancel!();
                  } catch (e) {
                    if (kDebugMode) print('Error in onCancel callback: $e');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // Booking Card

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('booking_confirmation built');

    // Determine which booked trip index to use based on the selected box:// If selectedBox == 1, use KAP index; otherwise, use CLE index.

    final int? bookedTripIndex = widget.selectedBox == 1
        ? widget.bookedTripIndexKAP
        : widget.bookedTripIndexCLE;

    // Retrieve the booked departure time passed from parent.
    final DateTime? bookedTime = widget.bookedDepartureTime;

    // Determine whether cancel button should be shown: only if bookedTime is in the future compared to timeNow
    final DateTime now = timeNow ?? DateTime.now();
    canCancel = bookedTime != null
        ? bookedTime.isAfter(now) || bookedTime.isAtSameMomentAs(now)
        : false;

    // Determine the station name based on the selected box.
    final String station = widget.selectedBox == 1
        ? 'KAP'
        : widget.selectedBox == 2
        ? 'CLE'
        : '-';

    // Use loading flag instead of relying on timeNow directly
    if (_loading || timeNow == null) {
      if (kDebugMode) {
        print('time now = $timeNow'); // Debug log for troubleshooting
      }
      return LoadingScroll();
    }

    // Determine card color with null-safe fallback
    final Color cardColor =
        generateColor(bookedTime, bookedTripIndex ?? 0) ?? Colors.white;

    // Guard: if there is no booked trip index or booked time, show a user friendly empty state
    if (bookedTripIndex == null || bookedTime == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(widget.fontSizeText),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trip cannot be found. Booking will now be cancelled.',
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.blueGrey[200]
                      : Colors.blueGrey[500],
                  fontSize: widget.fontSizeText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
              SizedBox(height: widget.fontSizeText),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: (isDarkMode
                      ? Colors.blueGrey[50]
                      : const Color(0xff014689)), // Button background color
                  foregroundColor: (isDarkMode
                      ? Colors.blueGrey[900]
                      : Colors.white),
                ), // Text color
                onPressed: () async {
                  // If the parent passed an async cancel function, call it via showCancelDialog or directly.
                  if (widget.onCancel != null) {
                    await widget.onCancel!();
                  }
                },
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontSize: widget.fontSizeText,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Main UI layout for the booking confirmation screen
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,

      // Center children horizontally
      children: [
        Center(
          // Wrap card in Center to align it horizontally
          child: _BookingDetailsCard(
            bookedTripIndex: bookedTripIndex,
            bookedTime: bookedTime,
            station: station,
            busStop: widget.busStop ?? '', // Fallback to empty string if null
            color: cardColor, // Dynamic background color with fallback
            canCancel: canCancel,
            onCancel: showCancelDialog, // Show cancel confirmation dialog
            fontSizeMiniText: widget.fontSizeMiniText,
            fontSizeText: widget.fontSizeText,
            fontSizeHeading: widget.fontSizeHeading,
            // Note: onCancel is synchronous dialog trigger; parent will handle async persistence
          ),
        ),
        SizedBox(height: widget.fontSizeHeading),
        // Show Afternoon service bus time only if current hour is after service start
        if (timeNow != null && timeNow!.hour >= startAfternoonETA)
          Center(
            // Wrap bus time in Center to align it horizontally
            child: AfternoonETAsAutoRefresh(box: widget.selectedBox),
          ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// Layout for Booking Details

class _BookingDetailsCard extends StatelessWidget {
  final int? bookedTripIndex; // Index of the booked trip
  final DateTime? bookedTime; // Departure time of the booked trip
  final String station; // Station name (KAP or CLE)
  final String busStop; // Bus stop name
  final Color? color; // Background color for the card
  final bool? canCancel;
  final VoidCallback onCancel; // Callback for cancel button
  final double fontSizeMiniText; // for sizing
  final double fontSizeText;
  final double fontSizeHeading;

  const _BookingDetailsCard({
    required this.bookedTripIndex,
    required this.bookedTime,
    required this.station,
    required this.busStop,
    required this.color,
    required this.canCancel,
    required this.onCancel,
    required this.fontSizeMiniText,
    required this.fontSizeText,
    required this.fontSizeHeading,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('bookingDetailsCard built');
    // Defensive local values
    final int displayIndex = (bookedTripIndex ?? 0) + 1;
    final String dateLabel = bookedTime != null
        ? '[${bookedTime!.day.toString().padLeft(2, '0')}.${bookedTime!.month.toString().padLeft(2, '0')}.${bookedTime!.year.toString()}]'
        : '-';
    final String timeLabel = bookedTime != null
        ? '${bookedTime!.hour.toString().padLeft(2, '0')}:${bookedTime!.minute.toString().padLeft(2, '0')}'
        : '-';
    final String stopLabel = busStop.isNotEmpty ? busStop : '-';

    return Padding(
      padding: EdgeInsets.all(fontSizeText), // Outer padding around the card
      child: Container(
        color: color, // Apply dynamic background color
        child: Padding(
          padding: EdgeInsets.all(
            fontSizeText * 0.5,
          ), // Inner padding inside the card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              SizedBox(height: fontSizeText * 0.5), // Small top spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    color: Colors.black,
                    size: fontSizeHeading,
                  ), // Calendar/check icon
                  SizedBox(
                    width: fontSizeText * 0.5,
                  ), // Space between icon and text
                  Flexible(
                    child: Text(
                      'Booking Confirmation',
                      maxLines: 1, //  limits to 1 lines
                      overflow:
                          TextOverflow.ellipsis, // clips text if not fitting
                      style: TextStyle(
                        fontSize: fontSizeHeading,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: fontSizeMiniText),
              Text(
                // Date of Trip
                dateLabel,
                style: TextStyle(
                  fontSize: fontSizeMiniText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  color: Colors.black,
                ),
              ),
              SizedBox(height: fontSizeText),

              // Display trip number (index + 1 for human-readable numbering)
              BookingConfirmationText(
                label: 'Trip Number',
                value: bookedTripIndex != null ? '$displayIndex' : '-',
                size: 1,
                darkText: true,
                fontSizeText: fontSizeText,
              ),
              DrawLine(fontSizeText: fontSizeText), // Divider line
              // Display departure time in HH:mm format
              BookingConfirmationText(
                label: 'Time',
                value: timeLabel,
                size: 1,
                darkText: true,
                fontSizeText: fontSizeText,
              ),
              DrawLine(fontSizeText: fontSizeText),
              // Display station name
              BookingConfirmationText(
                label: 'Station',
                value: station,
                size: 1,
                darkText: true,
                fontSizeText: fontSizeText,
              ),
              DrawLine(fontSizeText: fontSizeText),
              // Display bus stop name
              BookingConfirmationText(
                label: 'Bus Stop',
                value: stopLabel,
                size: 1,
                darkText: true,
                fontSizeText: fontSizeText,
              ),
              SizedBox(height: fontSizeText),
              // Cancel button row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: fontSizeText,
                      bottom: fontSizeText * 1.5,
                    ),
                    // if trip has already started, cannot cancel anymore
                    child: ElevatedButton(
                      style: ButtonStyle(
                        elevation: WidgetStateProperty.all(0),
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>((
                              Set<WidgetState> states,
                            ) {
                              if (states.contains(WidgetState.disabled)) {
                                return const Color.fromRGBO(
                                  38,
                                  50,
                                  56,
                                  0.75,
                                ); // Background when disabled
                              }
                              return Colors
                                  .blueGrey[900]; // Button background color
                            }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color?>((
                              Set<WidgetState> states,
                            ) {
                              if (states.contains(WidgetState.disabled)) {
                                return color; // Text color when disabled
                              }
                              return Colors.white; // Text (and icon) color
                            }),
                      ),

                      onPressed: canCancel == true
                          ? onCancel // Trigger cancel dialog
                          : null, // grey out button if trip already started
                      child: Padding(
                        padding: EdgeInsets.all(fontSizeText * 0.33),
                        child: Text(
                          canCancel == true ? 'Cancel' : 'Have a good trip! [:',
                          maxLines: 1, //  limits to 1 lines
                          overflow: TextOverflow
                              .ellipsis, // clips text if not fitting
                          style: TextStyle(
                            fontSize: fontSizeText,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
