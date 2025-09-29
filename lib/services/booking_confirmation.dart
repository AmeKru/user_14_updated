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
import 'package:user_14_updated/utils/text_sizing.dart';
import 'package:user_14_updated/utils/text_styles_booking_confirmation.dart';

///////////////////////////////////////////////////////////////
// This URL returns the current time for the Asia/Singapore timezone
// Moved API URL to a constant for easier maintenance
const String timeApiUrl =
    'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE';

///////////////////////////////////////////////////////////////
// Booking Confirmation

class BookingConfirmation extends StatefulWidget {
  // Index of the selected booking option (e.g., which trip card was tapped)
  final int selectedBox;

  // Index of the booked trip for KAP and CLE stops (nullable if not booked)
  final int? bookedTripIndexKAP;
  final int? bookedTripIndexCLE;

  // Function to retrieve the list of departure times
  final List<DateTime> Function() getDepartureTimes;

  // Callback to execute when booking is cancelled
  final VoidCallback onCancel;

  // Name of the bus stop (optional)
  final String? busStop;

  // Lists of departure times for KAP and CLE stops
  final List<DateTime> departureTimeKAP;
  final List<DateTime> departureTimeCLE;

  // Evening service identifier (likely used to determine schedule)
  final int eveningService;

  // Whether the app is currently in dark mode
  final bool isDarkMode;

  const BookingConfirmation({
    super.key,
    required this.selectedBox,
    this.bookedTripIndexKAP,
    this.bookedTripIndexCLE,
    required this.getDepartureTimes,
    required this.onCancel,
    this.busStop,
    required this.departureTimeKAP,
    required this.departureTimeCLE,
    required this.eveningService,
    required this.isDarkMode,
  });

  @override
  State<BookingConfirmation> createState() => _BookingConfirmationState();
}

class _BookingConfirmationState extends State<BookingConfirmation> {
  final Duration timeUpdateInterval = const Duration(seconds: 1);
  final Duration apiFetchInterval = const Duration(minutes: 3);

  int secondsElapsed = 0;
  Timer? _clockTimer;

  final SharedPreferenceService prefsService = SharedPreferenceService();

  // Added loading flag to track time fetch status
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // Save booking data here instead of inside build()
    prefsService.saveBookingData(
      widget.selectedBox,
      widget.bookedTripIndexKAP,
      widget.bookedTripIndexCLE,
      widget.busStop,
    );

    // Fetch the current time from the API first
    getTime().then((_) {
      // Mark loading complete once time is fetched
      setState(() {
        _loading = false;
      });

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
    _clockTimer?.cancel();
    super.dispose();
  }

  Color? generateColor(DateTime departureTime, int selectedTripNo) {
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

    final int departureSeconds =
        departureTime.hour * 3600 + departureTime.minute * 60;
    final int combinedSeconds = timeNow!.second + departureSeconds;
    final int roundedSeconds = (combinedSeconds ~/ 10) * 10;

    final DateTime roundedTime = DateTime(
      timeNow!.year,
      timeNow!.month,
      timeNow!.day,
      timeNow!.hour,
      timeNow!.minute,
      roundedSeconds,
    );

    final int seed = roundedTime.millisecondsSinceEpoch ~/ (1000 * 10);
    final Random random = Random(seed);
    final int syncedRandomNum = random.nextInt(10);

    return colors[syncedRandomNum];
  }

  ///////////////////////////////////////////////////////////////
  // Fetches the current time from the API and updates [timeNow].
  // This ensures the displayed time stays accurate even if the
  // device clock is off.

  Future<void> getTime() async {
    try {
      final uri = Uri.parse(timeApiUrl);

      // Added timeout to prevent indefinite loading
      final response = await get(uri).timeout(Duration(seconds: 5));

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

      // Fallback to device time if API fails
      setState(() {
        timeNow = DateTime.now();
      });
    }
  }

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
          backgroundColor: widget.isDarkMode
              ? Colors.blueGrey[900]
              : Colors.white,
          actionsAlignment: MainAxisAlignment.center,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    color: Colors.redAccent,
                    size: TextSizing.fontSizeHeading(context),
                  ), // Success icon
                  SizedBox(width: TextSizing.fontSizeMiniText(context)),
                  Text(
                    'Cancel Booking',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                      fontSize: TextSizing.fontSizeHeading(context),
                    ),
                  ),
                ],
              ),
            ],
          ),

          content: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TextSizing.fontSizeText(context),
              vertical: TextSizing.fontSizeMiniText(context),
            ),
            child: Text(
              "Are you sure you want to\ncancel this booking?",
              style: TextStyle(
                fontFamily: 'Roboto',
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: TextSizing.fontSizeText(context),
              ),
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
                  fontSize: TextSizing.fontSizeText(context),
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
                  fontSize: TextSizing.fontSizeText(context),
                  color: widget.isDarkMode
                      ? Colors.tealAccent
                      : const Color(0xff014689),
                ),
              ),
              onPressed: () {
                saveBusIndex(0);
                busIndex = 0;
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

  ///////////////////////////////////////////////////////////////
  // Booking Card

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

    // Use loading flag instead of relying on timeNow directly
    if (_loading || timeNow == null) {
      if (kDebugMode) {
        print('time now = $timeNow'); // Debug log for troubleshooting
      }
      return LoadingScroll(isDarkMode: widget.isDarkMode);
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
            color: generateColor(
              bookedTime,
              bookedTripIndex,
            ), // Dynamic background color
            onCancel: showCancelDialog, // Show cancel confirmation dialog
          ),
        ),
        SizedBox(height: TextSizing.fontSizeHeading(context)),
        // Show evening service bus time only if current hour is after service start
        if (timeNow!.hour >= startEveningService)
          Center(
            // Wrap bus time in Center to align it horizontally
            child: EveningStartPoint.getBusTime(
              widget.selectedBox,
              context,
              widget.isDarkMode,
            ),
          ),
      ],
    );
  }
}

