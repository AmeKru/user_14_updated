import 'dart:async'; // For using Future, async/await, and delayed actions

// Amplify packages for API and DataStore functionality
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
// Flutter UI framework
import 'package:flutter/material.dart';
// Local storage for persisting small bits of data
import 'package:shared_preferences/shared_preferences.dart';
// Project-specific imports
import 'package:user_14_updated/amplifyconfiguration.dart'; // Amplify config file
import 'package:user_14_updated/data/get_data.dart'; // Local bus data helper
import 'package:user_14_updated/data/global.dart'; // Global variables
import 'package:user_14_updated/models/model_provider.dart'; // Amplify model provider
import 'package:user_14_updated/services/booking_confirmation.dart'; // Booking confirmation UI
import 'package:user_14_updated/services/booking_service.dart'; // Booking servicing confirmation UI
import 'package:user_14_updated/services/shared_preference.dart'; // SharedPreferences wrapper
import 'package:user_14_updated/utils/styling_line_and_buttons.dart'; // Styling helpers
import 'package:user_14_updated/utils/text_sizing.dart'; // sizing, so it stays consistent
import 'package:user_14_updated/utils/text_styles_booking_confirmation.dart'; // Text style helpers
// For generating unique IDs
import 'package:uuid/uuid.dart';

//////////////////////////////////////////////////////////////
// AfternoonScreen widget
// Displays the afternoon booking interface, handles user selection,
// booking creation, and integration with Amplify backend.

class AfternoonScreen extends StatefulWidget {
  final Function(int)
  updateSelectedBox; // Callback to parent when selection changes
  final bool isDarkMode; // Theme mode flag
  static const int eveningService =
      15; // Static constant for evening service ID

  const AfternoonScreen({
    required this.updateSelectedBox,
    required this.isDarkMode,
    super.key,
  });

  @override
  State<AfternoonScreen> createState() => _AfternoonScreenState();
}

class _AfternoonScreenState extends State<AfternoonScreen> {
  // Currently selected MRT box index (0 = none)
  int selectedBox = selectedMRT;

  // Indices of booked trips for two MRT stations (KAP and CLE)
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;

  // Flag to prevent multiple confirmations
  bool confirmationPressed = false;

  // ID of the booking created in backend
  String? bookingID;

  // Name of the bus stop selected
  String selectedBusStop = '';

  // Local bus data helper
  final BusData _busData = BusData();

  // Service for reading/writing shared preferences
  final SharedPreferenceService prefsService = SharedPreferenceService();

  // Local constant for evening service (different from static const above)
  final int _eveningService = startEveningService;

  // Lists of DateTime objects for trip schedules
  List<DateTime> kapDT = [];
  List<DateTime> cleDT = [];

  // Future holding booking data loaded from preferences
  Future<Map<String, dynamic>?>? futureBookingData;

  // Controls whether booking service UI is shown
  bool _showBookingService = false;

