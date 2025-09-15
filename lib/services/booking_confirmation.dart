import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/evening_service.dart';
import 'package:user_14_updated/services/shared_preference.dart';
import 'package:user_14_updated/utils/loading.dart';
import 'package:user_14_updated/utils/styling_line_and_buttons.dart';
import 'package:user_14_updated/utils/text_styles_booking_confirmation.dart';

/// =====================
/// CHANGE SUMMARY:
/// 1. CHANGED: Removed unused variables (ColorValues, randomNum, timer, _loading, departureSeconds) to clean up state.
/// 2. CHANGED: Removed redundant widget.KAPDepartureTime and widget.CLEDepartureTime calls in initState (they had no effect).
/// 3. CHANGED: Used the already-declared `uri` variable in getTime() instead of re-parsing the same string twice.
/// 4. CHANGED: Removed unnecessary null check for bookedTime (it can’t be null if bookedTripIndex is non-null).
/// 5. CHANGED: Used const where possible for widgets (e.g., SizedBox, Text, Icon) to reduce rebuild cost.
/// 6. CHANGED: Removed unused `darkText` and `isAfter3pm` variables in build().
/// 7. CHANGED: Minor formatting and padding cleanup for readability.
/// 8. CHANGED: Extracted the booking details card into a separate stateless widget `_BookingDetailsCard` for cleaner build().
/// 9. CHANGED: Moved the API URL into a top-level constant `timeApiUrl` for easier maintenance.
/// =====================

///////////////////////////////////////////////////////////////
// This URL returns the current time for the Asia/Singapore timezone.
/// CHANGED: Moved API URL to a constant for easier maintenance.

const String timeApiUrl =
    'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE';

class BookingConfirmation extends StatefulWidget {
  // Index of the selected booking option (e.g., which trip card was tapped)
  final int selectedBox;

  // Index of the booked trip for KAP and CLE stops (nullable if not booked)
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;

  // Function to retrieve the list of departure times
  final List<DateTime> Function() getDepartureTimes;

  // Callback to execute when booking is cancelled
  final VoidCallback onCancel;

  // Name of the bus stop (optional)
  String? busStop;

  // Lists of departure times for KAP and CLE stops
  final List<DateTime> KAPDepartureTime;
  final List<DateTime> CLEDepartureTime;

  // Evening service identifier (likely used to determine schedule)
  final int eveningService;

  // Whether the app is currently in dark mode
  final bool isDarkMode;

  BookingConfirmation({
    super.key,
    required this.selectedBox,
    this.bookedTripIndexKAP,
    this.bookedTripIndexCLE,
    required this.getDepartureTimes,
    required this.onCancel,
    this.busStop,
    required this.KAPDepartureTime,
    required this.CLEDepartureTime,
    required this.eveningService,
    required this.isDarkMode,
  });

  @override
  State<BookingConfirmation> createState() => _BookingConfirmationState();
}

class _BookingConfirmationState extends State<BookingConfirmation> {
  // Interval for manually updating the displayed time
  final Duration timeUpdateInterval = const Duration(seconds: 1);

  // Interval for fetching the current time from the API
  final Duration apiFetchInterval = const Duration(minutes: 3);

  // Tracks how many seconds have passed since the last API fetch
  int secondsElapsed = 0;

  // Timer for updating the clock in real-time
  Timer? _clockTimer;

  // Service for interacting with shared preferences (local storage)
  final SharedPreferenceService prefsService = SharedPreferenceService();