///////////////////////////////////////////////////////////////
// Layout for Booking Details
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
      padding: EdgeInsets.all(
        TextSizing.fontSizeText(context),
      ), // Outer padding around the card
      child: Container(
        color: color, // Apply dynamic background color
        child: Padding(
          padding: EdgeInsets.all(
            TextSizing.fontSizeText(context) * 0.5,
          ), // Inner padding inside the card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              SizedBox(
                height: TextSizing.fontSizeText(context) * 0.5,
              ), // Small top spacing
              Row(
                children: [
                  SizedBox(
                    width: TextSizing.fontSizeText(context),
                  ), // Left spacing before icon
                  Icon(
                    Icons.event_available,
                    color: Colors.black,
                    size: TextSizing.fontSizeText(context) * 1.5,
                  ), // Calendar/check icon
                  SizedBox(
                    width: TextSizing.fontSizeText(context) * 0.5,
                  ), // Space between icon and text
                  Text(
                    'Booking Confirmation:',
                    style: TextStyle(
                      fontSize: TextSizing.fontSizeText(context),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: TextSizing.fontSizeText(context) * 1.5,
              ), // Space before booking details
              // Display trip number (index + 1 for human-readable numbering)
              BookingConfirmationText(
                label: 'Trip Number',
                value: '${bookedTripIndex + 1}',
                size: 1,
                darkText: true,
              ),
              DrawLine(), // Divider line
              // Display departure time in HH:mm format
              BookingConfirmationText(
                label: 'Time',
                value:
                    '${bookedTime.hour.toString().padLeft(2, '0')}:${bookedTime.minute.toString().padLeft(2, '0')}',
                size: 1,
                darkText: true,
              ),
              DrawLine(),
              // Display station name
              BookingConfirmationText(
                label: 'Station',
                value: station,
                size: 1,
                darkText: true,
              ),
              DrawLine(),
              // Display bus stop name
              BookingConfirmationText(
                label: 'Bus Stop',
                value: busStop,
                size: 1,
                darkText: true,
              ),
              SizedBox(height: TextSizing.fontSizeText(context)),
              // Cancel button row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: TextSizing.fontSizeText(context),
                      bottom: TextSizing.fontSizeText(context) * 1.5,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.blueGrey[900], // Button background color
                        foregroundColor: Colors.white, // Text (and icon) color
                      ),
                      onPressed: onCancel, // Trigger cancel dialog
                      child: Padding(
                        padding: EdgeInsets.all(
                          TextSizing.fontSizeText(context) * 0.33,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: TextSizing.fontSizeText(context),
                            fontFamily: 'Roboto'
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