  @override
  void initState() {
    super.initState();
    selectedMRT = 0; // Ensure global starts with no MRT selection

    _configureAmplify(); // Set up Amplify plugins and backend connection

    // Load any saved booking data from shared preferences
    futureBookingData = prefsService.getBookingData();

    // Hide booking service UI after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) setState(() => _showBookingService = false);
    });

    checkBooking();

    // Debug: print list of bus stops from BusData
    if (kDebugMode) {
      print('BusStop list: ${_busData.busStop}');
    }
  }

  void checkBooking() async {
    final data = await futureBookingData;
    if (data != null) {
      final selectedBox = data['selectedBox'] as int?;
      setState(() {
        confirmationPressed = selectedBox != 0;
      });
    }
  }

  //////////////////////////////////////////////////////////////
  // Updates the selected box index and notifies parent widget.
  // If the same box is tapped twice, it will be deselected.

  void updateSelectedBox(int box) {
    if (!confirmationPressed) {
      setState(() {
        // If the same box is tapped again, deselect it
        if (selectedBox == box) {
          selectedBox = 0;
          selectedMRT = 0; // reset global
        } else {
          selectedBox = box;
          selectedMRT = box; // update global
        }
      });
      // Notify parent widget of change
      widget.updateSelectedBox(selectedBox);
    }
  }

  //////////////////////////////////////////////////////////////
  // Loads booking data from shared preferences.
  // Returns a map with selected box, trip indices, and bus stop if found.

  Future<Map<String, dynamic>?> loadBookingData() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedBox = prefs.getInt('selectedBox');
    if (selectedBox != null) {
      return {
        'selectedBox': selectedBox,
        'bookedTripIndexKAP': prefs.getInt('bookedTripIndexKAP'),
        'bookedTripIndexCLE': prefs.getInt('bookedTripIndexCLE'),
        'busStop': prefs.getString('busStop'),
      };
    }
    return null; // No saved booking
  }

  //////////////////////////////////////////////////////////////
  // Configures Amplify with DataStore and API plugins.
  // Uses the generated amplifyconfiguration.dart file.

  Future<void> _configureAmplify() async {
    try {
      final provider = ModelProvider();
      Amplify.addPlugin(AmplifyDataStore(modelProvider: provider));
      Amplify.addPlugin(
        AmplifyAPI(options: APIPluginOptions(modelProvider: provider)),
      );
      await Amplify.configure(amplifyconfig);
      if (kDebugMode) {
        print('Amplify configured');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Amplify configuration error: $e');
      }
    }
  }

  //////////////////////////////////////////////////////////////
  // Creates a booking record in the backend via Amplify API.
  // [mrtStation] - MRT station name (e.g., "KAP")
  // [tripNo] - Trip number
  // [busStop] - Selected bus stop name

  Future<void> createBooking(
    String mrtStation,
    int tripNo,
    String busStop,
  ) async {
    try {
      // Create a new booking model instance with unique ID
      final model = BOOKINGDETAILS5(
        id: const Uuid().v4(),
        MRTStation: mrtStation,
        TripNo: tripNo,
        BusStop: busStop,
      );

      // Send mutation request to Amplify API
      final response = await Amplify.API
          .mutate(request: ModelMutations.create(model))
          .response;

      // Check if booking was created successfully
      final createdBooking = response.data;
      if (createdBooking == null) {
        safePrint('Booking creation errors: ${response.errors}');
        return;
      }

      // Save booking ID to state
      setState(() => bookingID = createdBooking.id);
      safePrint('Booking created with ID: $bookingID');
    } on ApiException catch (e) {
      safePrint('Booking creation failed: $e');
    }

    // Update passenger count for the trip
    _updateCount(mrtStation == 'KAP', tripNo, busStop);
  }

  //////////////////////////////////////////////////////////////
  // Counts the number of bookings for a given MRT station and trip number.
  // Returns the count as an integer, or null if an error occurs.

  Future<int?> countBooking(String mrt, int tripNo) async {
    try {
      // Query Amplify API for all bookings matching MRT station and trip number
      final response = await Amplify.API
          .query(
            request: ModelQueries.list(
              BOOKINGDETAILS5.classType,
              where: BOOKINGDETAILS5.MRTSTATION
                  .eq(mrt)
                  .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo)),
            ),
          )
          .response;

      // Count the number of matching bookings
      final count = response.data?.items.length ?? 0;
      if (kDebugMode) {
        print('Booking count for $mrt trip $tripNo: $count');
      }
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('Error counting bookings: $e');
      }
      return null;
    }
  }

  //////////////////////////////////////////////////////////////
  // Finds a specific booking by MRT station, trip number, and bus stop.
  // Returns the first matching booking, or null if none found.

  Future<BOOKINGDETAILS5?> _findBooking(
    String mrt,
    int tripNo,
    String busStop,
  ) async {
    final response = await Amplify.API
        .query(
          request: ModelQueries.list(
            BOOKINGDETAILS5.classType,
            where: BOOKINGDETAILS5.MRTSTATION
                .eq(mrt)
                .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo))
                .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
          ),
        )
        .response;

    // Get the first booking in the result set, if any
    final booking = response.data?.items.firstOrNull;
    if (kDebugMode) {
      print(booking != null ? 'Booking found: $booking' : 'No booking found');
    }
    return booking;
  }

  //////////////////////////////////////////////////////////////
  // Deletes a booking based on MRT station, trip number, and bus stop.
  // After deletion, updates the passenger count for that trip.

  Future<void> deleteBookingByTrip(
    String mrt,
    int tripNo,
    String busStop,
  ) async {
    final booking = await _findBooking(mrt, tripNo, busStop);
    if (booking != null) {
      // Delete the booking from the backend
      await Amplify.API
          .mutate(request: ModelMutations.delete(booking))
          .response;

      // Update passenger count for the trip after deletion
      _updateCount(mrt == 'KAP', booking.TripNo, booking.BusStop);
    } else {
      if (kDebugMode) {
        print('No booking to delete for $mrt trip $tripNo');
      }
    }
  }

  //////////////////////////////////////////////////////////////
  // Reads a booking from the backend using the stored bookingID.
  // Returns the booking if found, otherwise null.

  Future<BOOKINGDETAILS5?> _readBookingByID() async {
    // If no booking ID is stored, nothing to look up
    if (bookingID == null) return null;

    // Query Amplify API for a booking with the matching ID
    final response = await Amplify.API
        .query(
          request: ModelQueries.list(
            BOOKINGDETAILS5.classType,
            where: BOOKINGDETAILS5.ID.eq(bookingID!),
          ),
        )
        .response;

    // Return the first booking found (or null if none)
    return response.data?.items.firstOrNull;
  }

  //////////////////////////////////////////////////////////////
  // Deletes a booking using the stored bookingID.
  // After deletion, updates the passenger count for that trip.

  Future<void> deleteBookingByID() async {
    final booking = await _readBookingByID();
    if (booking != null) {
      // Delete the booking from the backend
      await Amplify.API
          .mutate(request: ModelMutations.delete(booking))
          .response;

      // Update passenger count for the trip
      _updateCount(
        booking.MRTStation == 'KAP',
        booking.TripNo,
        booking.BusStop,
      );
    } else {
      if (kDebugMode) {
        print('No booking found with ID: $bookingID');
      }
    }
  }

  //////////////////////////////////////////////////////////////
  // Updates the passenger count for a specific trip and bus stop.
  // If a count record exists, it is deleted and replaced with the new count.
  // If no bookings remain, no new record is created.

  Future<void> _updateCount(bool isKAP, int tripNo, String busStop) async {
    // Determine which model type to use based on MRT station
    final ModelType<Model> classType = isKAP
        ? KAPAfternoon.classType
        : CLEAfternoon.classType;

    // Build the query filter for the specific trip and bus stop
    final whereClause = isKAP
        ? KAPAfternoon.TRIPNO.eq(tripNo).and(KAPAfternoon.BUSSTOP.eq(busStop))
        : CLEAfternoon.TRIPNO.eq(tripNo).and(CLEAfternoon.BUSSTOP.eq(busStop));

    // Step 1: Delete existing count record if present
    final existing = await Amplify.API
        .query(request: ModelQueries.list(classType, where: whereClause))
        .response;
    final existingRow = existing.data?.items.firstOrNull;
    if (existingRow != null) {
      await Amplify.API
          .mutate(request: ModelMutations.delete(existingRow))
          .response;
    }

    // Step 2: Count current bookings for this trip
    final count = await countBooking(isKAP ? 'KAP' : 'CLE', tripNo) ?? 0;

    // Step 3: If there are bookings, create a new count record
    if (count > 0) {
      final model = isKAP
          ? KAPAfternoon(BusStop: busStop, TripNo: tripNo, Count: count)
          : CLEAfternoon(BusStop: busStop, TripNo: tripNo, Count: count);

      await Amplify.API.mutate(request: ModelMutations.create(model)).response;
    }
  }

  // --- UI Helpers ---
  //////////////////////////////////////////////////////////////
  // Shows a bottom sheet allowing the user to select a bus stop.
  // Updates `selectedBusStop` and `busIndex` when a stop is chosen.

  void showBusStopSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // so we can round corners
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.65, // finite height for the sheet
          child: Material(
            color: widget.isDarkMode ? Colors.blueGrey[900] : Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(TextSizing.fontSizeText(context)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(
                  TextSizing.fontSizeText(context) * 0.35,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max, // fill vertical space
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Choose bus stop:',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: TextSizing.fontSizeHeading(context),
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: TextSizing.fontSizeMiniText(context)),
                    // Give the list bounded height via Expanded
                    Expanded(
                      child: ListView.builder(
                        // no shrinkWrap, no NeverScrollablePhysics
                        itemCount: _busData.busStop.length - 2,
                        itemBuilder: (_, index) {
                          final stopName = _busData.busStop[index + 2];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: TextSizing.fontSizeText(context),
                              vertical: TextSizing.fontSizeText(context) * 0.2,
                            ),
                            child: Material(
                              color: widget.isDarkMode
                                  ? Colors.blueGrey[800]
                                  : const Color(0xff014689),
                              borderRadius: BorderRadius.circular(
                                TextSizing.fontSizeText(context) * 0.25,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  TextSizing.fontSizeText(context) * 0.25,
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedBusStop = stopName;
                                    busIndex = index + 2;
                                  });
                                  Navigator.pop(context);
                                },
                                child: ListTile(
                                  title: Text(
                                    stopName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w900,
                                      fontSize: TextSizing.fontSizeText(
                                        context,
                                      ),
                                    ),
                                  ),
                                  textColor: widget.isDarkMode
                                      ? Colors.cyanAccent
                                      : Colors.white,
                                  // No trailing/leading to keep it simple
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////
  // Updates the booking status for KAP station trips.
  // Resets confirmation state and sets or clears the booked trip index.

  void updateBookingStatusKAP(int index, bool isSelected) {
    setState(() {
      confirmationPressed = false;
      bookedTripIndexKAP = isSelected
          ? index
          : (bookedTripIndexKAP == index ? null : bookedTripIndexKAP);
    });
  }

  //////////////////////////////////////////////////////////////
  // Updates the booking status for CLE station trips.
  // Resets confirmation state and sets or clears the booked trip index.

  void updateBookingStatusCLE(int index, bool isSelected) {
    setState(() {
      confirmationPressed = false;
      bookedTripIndexCLE = isSelected
          ? index
          : (bookedTripIndexCLE == index ? null : bookedTripIndexCLE);
    });
  }
  //////////////////////////////////////////////////////////////
  // Returns the list of departure times based on the currently selected MRT station.
  // If `selectedBox` is 1 → return KAP departure times, otherwise return CLE departure times.

  List<DateTime> getDepartureTimes() =>
      selectedBox == 1 ? _busData.departureTimeKAP : _busData.departureTimeCLE;

  //////////////////////////////////////////////////////////////
  // Formats a DateTime into a string in HH:mm format with leading zeros.
  // Example: 8:5 → "08:05"

  String formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  //////////////////////////////////////////////////////////////
  // Shows a booking confirmation dialog with trip details.
  // Displays trip number, time, station, and bus stop.

  void showBookingConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          backgroundColor: widget.isDarkMode
              ? Colors.blueGrey[900]
              : Colors.white,

          // Dialog title section
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: TextSizing.fontSizeHeading(context),
                  ), // Success icon
                  SizedBox(width: TextSizing.fontSizeMiniText(context)),
                  Text(
                    'Booking Confirmed!',
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

          // Dialog content section
          content: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TextSizing.fontSizeText(context),
              vertical: TextSizing.fontSizeMiniText(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thank you for booking with us.\nYour booking has been confirmed.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: TextSizing.fontSizeText(context),
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: TextSizing.fontSizeHeading(context)),

                SingleChildScrollView(
                  child: ListBody(
                    children: [
                      // Trip number display
                      BookingConfirmationText(
                        label: 'Trip:',
                        value:
                            '${selectedBox == 1 ? bookedTripIndexKAP! + 1 : bookedTripIndexCLE! + 1}',
                        size: 0.60,
                        darkText: widget.isDarkMode ? false : true,
                      ),
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
                      // Departure time display
                      BookingConfirmationText(
                        label: 'Time:',
                        value: formatTime(
                          getDepartureTimes()[selectedBox == 1
                              ? bookedTripIndexKAP!
                              : bookedTripIndexCLE!],
                        ),
                        size: 0.60,
                        darkText: widget.isDarkMode ? false : true,
                      ),
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
                      // Station name display
                      BookingConfirmationText(
                        label: 'Station:',
                        value: selectedBox == 1 ? 'KAP' : 'CLE',
                        size: 0.60,
                        darkText: widget.isDarkMode ? false : true,
                      ),
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
                      // Bus stop display
                      BookingConfirmationText(
                        label: 'Bus Stop:',
                        value: selectedBusStop,
                        size: 0.60,
                        darkText: widget.isDarkMode ? false : true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dialog action buttons
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close dialog

              child: Text(
                'Close',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: TextSizing.fontSizeText(context),
                  fontFamily: 'Roboto',
                  color: widget.isDarkMode
                      ? Colors.tealAccent
                      : const Color(0xff014689),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////
  // Builds the MRT station selection row with two selectable boxes (KAP and CLE).
  // Each box is wrapped in a GestureDetector to handle taps.

  Widget _mrtSelectionRow() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: TextSizing.fontSizeMiniText(context),
      ),
      child: Row(
        children: [
          // KAP selection box
          Expanded(
            child: GestureDetector(
              onTap: () => updateSelectedBox(1), // Select KAP
              child: BoxMRT(
                box: selectedBox,
                mrt: 'KAP',
                isDarkMode: widget.isDarkMode,
              ),
            ),
          ),
          SizedBox(
            width: TextSizing.fontSizeMiniText(context),
          ), // Space between boxes
          // CLE selection box
          Expanded(
            child: GestureDetector(
              onTap: () => updateSelectedBox(2), // Select CLE
              child: BoxMRT(
                box: selectedBox,
                mrt: 'CLE',
                isDarkMode: widget.isDarkMode,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the selected station name based on the selectedBox value
    // 1 → KAP, anything else → CLE
    final String selectedStation = selectedBox == 1 ? 'KAP' : 'CLE';

    return FutureBuilder<Map<String, dynamic>?>(
      future: futureBookingData, // Future that loads saved booking data
      builder: (context, snapshot) {
        // 1. While waiting for the future to complete → show loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          SizedBox.expand(
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // 2. If there was an error loading the data → show error message
        if (snapshot.hasError) {
          return const Expanded(
            child: Scaffold(body: Center(child: Text('Error loading data'))),
          );
        }

        // 3. If booking data exists → restore state and show booking UI
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          selectedBox =
              data['selectedBox']; // Restore selected MRT from saved data

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: TextSizing.fontSizeMiniText(context)),

              // Title: "Select MRT"
              Center(
                child: Text(
                  'Select MRT',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                    fontSize: TextSizing.fontSizeText(context),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),

              SizedBox(height: TextSizing.fontSizeMiniText(context)),

              // MRT selection row (KAP / CLE)
              _mrtSelectionRow(),

              SizedBox(height: TextSizing.fontSizeText(context)),

              // If _showBookingService is true → show booking selection UI
              // Else → show booking confirmation UI
              _showBookingService
                  ? BookingService(
                      departureTimes: getDepartureTimes(),
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: _busData.departureTimeKAP,
                      departureTimeCLE: _busData.departureTimeCLE,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      updateBookingStatusKAP: updateBookingStatusKAP,
                      updateBookingStatusCLE: updateBookingStatusCLE,
                      confirmationPressed: true,
                      countBooking: countBooking,
                      isDarkMode: widget.isDarkMode,
                      showBusStopSelectionBottomSheet:
                          showBusStopSelectionBottomSheet,
                      selectedBusStop: selectedBusStop,
                      onPressedConfirm: () {
                        saveBusIndex(busIndex);
                        // When confirm is pressed → create booking and show confirmation dialog
                        setState(() {
                          confirmationPressed = true;
                          createBooking(
                            selectedStation,
                            selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1,
                            selectedBusStop,
                          );
                        });
                        showBookingConfirmationDialog(context);
                      },
                    )
                  : BookingConfirmation(
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: data['KAPDepartureTime'] ?? [],
                      departureTimeCLE: data['CLEDepartureTime'] ?? [],
                      bookedTripIndexKAP: data['bookedTripIndexKAP'],
                      bookedTripIndexCLE: data['bookedTripIndexCLE'],
                      getDepartureTimes: getDepartureTimes,
                      busStop: data['busStop'],
                      isDarkMode: widget.isDarkMode,
                      onCancel: () {
                        // Cancel booking → delete from backend and clear saved data
                        setState(() {
                          saveBusIndex(0);
                          confirmationPressed = false;
                          if (data['bookedTripIndexCLE'] != null ||
                              data['bookedTripIndexKAP'] != null) {
                            final tripNo = selectedBox == 1
                                ? data['bookedTripIndexKAP'] + 1
                                : data['bookedTripIndexCLE'] + 1;
                            if (data['busStop'] != null) {
                              deleteBookingByTrip(
                                selectedStation,
                                tripNo,
                                data['busStop'],
                              );
                            }
                          }
                        });
                        // Clear saved booking data and reload
                        prefsService.clearBookingData();
                        futureBookingData = prefsService.getBookingData();
                      },
                    ),
            ],
          );
        }
        // No booking data yet → show initial selection UI
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: TextSizing.fontSizeMiniText(context)),
            // Title: "Select MRT"
            Center(
              child: Text(
                'Select MRT',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontSize: TextSizing.fontSizeText(context),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),

            SizedBox(height: TextSizing.fontSizeMiniText(context)),

            // MRT station selection row (KAP / CLE)
            _mrtSelectionRow(),

            SizedBox(height: TextSizing.fontSizeText(context)),

            // Only show booking UI if a station has been selected
            if (selectedBox != 0)
              // If booking has already been confirmed → show BookingConfirmation widget
              confirmationPressed
                  ? BookingConfirmation(
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: kapDT, // departure times for KAP
                      departureTimeCLE: cleDT, // departure times for CLE
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      getDepartureTimes: getDepartureTimes,
                      busStop: selectedBusStop,
                      isDarkMode: widget.isDarkMode,
                      onCancel: () {
                        saveBusIndex(0);
                        // Cancel booking → reset confirmation state and delete booking if exists
                        setState(() {
                          confirmationPressed = false;
                          if (bookedTripIndexCLE != null ||
                              bookedTripIndexKAP != null) {
                            final tripNo = selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1;
                            deleteBookingByTrip(
                              selectedStation,
                              tripNo,
                              selectedBusStop,
                            );
                          }
                        });
                        // Clear saved booking data and reload
                        prefsService.clearBookingData();
                        futureBookingData = prefsService.getBookingData();
                      },
                    )
                  // If booking not yet confirmed → show BookingService widget
                  : BookingService(
                      departureTimes: getDepartureTimes(),
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: _busData.departureTimeKAP,
                      departureTimeCLE: _busData.departureTimeCLE,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      updateBookingStatusKAP: updateBookingStatusKAP,
                      updateBookingStatusCLE: updateBookingStatusCLE,
                      confirmationPressed: confirmationPressed,
                      countBooking: countBooking,
                      isDarkMode: widget.isDarkMode,
                      showBusStopSelectionBottomSheet:
                          showBusStopSelectionBottomSheet,
                      selectedBusStop: selectedBusStop,
                      onPressedConfirm: () {
                        // Confirm booking → create booking in backend and show confirmation dialog
                        saveBusIndex(busIndex);
                        setState(() {
                          confirmationPressed = true;
                          createBooking(
                            selectedStation,
                            selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1,
                            selectedBusStop,
                          );
                        });
                        showBookingConfirmationDialog(context);
                      },
                    ),
          ],
        );
      },
    );
  }
}