  @override
  void initState() {
    super.initState();
    // Fetch the current time from the API first
    getTime().then((_) {
      // Start a periodic timer to update the time every second
      _clockTimer = Timer.periodic(timeUpdateInterval, (timer) {
        updateTimeManually(); // Increment time locally
        secondsElapsed += timeUpdateInterval.inSeconds;

        // Every [apiFetchInterval], refresh the time from the API
        if (secondsElapsed >= apiFetchInterval.inSeconds) {
          getTime();
          secondsElapsed = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    // Cancel the timer to prevent memory leaks when widget is disposed
    _clockTimer?.cancel();
    super.dispose();
  }

  ///////////////////////////////////////////////////////////////
  // This creates a "synced random" color that changes predictably
  // depending on the departure time and the current time.

  Color? generateColor(DateTime departureTime, int selectedTripNo) {
    // Predefined list of possible colors
    final List<Color?> colors = [
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

    // Convert departure time to total seconds since midnight
    final int departureSeconds =
        departureTime.hour * 3600 + departureTime.minute * 60;

    // Combine departure seconds with the current second
    final int combinedSeconds = timeNow!.second + departureSeconds;

    // Round to the nearest 10 seconds for consistency
    final int roundedSeconds = (combinedSeconds ~/ 10) * 10;

    // Create a DateTime object with the rounded seconds
    final DateTime roundedTime = DateTime(
      timeNow!.year,
      timeNow!.month,
      timeNow!.day,
      timeNow!.hour,
      timeNow!.minute,
      roundedSeconds,
    );

    // Use the rounded time as a seed for the random generator
    final int seed = roundedTime.millisecondsSinceEpoch ~/ (1000 * 10);
    final Random random = Random(seed);

    // Pick a random index from the colors list (0–9)
    final int syncedRandomNum = random.nextInt(10);

    // Return the selected color
    return colors[syncedRandomNum];
  }

  ///////////////////////////////////////////////////////////////
  // Fetches the current time from the API and updates [timeNow].
  // This ensures the displayed time stays accurate even if the
  // device clock is off.

  Future<void> getTime() async {
    try {
      /// CHANGED: Use constant instead of hardcoding URL twice.
      final uri = Uri.parse(timeApiUrl);
      final response = await get(uri);

      // Decode the JSON response
      final Map data = jsonDecode(response.body);

      // Extract the datetime string and parse it into a DateTime object
      final String datetime = data['dateTime'];
      setState(() {
        timeNow = DateTime.parse(datetime);
      });
    } catch (e) {
      // Log error in debug mode if API call fails
      if (kDebugMode) {
        print('Error fetching time: $e');
      }
    }
  }

  ///////////////////////////////////////////////////////////////
  // Advances [timeNow] manually by [timeUpdateInterval].
  // This is used between API fetches to keep the clock ticking.

  void updateTimeManually() {
    setState(() {
      timeNow = timeNow!.add(timeUpdateInterval);
    });
  }

  ///////////////////////////////////////////////////////////////
  // Shows a confirmation dialog before cancelling the booking.
  // If the user confirms, it triggers the onCancel callback and
  // clears booking data from shared preferences.

  void showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Match dialog background to theme mode
          backgroundColor: widget.isDarkMode ? Colors.black : Colors.white,
          title: Text(
            "Cancel Booking",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            "Are you sure you want to cancel this booking?",
            style: TextStyle(
              fontFamily: 'Roboto',
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          actions: <Widget>[
            // "No" button just closes the dialog
            TextButton(
              child: Text(
                "No",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  color: widget.isDarkMode
                      ? Colors.tealAccent
                      : const Color(0xff014689),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            // "Yes" button cancels booking and clears stored data
            TextButton(
              child: Text(
                "Yes",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                  color: widget.isDarkMode
                      ? Colors.tealAccent
                      : const Color(0xff014689),
                ),
              ),
              onPressed: () {
                widget
                    .onCancel(); // Trigger the parent widget's cancel callback
                prefsService
                    .clearBookingData(); // Remove any saved booking info from local storage
                Navigator.of(
                  context,
                ).pop(); // Close the dialog after cancelling
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which booked trip index to use based on the selected box:
    // If selectedBox == 1, use KAP index; otherwise, use CLE index.
    final int? bookedTripIndex = widget.selectedBox == 1
        ? widget.bookedTripIndexKAP
        : widget.bookedTripIndexCLE;

    // Retrieve the booked departure time from the list of departure times
    // using the booked trip index (non-null asserted with !).
    final DateTime bookedTime = widget.getDepartureTimes()[bookedTripIndex!];

    // Determine the station name based on the selected box.
    final String station = widget.selectedBox == 1 ? 'KAP' : 'CLE';

    // Save booking data persistently so it can be restored later
    // (e.g., after app restart or navigation).
    prefsService.saveBookingData(
      widget.selectedBox,
      widget.bookedTripIndexKAP,
      widget.bookedTripIndexCLE,
      widget.busStop,
    );

    // If the current time has not yet been fetched or set, show a loading widget.
    if (timeNow == null) {
      if (kDebugMode) {
        print('time now = $timeNow'); // Debug log for troubleshooting
      }
      return LoadingScroll(isDarkMode: widget.isDarkMode);
    }

    // Main UI layout for the booking confirmation screen
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,

      /// CHANGED: Center children horizontally
      children: [
        Center(
          /// CHANGED: Wrap card in Center to align it horizontally
          child: _BookingDetailsCard(
            bookedTripIndex: bookedTripIndex,
            bookedTime: bookedTime,
            station: station,
            busStop: widget.busStop ?? '', // Fallback to empty string if null
            color: generateColor(
              bookedTime,
              bookedTripIndex,
            ), // Dynamic background color
            onCancel: showCancelDialog, // Show cancel confirmation dialog
          ),
        ),
        const SizedBox(height: 20),
        // Show evening service bus time only if current hour is after service start
        if (timeNow!.hour > startEveningService)
          EveningStartPoint.getBusTime(
            widget.selectedBox,
            context,
            widget.isDarkMode,
          ),
      ],
    );
  }
}

/// CHANGED: New stateless widget for booking details card.
class _BookingDetailsCard extends StatelessWidget {
  final int bookedTripIndex; // Index of the booked trip
  final DateTime bookedTime; // Departure time of the booked trip
  final String station; // Station name (KAP or CLE)
  final String busStop; // Bus stop name
  final Color? color; // Background color for the card
  final VoidCallback onCancel; // Callback for cancel button

  const _BookingDetailsCard({
    required this.bookedTripIndex,
    required this.bookedTime,
    required this.station,
    required this.busStop,
    required this.color,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0), // Outer padding around the card
      child: Container(
        color: color, // Apply dynamic background color
        child: Padding(
          padding: const EdgeInsets.all(5.0), // Inner padding inside the card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              SizedBox(height: 5), // Small top spacing
              Row(
                children: const [
                  SizedBox(width: 10), // Left spacing before icon
                  Icon(
                    Icons.event_available,
                    color: Colors.black,
                  ), // Calendar/check icon
                  SizedBox(width: 5), // Space between icon and text
                  Text(
                    'Booking Confirmation:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25), // Space before booking details
              // Display trip number (index + 1 for human-readable numbering)
              BookingConfirmationText(
                label: 'Trip Number',
                value: '${bookedTripIndex + 1}',
                size: 0.5,
                darkText: true,
              ),
              DrawLine(), // Divider line
              // Display departure time in HH:mm format
              BookingConfirmationText(
                label: 'Time',
                value:
                    '${bookedTime.hour.toString().padLeft(2, '0')}:${bookedTime.minute.toString().padLeft(2, '0')}',
                size: 0.5,
                darkText: true,
              ),
              DrawLine(),
              // Display station name
              BookingConfirmationText(
                label: 'Station',
                value: station,
                size: 0.5,
                darkText: true,
              ),
              DrawLine(),
              // Display bus stop name
              BookingConfirmationText(
                label: 'Bus Stop',
                value: busStop,
                size: 0.5,
                darkText: true,
              ),
              const SizedBox(height: 10),
              // Cancel button row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.blueGrey[900], // Button background color
                        foregroundColor: Colors.white, // Text (and icon) color
                      ),
                      onPressed: onCancel, // Trigger cancel dialog
                      child: const Text('Cancel'),
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
