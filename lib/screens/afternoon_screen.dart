import 'dart:async'; // For using Future, async/await, and delayed actions
import 'dart:convert';
import 'dart:math'; //

// Amplify packages for API and DataStore functionality
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
// Flutter UI framework
import 'package:flutter/material.dart' hide TimeOfDay;
// For generating unique IDs
import 'package:uuid/uuid.dart';

import '../data/get_data.dart'; // Local bus data helper
import '../data/global.dart'; // Global variables
import '../models/ModelProvider.dart'; // Amplify model provider
import '../services/booking_confirmation.dart'; // Booking confirmation UI
import '../services/booking_service.dart'; // Booking servicing confirmation UI
import '../services/shared_preference.dart'; // SharedPreferences wrapper
import '../utils/booking_data_consistent_format.dart'; // to have a singular format for booking, no matter if it is loaded from save, or from server
import '../utils/get_time.dart';
import '../utils/loading.dart'; // For loading
import '../utils/styling_line_and_buttons.dart'; // Styling helpers
import '../utils/text_sizing.dart'; // sizing, so it stays consistent
import '../utils/text_styles_booking_confirmation.dart'; // Text style helpers

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Afternoon Screen---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// enum to check what BookingStatus the booking has

enum BookingStatus {
  unknown,
  noBooking,
  validBooking,
  invalidBooking,
  oldBooking,
}

////////////////////////////////////////////////////////////////////////////////
// AfternoonScreen class
// displays the afternoon booking interface, handles user selection,
// booking creation, and integration with Amplify backend

class AfternoonScreen extends StatefulWidget {
  final Function(int)
  updateSelectedBox; // Callback to parent when selection changes
  const AfternoonScreen({required this.updateSelectedBox, super.key});

  @override
  State<AfternoonScreen> createState() => _AfternoonScreenState();
}

class _AfternoonScreenState extends State<AfternoonScreen>
    with WidgetsBindingObserver {
  // Create a GlobalKey typed to the child’s State
  final GlobalKey<BookingServiceState> _bookingKey =
      GlobalKey<BookingServiceState>();

  // Flag to prevent multiple confirmations
  bool? confirmationPressed =
      false; // null as state when booking is in process of being deleted

  // Currently selected MRT box index (0 = none)
  int selectedBox = 0;

  // Indices of booked trips for two MRT stations (KAP and CLE)
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;

  // ID of the booking created in backend
  String? bookingID;

  // Name of the bus stop selected
  String selectedBusStop = '';

  // Booked departure time
  DateTime? bookedDepartureTime;

  // Local bus data helper
  final BusData _busData = BusData();

  // add listener token
  VoidCallback? _busDataListener;

  // Service for reading/writing shared preferences
  final SharedPreferenceService prefsService = SharedPreferenceService();

  // Future holding booking data either from server if accessible or just loaded from preferences
  late Future<Map<String, dynamic>?> futureBookingData;

  // Guard to prevent repeated/overlapping local-cleanup runs
  bool _isClearingBooking = false;

  // One-shot guard so snapshot restoration runs only once
  bool _didRestoreSnapshot = false;

  // Booking status (moved from top-level into this state)
  BookingStatus _bookingStatus = BookingStatus.unknown;

  // guard to prevent multiple refreshes at once
  bool _isRefreshing = false;

  // to prevent loading UI before checking everything else
  bool loadingInitialData = false;

  // to prevent User from switching between boxes and UI being too slow to catch up
  bool updatingSelectedBox = false;

  // used to check for AppLifeCycle
  AppLifecycleState? _previousAppLifecycleState;
  DateTime? _lastBackgroundAt;
  final Duration _resumeCooldown = const Duration(seconds: 2);
  final Duration _inactivityStopDelay = const Duration(milliseconds: 900);

  // Timers for AppLifeCycle
  Timer? _inactivityStopTimer;
  Timer? _lifecycleResetTimer;

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  //////////////////////////////////////////////////////////////////////////////
  // Init function (called when first built)
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (kDebugMode) {
      print('afternoon screen initState');
    }
    _isRefreshing = false;
    loadingInitialData = true;
    selectedBox = selectedMRT; // sync with global if needed

    // Initialize the future once and cache it
    confirmationPressed = false;
    futureBookingData = prefsService.getBookingData();

    // Defer running the restore check until after the first frame so setState
    // inside the loader will not run during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // don't await here; we spawn the async task safely
      _loadAndCheckIfSavedBookingValid();
    });

    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
    }

    // Make the listener a synchronous VoidCallback that spawns an async task
    _busDataListener = () {
      if (kDebugMode) print('BusDataListener called, _busData was refreshed');
      if (confirmationPressed != true && mounted) {
        if (kDebugMode) {
          print(
            'confirmation has not been pressed, now calling updateSelectedBox to refresh',
          );
        }
        updateSelectedBox(0, false); // unified refresh
      } else {
        if (kDebugMode) {
          print('confirmation had been pressed, now calling _refreshingTrips');
        }
        _refreshTrips();
      }
    };
    _busData.addListener(_busDataListener!);
    loadInitialData();
    if (kDebugMode) {
      print("TimeNow ready: $timeNow");
    }
    _didRestoreSnapshot = false;
  }

  //////////////////////////////////////////////////////////////////////////////
  // function called at start (after initState or similar)
  // to determine sizing variables

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  //////////////////////////////////////////////////////////////////////////////
  // dispose function (called when build is destroyed)

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
      _busDataListener = null;
    }

    // cancel all timers when disposed
    _inactivityStopTimer?.cancel();
    _inactivityStopTimer = null;
    _lifecycleResetTimer?.cancel();
    _lifecycleResetTimer = null;

    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  // Load initial data

  Future<void> loadInitialData() async {
    await _waitForTimeAndCheckBooking();
    if (mounted) {
      setState(() {
        loadingInitialData = false;
      });
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Unified refresh function (used by listener AND manual button)

  Future<void> _refreshTrips() async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;

    if (kDebugMode) print('refreshing Trips');

    try {
      final previousStatus = _bookingStatus;
      _bookingStatus = await _loadAndCheckIfSavedBookingValid();

      if (_bookingStatus == BookingStatus.invalidBooking) {
        if (!_isClearingBooking) {
          _isClearingBooking = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _deleteLocalBookingAndNotify(
              message: 'Your previously selected trip was removed',
            );
            if (kDebugMode) print('deleted invalid booking and informed user');
            _isClearingBooking = false;
            confirmationPressed = false;
          });
        }
      } else {
        if (_bookingStatus == BookingStatus.oldBooking) {
          if (!_isClearingBooking) {
            _isClearingBooking = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _deleteLocalBookingAndNotify(message: '');
              if (kDebugMode) print('deleted old booking');
              _isClearingBooking = false;
              confirmationPressed = false;
            });
          }
        } else {
          if (previousStatus == _bookingStatus && mounted) {
            if (kDebugMode) print('no changes in booking Status');
            setState(() {});
          }
          if (previousStatus != _bookingStatus && mounted) {
            if (kDebugMode) print('Booking status changed to $_bookingStatus');
            setState(() {});
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) print('Error refreshing trips: $e\n$st');
    } finally {
      _isRefreshing = false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- App Lifecycle ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // functions to check if app is used in foreground or open in background
  // (or is reopened from the background)

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the state is just a transient "inactive", ignore it entirely here.
    // Instead rely on hidden/paused as the true "background" indicators.
    switch (state) {
      case AppLifecycleState.hidden:
        // The app became not visible; schedule a delayed stop so we tolerate quick returns.
        if (kDebugMode) {
          print('Lifecycle hidden');
        }
        _scheduleInactivityStop();
        // record the transition for later comparison
        _previousAppLifecycleState = state;
        break;

      case AppLifecycleState.paused:
        // Paused on many platforms is the real background; stop immediately (or you can delay).
        if (kDebugMode) {
          print('Lifecycle paused');
        }
        _cancelInactivityStopTimer();
        _lastBackgroundAt = DateTime.now();
        _previousAppLifecycleState = state;
        // clear resume cooldown guard so next resume will act
        _lifecycleResetTimer?.cancel();
        _lifecycleResetTimer = null;
        break;

      case AppLifecycleState.inactive:
        // Intentionally ignore inactive as a background indicator.
        // Only schedule a short delayed stop if you still want to be conservative.
        // Do not update _previousAppLifecycleState to inactive so resume logic can know
        // whether the app was truly backgrounded earlier.
        break;

      case AppLifecycleState.resumed:
        // We only treat this as a "foreground after background" if the previous
        // stored state was hidden or paused (the two markers we consider background).
        if (_previousAppLifecycleState == AppLifecycleState.hidden ||
            _previousAppLifecycleState == AppLifecycleState.paused) {
          // Debounce repeated resumed events
          final now = DateTime.now();
          if (_lastBackgroundAt != null &&
              now.difference(_lastBackgroundAt!) < _resumeCooldown) {
            if (kDebugMode) {
              print(
                'Resumed soon after background; applying cooldown and ignoring',
              );
            }
            // Reset previous state anyway to avoid treating next resume the same way
            _previousAppLifecycleState = state;
            return;
          }

          if (kDebugMode) {
            print('Resumed after real background; refreshing');
          }
          try {
            if (confirmationPressed != true && mounted) {
              if (kDebugMode) {
                print(
                  'confirmation has not been pressed, now calling updateSelectedBox to refresh',
                );
              }
              updateSelectedBox(0, true); // unified refresh
            } else {
              if (kDebugMode) {
                print(
                  'confirmation had been pressed, now calling _refreshingTrips',
                );
              }
              _refreshTrips();
            }
          } catch (e, st) {
            if (kDebugMode) {
              print("Error on resume: $e\n$st");
            }
          }

          // Force immediate data refresh
          try {
            _busData.loadData();
          } catch (e, st) {
            if (kDebugMode) print("Error loading bus data on resume: $e\n$st");
          }

          if (mounted) setState(() {});

          // Reset resume guard after cooldown so future resumes can be handled again
          _lifecycleResetTimer?.cancel();
          _lifecycleResetTimer = Timer(_resumeCooldown, () {
            _lastBackgroundAt = null;
            _lifecycleResetTimer = null;
            if (kDebugMode) {
              print('Resume cooldown expired, resume guard cleared');
            }
          });
        }
        // update previous state to resumed for future comparisons
        _previousAppLifecycleState = state;
        break;

      case AppLifecycleState.detached:
        if (kDebugMode) {
          print('Lifecycle detached: clearing guards');
        }
        _cancelInactivityStopTimer();
        _previousAppLifecycleState = state;
        _lastBackgroundAt = null;
        _lifecycleResetTimer?.cancel();
        _lifecycleResetTimer = null;
        break;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // helpers for didChangeAppLifecycleState

  void _scheduleInactivityStop() {
    if (_inactivityStopTimer?.isActive == true) {
      if (kDebugMode) print('Inactivity stop already scheduled; leaving it.');
      return;
    }

    _inactivityStopTimer = Timer(_inactivityStopDelay, () {
      _inactivityStopTimer = null;
      if (kDebugMode) print('Inactivity delay expired');
      _lastBackgroundAt = DateTime.now();
      // record that we were backgrounded via hidden path
      _previousAppLifecycleState = AppLifecycleState.hidden;
    });

    if (kDebugMode) {
      print(
        'Scheduled inactivity stop in ${_inactivityStopDelay.inMilliseconds}ms',
      );
    }
  }

  void _cancelInactivityStopTimer() {
    if (_inactivityStopTimer?.isActive == true) {
      _inactivityStopTimer?.cancel();
      _inactivityStopTimer = null;
      if (kDebugMode) print('Cancelled scheduled inactivity stop');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Creating Booking ---
  ///  /////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Creates a booking record in the backend via Amplify API.
  // [mrtStation] - MRT station name (e.g., "KAP")
  // [tripNo] - Trip number
  // [busStop] - Selected bus stop name

  Future<bool?> createBooking(
    String mrtStation,
    int tripNo,
    String busStop,
  ) async {
    // Checks if booking full
    int? checkIfTripFull = await fetchPassengerCountTrip(mrtStation, tripNo);
    if (checkIfTripFull == busMaxCapacity) {
      if (kDebugMode) {
        print(
          'Create Booking failed as Bus already full - checkIfTripFull: $checkIfTripFull BusMaxCapacity: $busMaxCapacity',
        );
      }
      return false;
    }
    if (checkIfTripFull == null) {
      if (kDebugMode) {
        print('Create Booking failed as checkIfTripFull == null');
      }
      return null;
    }

    // Checks if booking in past
    final List<DateTime> listCheck = getDepartureTimes();
    final int? idxCheck = selectedBox == 1
        ? bookedTripIndexKAP
        : bookedTripIndexCLE;

    // If index is invalid, mark departure as null
    final DateTime? departureCheck =
        (idxCheck == null || idxCheck < 0 || idxCheck >= listCheck.length)
        ? null
        : listCheck[idxCheck];

    final TimeService timeService = TimeService();
    await timeService.getTime();

    DateTime now = timeNow ?? DateTime.now();

    if (departureCheck == null) {
      if (kDebugMode) {
        print('Create Booking failed as departureCheck == null');
      }
      return false;
    }
    if (departureCheck.hour < now.hour ||
        departureCheck.hour == now.hour && departureCheck.minute < now.minute) {
      if (kDebugMode) {
        print('Create Booking failed as departure is in the past');
      }
      return false;
    }

    // Only if ok, will continue to create a booking
    try {
      final model = BookingDetails(
        id: const Uuid().v4(),
        MRTStation: mrtStation,
        TripNo: tripNo,
        BusStop: busStop,
      );

      final response = await Amplify.API
          .mutate(
            request: ModelMutations.create(
              model,
              authorizationMode: APIAuthorizationType.iam,
            ),
          )
          .response;

      final createdBooking = response.data;
      if (createdBooking == null) {
        safePrint('Booking creation errors: ${response.errors}');
        return null;
      }

      if (!mounted) return null;

      // Keep a local copy of values we will persist to avoid racing with UI changes
      final String createdId = createdBooking.id;
      final List<DateTime> list = getDepartureTimes();
      final int? idx = selectedBox == 1
          ? bookedTripIndexKAP
          : bookedTripIndexCLE;

      // If index is invalid, mark departure as null
      final DateTime? departure = (idx == null || idx < 0 || idx >= list.length)
          ? null
          : list[idx];

      // Normalize into BookingData
      final booking = BookingData(
        id: createdId,
        station: mrtStation,
        tripIndex: idx ?? -1,
        busStop: selectedBusStop,
        busIndex: busIndex.value,
        departure: departure, // nullable departure; no DateTime.now fallback
      );

      // Save locally (await so persistence completes before UI changes)
      try {
        await _saveBookingLocally(
          booking,
          selectedBoxValue: selectedBox, // 1 or 2
          bookedTripIndexKAP: selectedBox == 1 ? idx : null,
          bookedTripIndexCLE: selectedBox == 2 ? idx : null,
        );
      } catch (e, st) {
        if (kDebugMode) print('Persist booking locally failed: $e\n$st');
        // If save fails, avoid flipping UI; inform user and exit
        if (!mounted) return null;
        _showAsyncSnackBar('Failed to persist booking locally.');
        return null;
      }

      // Determine new booking status synchronously
      final BookingStatus newStatus = departure != null
          ? BookingStatus.validBooking
          : BookingStatus.invalidBooking;

      // Prepare the new future but do not assign inside setState
      final refreshedFuture = prefsService.getBookingData();
      if (!mounted) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          // Atomically update parent visible state (assign all fields BookingConfirmation expects)
          bookingID = createdId;
          // ensure these match what BookingConfirmation uses
          if (selectedBox == 1) {
            bookedTripIndexKAP = idx;
          } else {
            bookedTripIndexCLE = idx;
          }
          bookedDepartureTime = departure;
          selectedBusStop = booking.busStop;
          // other fields used by BookingConfirmation:
          _bookingStatus = newStatus;
          futureBookingData = refreshedFuture;
        });

        if (kDebugMode) {
          safePrint(
            'Post-save state: '
            'bookingID=$bookingID, '
            'bookedTripIndexKAP=$bookedTripIndexKAP, '
            'bookedTripIndexCLE=$bookedTripIndexCLE, '
            'bookedDepartureTime=${bookedDepartureTime?.toIso8601String() ?? "null"}, '
            'selectedBusStop=$selectedBusStop, '
            '_bookingStatus=$_bookingStatus, '
            'confirmationPressed=$confirmationPressed, '
            'futureBookingDataSet=$futureBookingData',
          );
        }
      });

      safePrint('Booking created with ID: $bookingID');

      // Only update passenger count after success
      _updateCount(
        isKAP: selectedBox == 1,
        busStop: selectedBusStop,
        increment: true,
        tripNo: tripNo,
      );
    } on ApiException catch (e) {
      safePrint('Booking creation failed: $e');
    }
    return true;
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Checks if Booking is old ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // To check if Time has been set and then goes to check if booking is still valid

  Future<void> _waitForTimeAndCheckBooking() async {
    // Wait for timeNow to be set
    const maxWait = Duration(seconds: 3);
    final start = DateTime.now();
    while (timeNow == null && DateTime.now().difference(start) < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    timeNow ??= DateTime.now();

    if (kDebugMode) print("TimeNow ready: $timeNow");

    _bookingStatus = await _loadAndCheckIfSavedBookingValid();

    switch (_bookingStatus) {
      case BookingStatus.validBooking:
        if (kDebugMode) print('Valid booking found, nothing to delete');
        break;

      case BookingStatus.invalidBooking:
        if (_isClearingBooking) return;
        _isClearingBooking = true;
        try {
          final success = await deleteBookingOnServerByID();
          // Always clear local booking, even if server deletion fails
          await _deleteLocalBookingAndNotify(
            message: 'Your previously selected trip was removed',
          );
          if (success != true && mounted) {
            if (kDebugMode) print('could not delete old booking on server');
          }
        } catch (e, st) {
          if (kDebugMode) print('Error deleting booking on server: $e\n$st');
          await _deleteLocalBookingAndNotify(
            message: 'Your previously selected trip was removed',
          );
        } finally {
          _isClearingBooking = false;
        }
        if (mounted) setState(() => selectedBox = 0);
        break;

      case BookingStatus.oldBooking:
        if (_isClearingBooking) return;
        _isClearingBooking = true;
        try {
          final success = await deleteBookingOnServerByID();
          // Always clear local booking, even if server deletion fails
          await _updateCount(
            isKAP: selectedBox == 1,
            tripNo: selectedBox == 1
                ? bookedTripIndexKAP! + 1
                : bookedTripIndexCLE! + 1,
            busStop: selectedBusStop,
            increment: false,
          );
          await _deleteLocalBookingAndNotify(message: '');
          if (success == true && kDebugMode) {
            if (kDebugMode) {
              print('Deleted Old Booking');
            }
          }
        } catch (e, st) {
          if (kDebugMode) print('Error deleting booking on server: $e\n$st');
          await _deleteLocalBookingAndNotify(message: '');
        } finally {
          _isClearingBooking = false;
        }
        if (mounted) setState(() => selectedBox = 0);
        break;

      case BookingStatus.noBooking:
        if (kDebugMode) print('No booking found, nothing to check');
        break;

      case BookingStatus.unknown:
        if (kDebugMode) print('Booking status unknown, keeping local booking');
        break;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Checking/Finding Booking on Server through Amplify---
  ///  /////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Reads a booking from the backend using the stored bookingID.
  // Returns the BookingDetails object if found, otherwise null.

  Future<BookingDetails?> _readBookingByID() async {
    if (bookingID == null) return null;
    try {
      final response = await _retry(() async {
        // Add a short timeout so the query won't hang indefinitely
        final call = Amplify.API
            .query(
              request: ModelQueries.list(
                BookingDetails.classType,
                where: BookingDetails.ID.eq(bookingID!),
                authorizationMode: APIAuthorizationType.iam,
              ),
            )
            .response;
        return await call.timeout(const Duration(seconds: 8));
      }, attempts: 2);

      final items = response.data?.items;
      if (items != null && items.isNotEmpty) {
        return items.first;
      }
      return null;
    } on ApiException catch (e, st) {
      if (kDebugMode) {
        print('readBookingByID ApiException for ID=$bookingID: $e\n$st');
      }
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        print('readBookingByID error for ID=$bookingID: $e\n$st');
      }
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Check existence on server by booking ID
  // Returns:
  //   true  -> booking exists
  //   false -> booking does not exist
  //   null  -> verification failed due to network/error (caller should retry)

  Future<bool?> _doesBookingExistByID(String id) async {
    try {
      final resp = await _retry(() async {
        final call = Amplify.API
            .query(
              request: ModelQueries.list(
                BookingDetails.classType,
                where: BookingDetails.ID.eq(id),
                authorizationMode: APIAuthorizationType.iam,
              ),
            )
            .response;
        return await call.timeout(const Duration(seconds: 8));
      }, attempts: 2);

      // check for server/network errors
      if (resp.errors.isNotEmpty) {
        if (kDebugMode) {
          print(
            'doesBookingExistByID GraphQL errors for ID=$id (server unreachable?): ${resp.errors}',
          );
        }
        return null; // could not verify due to server/network issue
      }

      final items = resp.data?.items;
      if (items != null && items.isNotEmpty) return true;
      return false;
    } on ApiException catch (e, st) {
      if (kDebugMode) {
        print(
          'doesBookingExistByID ApiException for ID=$id (verification failed): $e\n$st',
        );
      }
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        print(
          'doesBookingExistByID error for ID=$id (verification failed): $e\n$st',
        );
      }
      // Return null to indicate we couldn't verify; caller can decide to retry later
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // get the time the booking was created, if cannot find booking returns null

  Future<DateTime?> getBookingCreatedAt(String bookingId) async {
    if (kDebugMode) {
      print('afternoon_screen => getting time booking was created at');
    }
    try {
      final request = ModelQueries.get(
        BookingDetails.classType,
        BookingDetailsModelIdentifier(id: bookingId),
      );

      final response = await Amplify.API.query(request: request).response;

      final booking = response.data;
      if (booking == null) {
        return null; // booking not found
      }

      // Convert TemporalDateTime to Dart DateTime
      return booking.createdAt?.getDateTimeInUtc();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching booking: $e');
      }
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Deleting Booking ---
  ///  /////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Supposed to delete Booking Confirmation locally (through sharedPreferences)
  // And show SnackBar after deletion, if message is '', no snackBar is shown

  Future<void> _deleteLocalBookingAndNotify({required String message}) async {
    if (!mounted) return;

    if (kDebugMode) {
      print('_deleteLocalBookingAndNotify triggered message="$message"');
    }

    // Clear persisted snapshot first
    try {
      await prefsService.clearBookingData();
    } catch (e) {
      if (kDebugMode) print('Error clearing prefs: $e');
    }

    // Atomically clear UI state used by map and booking
    if (!mounted) return;
    setState(() {
      // Map/route-critical
      selectedMRT = 0;
      selectedBox = 0;
      busIndex.value = 0;
      selectedBusStop = '';

      // Booking state
      bookedTripIndexKAP = null;
      bookedTripIndexCLE = null;
      bookedDepartureTime = null;
      bookingID = null;
      confirmationPressed = false;

      // Status and snapshot
      _bookingStatus = BookingStatus.noBooking;
      _didRestoreSnapshot = false; // ensure restore is allowed later if needed
      futureBookingData = Future.value(
        null,
      ); // prevent FutureBuilder from rehydrating stale prefs
    });

    if (kDebugMode) {
      print(
        'After local delete → bookingID=$bookingID, '
        'selectedBox=$selectedBox, selectedMRT=$selectedMRT, '
        'busIndex=${busIndex.value}, selectedBusStop="$selectedBusStop", '
        'bookedDepartureTime=$bookedDepartureTime, '
        'confirmationPressed=$confirmationPressed, '
        '_bookingStatus=$_bookingStatus',
      );
    }

    if (message.isNotEmpty) _showAsyncSnackBar(message);

    // Notify parent selection change
    widget.updateSelectedBox(selectedBox);
  }

  //////////////////////////////////////////////////////////////////////////////
  // Deletes a booking on server using the stored bookingID
  // true => Successfully deleted
  // false => error during deletion, booking might still exist
  // null => booking is cannot be found (no such trip exists anymore)
  // After successful deletion, updates the passenger count for that trip.

  Future<bool> deleteBookingOnServerByID() async {
    try {
      final String? id = bookingID;
      if (kDebugMode) {
        print('deleteBookingOnServerByID called with bookingID=$id');
      }

      if (id == null || id.isEmpty) {
        if (kDebugMode) {
          print('No booking ID available; treating as already deleted');
        }
        return true; // nothing to delete
      }

      // Check existence first (optional, but your code seems to do this)
      final bool? exists = await _doesBookingExistByID(id);
      if (exists == false) {
        if (kDebugMode) {
          print('No booking found with ID: $id (already deleted)');
        }
        return true; // treat as success, proceed to local cleanup
      }
      if (exists == null) {
        if (kDebugMode) {
          print('could not reach server, so cannot cancel booking');
        }
        return false;
      }

      // Attempt delete; if mutation throws or returns null, we’ll handle errors below
      final booking = await _readBookingByID(); // returns model or null
      if (booking == null) {
        if (kDebugMode) print('Read by ID returned null; treating as deleted');
        return true;
      }

      final resp = await Amplify.API
          .mutate(
            request: ModelMutations.delete(
              booking,
              authorizationMode: APIAuthorizationType.iam,
            ),
          )
          .response;

      final ok = resp.errors.isEmpty;
      if (kDebugMode) {
        print('Server delete mutation ok=$ok, errors=${resp.errors}');
      }
      return ok;
    } catch (e, st) {
      if (kDebugMode) print('deleteBookingOnServerByID error: $e\n$st');
      return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Local saves, loads, checks if locally saved stuff is still valid ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // saves booking data locally in SharedPreferences via your prefsService

  Future<void> _saveBookingLocally(
    BookingData booking, {
    required int selectedBoxValue, // 1 for KAP, 2 for CLE
    int? bookedTripIndexKAP,
    int? bookedTripIndexCLE,
  }) async {
    // Build a prefs-compatible map here (keys & types must match saveBookingData requiredSpec)
    final Map<String, dynamic> prefsMap = {
      'bookingID': booking.id,
      'selectedBox': selectedBoxValue,
      'bookedTripIndexKAP': bookedTripIndexKAP,
      'bookedTripIndexCLE': bookedTripIndexCLE,
      'busStop': booking.busStop,
      'busIndex': booking.busIndex,
      'bookedDepartureTime': booking.departure,
      // must be DateTime or null (saveBookingData requires DateTime)
    };

    if (kDebugMode) safePrint('Attempting to save booking to prefs: $prefsMap');

    // Call the service and await its boolean result
    final bool ok = await prefsService.saveBookingData(prefsMap);

    if (!ok) {
      // Do not proceed to update UI if save failed; surface debug info
      if (kDebugMode) {
        safePrint(
          'saveBookingData returned false; map was rejected by validation',
        );
      }
      throw Exception('Failed to persist booking data locally');
    }

    // Optionally read back and log the persisted snapshot for debug confidence
    final persisted = await prefsService.getBookingData();
    if (kDebugMode) safePrint('Persisted prefs snapshot: $persisted');

    // Update the cached future and let the UI know (assign outside build)
    if (!mounted) return;
    setState(() {
      futureBookingData = Future.value(persisted);
    });

    if (kDebugMode) safePrint('Persisted and futureBookingData refreshed');
  }

  //////////////////////////////////////////////////////////////////////////////
  // loads saved booking, if none returns null
  // Returns BookingStatus when locally saved booking is still valid
  // (server ID exists or matching departure found)

  Future<BookingStatus> _loadAndCheckIfSavedBookingValid() async {
    // point at prefs-read once
    final bookingData = await futureBookingData;

    if (bookingData == null) return BookingStatus.noBooking;

    // Safe helpers
    DateTime? safeDateTime(dynamic v) {
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
      return null;
    }

    final persistedBookingID = bookingData['bookingID'] as String?;

    DateTime? dateOfBookedTrip;
    if (persistedBookingID != null) {
      dateOfBookedTrip = await getBookingCreatedAt(persistedBookingID);
      if (kDebugMode) {
        print('booking created at: $dateOfBookedTrip');
      }
    }
    if (dateOfBookedTrip != null) {
      final TimeService timeService = TimeService();
      await timeService.getTime();
      final today = timeNow ?? DateTime.now();

      final bookingDate = DateTime(
        dateOfBookedTrip.year,
        dateOfBookedTrip.month,
        dateOfBookedTrip.day,
      );

      final currentDate = DateTime(today.year, today.month, today.day);

      if (bookingDate.isBefore(currentDate)) {
        if (kDebugMode) print('Booking is from a past date → invalid');
        return BookingStatus.oldBooking;
      }
    }

    if (persistedBookingID != null) {
      try {
        final bool? exists = await _doesBookingExistByID(persistedBookingID);
        if (exists == null) {
          if (kDebugMode) {
            print('Could not verify booking ID; treating as unknown for now');
          }
          return BookingStatus.unknown;
        }

        if (exists) {
          final BookingDetails? serverBooking = await _readBookingByID();

          if (serverBooking != null) {
            // Parse server map safely (no context use here)
            final map = serverBooking.toMap().cast<String, dynamic>();
            final List<DateTime> list = getDepartureTimes();

            // If index is invalid, mark departure as null
            final int? tripNo = map['TripNo'] as int?;
            final DateTime? serverDeparture =
                (tripNo == null || tripNo - 1 < 0 || tripNo - 1 >= list.length)
                ? null
                : list[tripNo - 1];

            // Defer state mutation until after the current build frame
            if (!mounted) return BookingStatus.validBooking;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                bookingID = serverBooking.id;
                selectedBusStop = (map['BusStop'] as String?) ?? '';
                selectedBox = (map['MRTStation'] as String?) == 'KAP' ? 1 : 2;
                final tripNo = map['TripNo'] as int?;
                if (tripNo != null) {
                  if (selectedBox == 1) {
                    bookedTripIndexKAP = tripNo - 1;
                  } else {
                    bookedTripIndexCLE = tripNo - 1;
                  }
                }
                bookedDepartureTime = serverDeparture;
                confirmationPressed = true;
                // leave futureBookingData pointing to prefs; do not create a new Future.value
              });
              if (kDebugMode) {
                safePrint(
                  'Restore applied (server): id=$bookingID selBox=$selectedBox dep=${bookedDepartureTime?.toIso8601String()}',
                );
              }
            });

            return BookingStatus.validBooking;
          } else {
            if (kDebugMode) {
              print(
                'Server booking read returned null despite existence. Falling back to local snapshot.',
              );
            }

            // Safe parse of local snapshot 'bookingData' (already available in the function)
            final int? selBoxLocal = bookingData['selectedBox'] as int?;
            final int? kapLocal = bookingData['bookedTripIndexKAP'] as int?;
            final int? cleLocal = bookingData['bookedTripIndexCLE'] as int?;
            final String busLocal = (bookingData['busStop'] as String?) ?? '';
            final DateTime? localDeparture = safeDateTime(
              bookingData['bookedDepartureTime'],
            );
            final String? localId = bookingData['bookingID'] as String?;

            // Defer state mutation until after the current build frame
            if (!mounted) return BookingStatus.validBooking;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                bookingID = localId;
                selectedBusStop = busLocal;
                selectedBox = selBoxLocal == 1
                    ? 1
                    : selBoxLocal == 2
                    ? 2
                    : 0;
                if (selectedBox == 1) {
                  bookedTripIndexKAP = kapLocal;
                } else {
                  bookedTripIndexCLE = cleLocal;
                }
                bookedDepartureTime = localDeparture;
                confirmationPressed =
                    (localId != null &&
                    localDeparture != null &&
                    (selectedBox == 1 || selectedBox == 2));
              });
              if (kDebugMode) {
                safePrint(
                  'Restore applied (local): id=$bookingID selBox=$selectedBox dep=${bookedDepartureTime?.toIso8601String()}',
                );
              }
            });

            return BookingStatus.validBooking;
          }
        } else {
          return BookingStatus.invalidBooking;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error verifying booking ID, treating as unknown: $e');
        }
        return BookingStatus.unknown;
      }
    }

    // If no server id present but some local data exists, treat as invalid (or unknown per your policy)
    if (kDebugMode) {
      print('Invalid Booking. Could not find booking ID on server.');
    }
    return BookingStatus.invalidBooking;
  }

  //////////////////////////////////////////////////////////////////////////////
  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Helper ---
  ///  /////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // to retry connecting to server a few times instead of giving up after one try

  Future<T> _retry<T>(
    Future<T> Function() operation, {
    int attempts = 3,
    Duration initialDelay = const Duration(milliseconds: 200),
    int maxJitterMs = 100,
    bool Function(Object error)? shouldRetry,
  }) async {
    if (attempts <= 0) {
      throw ArgumentError.value(attempts, 'attempts', 'must be > 0');
    }

    var delay = initialDelay;
    final rng = Random();
    const Duration maxDelay = Duration(seconds: 10);

    for (var i = 0; i < attempts; i++) {
      try {
        return await operation();
      } catch (e, st) {
        if (kDebugMode) {
          print('Retry attempt ${i + 1} failed: $e');
          print(st);
        }

        // If caller supplied a predicate and it says don't retry, rethrow immediately.
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        if (i == attempts - 1) {
          rethrow;
        }

        final jitter = Duration(milliseconds: rng.nextInt(maxJitterMs));
        await Future.delayed(delay + jitter);

        // Exponential backoff with cap
        final nextMillis = delay.inMilliseconds * 2;
        delay = Duration(
          milliseconds: nextMillis.clamp(0, maxDelay.inMilliseconds),
        );
      }
    }

    throw Exception('Retry exhausted');
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- updates and get stuff ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Updates the selected box index and notifies parent widget.
  // If the same box is tapped twice, it will be deselected.

  void updateSelectedBox(int box, bool refresh) {
    // Prevent interactions while a confirmation/cancel flow is in progress.
    // confirmationPressed is tri-state: true = confirmed, false = normal, null = cancelling.

    if (confirmationPressed != false) {
      if (kDebugMode) {
        print('Tap ignored: confirmationPressed=$confirmationPressed');
      }
      return;
    }
    // Guard: ensure the State object is still mounted before making changes.
    if (!mounted) {
      if (kDebugMode) {
        print('updateSelectedBox called but not mounted');
      }
      return;
    }

    if (updatingSelectedBox == true) {
      if (kDebugMode) {
        print('Tap ignored: updatingSelectedBox=$updatingSelectedBox');
      }
      return; // return if update is in progress to prevent wrong UI loads
    }

    // fetch data, in case changes in backend
    _busData.loadData();

    if (kDebugMode) {
      // Debug: show the previous selection before we change it.
      print('Old selected Box $selectedBox in afternoon screen');
    }

    // Update local selection state immediately so subsequent logic sees the new value.
    // This ensures any refreshes or fetches that run after setState operate on the updated selection.
    setState(() {
      updatingSelectedBox = true; // setting guard to true
      // Toggle behaviour: tapping the same box deselects it (resets to 0).
      if (box != 0) {
        if (selectedBox == box) {
          selectedBox = 0;
        } else {
          selectedBox = box;
        }
        // Notify parent of the new selectedBox value (keeps parent-child synchronized).
        widget.updateSelectedBox(selectedBox);
      }
    });

    if (kDebugMode) {
      print('updated SelectedBox to $selectedBox in afternoon screen');
    }

    // Kick off data refresh for the new selection after state update.
    // Placing this after setState avoids races where refresh logic reads stale selection.
    _refreshTrips();

    // Only attempt to refresh the child BookingService when a station is selected (selectedBox != 0).
    // If selectedBox == 0 we intentionally skip refreshing the child.
    if (selectedBox != 0) {
      // Read the keyed child state once to avoid repeated lookups.
      final bookingState = _bookingKey.currentState;

      // If the child State exists and is mounted, call its refresh method immediately.
      // This keeps booking counts up-to-date without waiting for another user action.
      if (bookingState != null && (bookingState as State).mounted) {
        bookingState.refreshFromParent(refresh);
        if (kDebugMode) {
          print('booking service refreshed by afternoon screen');
        }
      } else {
        // If the child is not yet built or not mounted, schedule a retry on the next frame.
        // addPostFrameCallback runs after the current frame when the child is more likely to be created.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final s = _bookingKey.currentState;
          if (s != null && (s as State).mounted) {
            // Child is now ready: perform the refresh.
            s.refreshFromParent(refresh);
            if (kDebugMode) {
              print('booking service refreshed after first build');
            }
          } else {
            // Child still not ready after one frame: log for debugging.
            if (kDebugMode) {
              print('booking service still not ready after first frame');
            }
          }
        });

        // Debug message indicating we scheduled a deferred refresh because the child wasn't ready.
        if (kDebugMode) {
          print(
            'booking service has not been built; scheduled deferred refresh',
          );
        }
      }
    } else {
      //When the selection was reset to 0, explicitly skip attempting a child refresh.
      if (kDebugMode) {
        print('selectedBox is 0; skipping booking service refresh');
      }
    }
    Future.delayed(Duration(seconds: 1), () {
      // waits one second before freeing up guard to completely prevent loading issues
      // (not too obvious to user as animation of loading takes similar amount of time)
      if (!mounted) return;
      setState(() {
        updatingSelectedBox =
            false; // setting guard to false when done updating
        if (kDebugMode) {
          print(
            'finished updating selectedBox - now setting updatingSelectedBox to $updatingSelectedBox',
          );
        }
      });
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // Updates the booking status for KAP station trips.
  // Resets confirmation state and sets or clears the booked trip index.

  void updateBookingStatusKAP(int index, bool isSelected) {
    if (!mounted) return;
    setState(() {
      confirmationPressed = false;
      bookedTripIndexKAP = isSelected
          ? index
          : (bookedTripIndexKAP == index ? null : bookedTripIndexKAP);
    });
    if (kDebugMode) {
      print('KAP booking index: $bookedTripIndexKAP');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Updates the booking status for CLE station trips.
  // Resets confirmation state and sets or clears the booked trip index.

  void updateBookingStatusCLE(int index, bool isSelected) {
    if (!mounted) return;
    setState(() {
      confirmationPressed = false;
      bookedTripIndexCLE = isSelected
          ? index
          : (bookedTripIndexCLE == index ? null : bookedTripIndexCLE);
    });
    if (kDebugMode) {
      print('CLE booking index: $bookedTripIndexCLE');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Updates the passenger count for a specific trip and bus stop.
  // If a count record exists, it is deleted and replaced with the new count.
  // If no bookings remain, no new record is created.

  Future<void> _updateCount({
    required bool isKAP,
    required int tripNo,
    required String busStop,
    required bool increment, // true = +1, false = -1
  }) async {
    final station = isKAP ? 'KAP' : 'CLE';

    try {
      // Step 1: Query existing CountTripList entries for this station/trip/busStop
      final existingResponse = await Amplify.API
          .query(
            request: ModelQueries.list(
              CountTripList.classType,
              where: CountTripList.MRTSTATION
                  .eq(station)
                  .and(CountTripList.TRIPTIME.eq(TripTimeOfDay.AFTERNOON))
                  .and(CountTripList.TRIPNO.eq(tripNo))
                  .and(CountTripList.BUSSTOP.eq(busStop)),
              authorizationMode: APIAuthorizationType.iam,
            ),
          )
          .response;

      final items = existingResponse.data?.items.cast<CountTripList>() ?? [];

      // Step 1a: filter by createdAt → only keep rows created today (Singapore time)
      final nowLocal = DateTime.now();
      final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      final todayRows = items.where((row) {
        final createdUtc = row.createdAt?.getDateTimeInUtc();
        if (createdUtc == null) return false;

        // Convert UTC → local (SGT if device timezone is Singapore)
        final createdLocal = createdUtc.toLocal();
        final createdDate = DateTime(
          createdLocal.year,
          createdLocal.month,
          createdLocal.day,
        );

        // Compare only the date parts
        return createdDate == todayDate;
      }).toList();

      final existingRow = todayRows.isNotEmpty ? todayRows.first : null;

      if (existingRow != null) {
        // Step 2: Update existing row
        final newCount = (existingRow.Count) + (increment ? 1 : -1);

        if (newCount < 0) {
          if (kDebugMode) {
            print('No count changed, as newCount in invalid range');
          }
        } else {
          final updatedRow = existingRow.copyWith(Count: newCount);
          await Amplify.API
              .mutate(
                request: ModelMutations.update(
                  updatedRow,
                  authorizationMode: APIAuthorizationType.iam,
                ),
              )
              .response;
          if (kDebugMode) print('Updated count → $newCount');
        }
      } else {
        // Step 3: Create new row if none exists for today
        final model = CountTripList(
          MRTStation: station,
          TripTime: TripTimeOfDay.AFTERNOON,
          BusStop: busStop,
          TripNo: tripNo,
          Count: increment ? 1 : 0,
        );

        if (model.Count > 0) {
          await Amplify.API
              .mutate(
                request: ModelMutations.create(
                  model,
                  authorizationMode: APIAuthorizationType.iam,
                ),
              )
              .response;
          if (kDebugMode) print('Created new CountTripList with count=1');
        }
      }
    } catch (e, st) {
      if (kDebugMode) print('Error updating count: $e\n$st');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // fetches the number of bookings for a given MRT station and trip number for the current day
  // Returns the count as an integer, or null if an error occurs

  Future<int?> fetchPassengerCountTrip(String mrt, int tripNo) async {
    const tripTime = 'AFTERNOON';
    try {
      final request = GraphQLRequest<String>(
        document: '''
        query GetTripCounts(\$station: String!, \$tripTime: TripTimeOfDay!, \$tripNo: Int!) {
          listCountTripLists(
            filter: {
              MRTStation: { eq: \$station }
              TripTime: { eq: \$tripTime }
              TripNo: { eq: \$tripNo }
            }
          ) {
            items {
              Count
              createdAt
            }
          }
        }
      ''',
        variables: {'station': mrt, 'tripTime': tripTime, 'tripNo': tripNo},
      );

      final response = await Amplify.API.query(request: request).response;
      final data = response.data;
      if (data == null) return 0;

      final items = (jsonDecode(data)['listCountTripLists']['items'] as List);

      if (items.isEmpty) return 0;

      // Singapore local time (system timezone should be set to SGT)
      final nowLocal = DateTime.now();
      final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      final todayItems = items.where((item) {
        final createdStr = item['createdAt'];
        if (createdStr == null) return false;

        final createdUtc = DateTime.tryParse(createdStr);
        if (createdUtc == null) return false;

        // Convert UTC → local (SGT if system timezone is Singapore)
        final createdLocal = createdUtc.toLocal();
        final createdDate = DateTime(
          createdLocal.year,
          createdLocal.month,
          createdLocal.day,
        );

        // Compare only the date parts
        return createdDate == todayDate;
      }).toList();

      return todayItems.fold<int>(
        0,
        (sum, item) => sum + (item['Count'] as int),
      );
    } catch (e) {
      safePrint('Error fetching passenger count: $e');
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Returns the list of departure times based on the currently selected MRT station.
  // If `selectedBox` is 1 → return KAP departure times, otherwise return CLE departure times.

  List<DateTime> getDepartureTimes([int? box]) => (box ?? selectedBox) == 1
      ? _busData.afternoonTimesKAP
      : _busData.afternoonTimesCLE;

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- UI Helpers ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Shows a bottom sheet allowing the user to select a bus stop.
  // Updates `selectedBusStop` and `busIndex` when a stop is chosen.

  void showBusStopSelectionBottomSheet(BuildContext context) {
    final scrollController = ScrollController();

    if (kDebugMode) {
      print('afternoon_screen => bus stop selection bottom sheet built');
    }
    // Defensive guard: ensure there are at least two leading elements to skip (index + 2)
    if (_busData.busStop.length < 3) {
      // Provide lightweight feedback and avoid showing the sheet that would crash
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Center(child: Text('No bus stops available')),
          ),
        );
      }
      return;
    }
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // so we can round corners
      builder: (_) {
        return FractionallySizedBox(
          heightFactor:
              ((TextSizing.isLandscapeMode(context)
                      ? screenHeight * 0.98
                      : screenHeight * 0.8) -
                  fontSizeHeading * 3) /
              screenHeight, // finite height for the sheet
          child: Material(
            color: isDarkMode ? Colors.blueGrey[800] : Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(fontSizeText),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(fontSizeText * 0.35),
                child: Column(
                  mainAxisSize: MainAxisSize.max, // fill vertical space
                  children: [
                    SizedBox(height: fontSizeMiniText),
                    Text(
                      'Choose bus stop:',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: fontSizeHeading,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: fontSizeMiniText),
                    // Give the list bounded height via Expanded
                    Expanded(
                      child: RawScrollbar(
                        controller: scrollController,
                        thumbVisibility: true,
                        thickness: fontSizeText * 0.2,
                        radius: const Radius.circular(8),
                        thumbColor: isDarkMode ? Colors.black : Colors.grey,
                        child: ListView.builder(
                          controller: scrollController,
                          // excludes first two and last bus stop
                          itemCount: _busData.busStop.length - 3,
                          itemBuilder: (_, index) {
                            final stopName = _busData.busStop[index + 2];
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: fontSizeText,
                                vertical: fontSizeText * 0.2,
                              ),
                              child: Material(
                                color: isDarkMode
                                    ? Colors.blueGrey[700]
                                    : const Color(0xff014689),
                                borderRadius: BorderRadius.circular(
                                  fontSizeText * 0.25,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    fontSizeText * 0.25,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedBusStop = stopName;
                                      busIndex.value = index + 2;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: ListTile(
                                    title: Text(
                                      stopName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontWeight: FontWeight.w900,
                                        fontSize: TextSizing.fontSizeText(
                                          context,
                                        ),
                                      ),
                                    ),
                                    textColor: isDarkMode
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

  //////////////////////////////////////////////////////////////////////////////
  // Formats a DateTime into a string in HH:mm format with leading zeros.
  // Example: 8:5 → "08:05"

  String formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  //////////////////////////////////////////////////////////////////////////////
  // Safe snackBar poster used from async contexts
  void _showAsyncSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.black : Colors.white,
                fontFamily: 'Roboto',
                fontSize: fontSizeText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          backgroundColor: isDarkMode ? Colors.white : Colors.black,
          duration: Duration(seconds: 5),
        ),
      );
  }

  //////////////////////////////////////////////////////////////////////////////
  // Shows a booking confirmation dialog with trip details.
  // Displays trip number, time, station, and bus stop.

  void showBookingConfirmationDialog(BuildContext context) {
    final scrollController = ScrollController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Precompute trip number display for readability
        final tripIndex = selectedBox == 1
            ? bookedTripIndexKAP
            : bookedTripIndexCLE;
        final tripValue = tripIndex != null ? '${tripIndex + 1}' : '-';

        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,

          // Dialog title section
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: fontSizeHeading,
                  ), // Success icon
                  SizedBox(width: fontSizeMiniText),
                  Expanded(
                    child: Text(
                      softWrap: true,
                      'Booking Confirmed!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: fontSizeHeading,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Dialog content section
          content: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fontSizeText,
              vertical: fontSizeMiniText,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  softWrap: true,
                  'Thank you for booking with us. Your booking has been confirmed.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: fontSizeText,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: fontSizeHeading),
                Flexible(
                  child: RawScrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: fontSizeText * 0.2,
                    radius: const Radius.circular(8),
                    thumbColor: isDarkMode ? Colors.black : Colors.grey,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          // Trip number display
                          BookingConfirmationText(
                            label: 'Trip:',
                            value: tripValue,
                            size: 0.60,
                            darkText: isDarkMode ? false : true,
                            fontSizeText: fontSizeText,
                          ),
                          SizedBox(height: fontSizeMiniText),
                          // Departure time display
                          BookingConfirmationText(
                            label: 'Time:',
                            value: bookedDepartureTime != null
                                ? formatTime(bookedDepartureTime!)
                                : '-',
                            size: 0.60,
                            darkText: isDarkMode ? false : true,
                            fontSizeText: fontSizeText,
                          ),
                          SizedBox(height: fontSizeMiniText),
                          // Station name display
                          BookingConfirmationText(
                            label: 'Station:',
                            value: selectedBox == 1
                                ? 'KAP'
                                : selectedBox == 2
                                ? 'CLE'
                                : '-',
                            size: 0.60,
                            darkText: isDarkMode ? false : true,
                            fontSizeText: fontSizeText,
                          ),
                          SizedBox(height: fontSizeMiniText),
                          // Bus stop display
                          BookingConfirmationText(
                            label: 'Bus Stop:',
                            value: selectedBusStop.isNotEmpty
                                ? selectedBusStop
                                : '-',
                            size: 0.60,
                            darkText: isDarkMode ? false : true,
                            fontSizeText: fontSizeText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dialog action buttons
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSizeText,
                  fontFamily: 'Roboto',
                  color: isDarkMode
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

  //////////////////////////////////////////////////////////////////////////////
  // Builds the MRT station selection row with two selectable boxes (KAP and CLE).
  // Each box is wrapped in a GestureDetector to handle taps.

  Widget _mrtSelectionRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSizeMiniText),
      child: Row(
        children: [
          // KAP selection box
          Expanded(
            child: GestureDetector(
              onTap: () => updatingSelectedBox
                  ? null
                  : updateSelectedBox(1, false), // Select KAP
              child: BoxMRT(
                box: selectedBox,
                mrt: 'KAP',
                fontSizeText: fontSizeText,
                fontSizeHeading: fontSizeHeading,
              ),
            ),
          ),
          SizedBox(width: fontSizeMiniText), // Space between boxes
          // CLE selection box
          Expanded(
            child: GestureDetector(
              onTap: () => updatingSelectedBox
                  ? null
                  : updateSelectedBox(2, false), // Select CLE
              child: BoxMRT(
                box: selectedBox,
                mrt: 'CLE',
                fontSizeText: fontSizeText,
                fontSizeHeading: fontSizeHeading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- The Overall UI of Afternoon Screen ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Restores booking state from raw map data (server or local). needed for UI build
  // Runs only once per snapshot to avoid repeated setState calls.

  void _restoreFromDataOnce(Map<String, dynamic> raw) {
    if (_bookingStatus != BookingStatus.unknown) return;

    try {
      // Local temporaries to compute new state before applying via setState
      int newSelectedBox = 0;
      int? newBookedTripIndexKAP = bookedTripIndexKAP;
      int? newBookedTripIndexCLE = bookedTripIndexCLE;
      DateTime? newBookedDepartureTime = bookedDepartureTime;
      String newSelectedBusStop = selectedBusStop;
      String? newBookingID = bookingID;

      if (raw.containsKey('MRTStation')) {
        // Server data
        final station = raw['MRTStation'] as String?;
        newSelectedBox = station == 'KAP' ? 1 : (station == 'CLE' ? 2 : 0);

        final tripNo = raw['TripNo'] as int?;
        if (tripNo != null) {
          final tripIndex = tripNo - 1;
          if (newSelectedBox == 1) {
            newBookedTripIndexKAP = tripIndex;
          } else if (newSelectedBox == 2) {
            newBookedTripIndexCLE = tripIndex;
          }
        }

        newSelectedBusStop = raw['BusStop'] as String? ?? '';

        // Resolve departure safely using a captured list based on the computed box
        final departures = (newSelectedBox == 1)
            ? _busData.afternoonTimesKAP
            : _busData.afternoonTimesCLE;
        final idx = newSelectedBox == 1
            ? newBookedTripIndexKAP
            : newBookedTripIndexCLE;
        if (idx != null && idx >= 0 && idx < departures.length) {
          newBookedDepartureTime = departures[idx];
        } else {
          newBookedDepartureTime = null;
        }

        newBookingID = raw['id'] as String?;
      } else {
        // Local prefs data
        newSelectedBox = raw['selectedBox'] as int? ?? 0;
        newBookedTripIndexKAP = raw['bookedTripIndexKAP'] as int?;
        newBookedTripIndexCLE = raw['bookedTripIndexCLE'] as int?;
        final depRaw = raw['bookedDepartureTime'];
        if (depRaw is DateTime) {
          newBookedDepartureTime = depRaw;
        } else if (depRaw is int) {
          newBookedDepartureTime = DateTime.fromMillisecondsSinceEpoch(depRaw);
        } else if (depRaw is String) {
          try {
            newBookedDepartureTime = DateTime.parse(depRaw);
          } catch (_) {
            newBookedDepartureTime = null;
          }
        }
        newSelectedBusStop = raw['busStop'] as String? ?? '';
        newBookingID = raw['id'] as String? ?? raw['bookingID'] as String?;
      }

      // Apply all computed values atomically after the current frame
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          selectedBox = newSelectedBox;
          bookedTripIndexKAP = newBookedTripIndexKAP;
          bookedTripIndexCLE = newBookedTripIndexCLE;
          bookedDepartureTime = newBookedDepartureTime;
          selectedBusStop = newSelectedBusStop;
          bookingID = newBookingID;

          confirmationPressed = true;
          _bookingStatus = BookingStatus.validBooking;
        });
      });
    } catch (e, st) {
      if (kDebugMode) print('Restore booking failed: $e\n$st');

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          confirmationPressed = false;
          _bookingStatus = BookingStatus.invalidBooking;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('afternoon_screen built');

    final int currentBox = selectedBox;

    // Extracted helper for booking section to improve readability
    Widget bookingSection() {
      if (loadingInitialData) {
        if (kDebugMode) {
          print('loadingInitialData=true → hiding booking UI');
        }
        return const SizedBox();
      }

      if (selectedBox == 0) {
        return const SizedBox();
      }

      if (confirmationPressed == true) {
        // If booking has already been confirmed → show BookingConfirmation widget
        return BookingConfirmation(
          selectedBox: currentBox,
          bookedTripIndexKAP: bookedTripIndexKAP,
          bookedTripIndexCLE: bookedTripIndexCLE,
          bookedDepartureTime: bookedDepartureTime,
          busStop: selectedBusStop,
          fontSizeMiniText: fontSizeMiniText,
          fontSizeText: fontSizeText,
          fontSizeHeading: fontSizeHeading,
          onCancel: () async {
            // Cancel booking → reset confirmation state and delete booking if exists
            if (!mounted) return;
            setState(
              () => confirmationPressed = null,
            ); // null = cancelling in progress
            bool? deleted = await deleteBookingOnServerByID();

            if (deleted == true) {
              await _updateCount(
                isKAP: selectedBox == 1,
                tripNo: selectedBox == 1
                    ? bookedTripIndexKAP! + 1
                    : bookedTripIndexCLE! + 1,
                busStop: selectedBusStop,
                increment: false,
              );
              await _deleteLocalBookingAndNotify(
                message: 'Booking has been Cancelled.',
              );
              if (!mounted) return;
              setState(() => confirmationPressed = false);
            } else {
              setState(() => confirmationPressed = true);
              _showAsyncSnackBar('Could not delete Booking.');
            }
            updateSelectedBox(0, false);
          },
        );
      } else if (confirmationPressed == false) {
        // If booking not yet confirmed → show BookingService widget
        return BookingService(
          key: _bookingKey,
          departureTimes: getDepartureTimes(currentBox),
          selectedBox: currentBox,
          bookedTripIndexKAP: bookedTripIndexKAP,
          bookedTripIndexCLE: bookedTripIndexCLE,
          updateBookingStatusKAP: updateBookingStatusKAP,
          updateBookingStatusCLE: updateBookingStatusCLE,
          countBooking: fetchPassengerCountTrip,
          showBusStopSelectionBottomSheet: showBusStopSelectionBottomSheet,
          selectedBusStop: selectedBusStop,
          onPressedConfirm: () async {
            updatingSelectedBox = true;
            if (kDebugMode) {
              print('confirming Booking...');
            }
            // Capture values synchronously to avoid races across awaits
            final boxAtTap = currentBox;
            final idx = boxAtTap == 1 ? bookedTripIndexKAP : bookedTripIndexCLE;
            final selectedBusStopAtTap = selectedBusStop;
            final List<DateTime> list = getDepartureTimes();
            final stationAtTap = boxAtTap == 1
                ? 'KAP'
                : boxAtTap == 2
                ? 'CLE'
                : '';

            if (idx == null ||
                selectedBusStopAtTap.isEmpty ||
                stationAtTap.isEmpty) {
              _showAsyncSnackBar('Please select a trip and bus stop.');
              updatingSelectedBox = false;
              return;
            }

            bookedDepartureTime = list[idx];

            bool? bookingValid = await createBooking(
              stationAtTap,
              idx + 1,
              selectedBusStopAtTap,
            );

            if (bookingValid != true) {
              if (!mounted) return;
              _showAsyncSnackBar('Could not book trip.');
              setState(() {
                // resets everything just to be sure
                confirmationPressed = false;
                bookedTripIndexKAP = null;
                bookedTripIndexCLE = null;
                bookingID = null;
                bookedDepartureTime = null;
                _bookingStatus = BookingStatus.noBooking;
              });

              updatingSelectedBox = false;
              updateSelectedBox(0, true);
              return;
            }
            if (!mounted) {
              updatingSelectedBox = false;
              return;
            }

            setState(() => confirmationPressed = true);

            // Capture the dialog function synchronously
            void showDialogFn() => showBookingConfirmationDialog(context);

            if (!mounted) {
              updatingSelectedBox = false;
              return;
            }
            showDialogFn();
            updatingSelectedBox = false;
          },
        );
      } else {
        // Cancelling state
        return Column(
          children: [
            Text(
              'Cancelling Booking...',
              style: TextStyle(
                color: Colors.blueGrey[200],
                fontSize: fontSizeText,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            LoadingScroll(),
          ],
        );
      }
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: futureBookingData,
      builder: (context, snapshot) {
        // 1. While waiting for the future to complete → show loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            print('waiting for snapshot to complete');
          }
          return const Center(child: LoadingScreen());
        }

        // 2. If there was an error loading the data → show error message
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading data. Please try again later.',
              softWrap: true,
              style: TextStyle(
                color: Colors.blueGrey[200],
                fontSize: fontSizeText,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          );
        }

        // 3. If booking data exists → restore state
        if (snapshot.hasData && snapshot.data != null && !_didRestoreSnapshot) {
          _didRestoreSnapshot = true;
          _restoreFromDataOnce(snapshot.data!);
        }

        // If booking is invalid → schedule cleanup (guarded so it only runs once)
        if ((_bookingStatus == BookingStatus.invalidBooking ||
                _bookingStatus == BookingStatus.oldBooking) &&
            !_isClearingBooking) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final ok = await deleteBookingOnServerByID();
            await _deleteLocalBookingAndNotify(
              message: _bookingStatus == BookingStatus.invalidBooking
                  ? 'Invalid booking has been deleted'
                  : '',
            );
            _isClearingBooking = false;
            if (kDebugMode) print('Cleanup completed, ok=$ok');
          });
        }

        // Returned widget that is shown on screen
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MRT station selection row (KAP / CLE)
            loadingInitialData ? LoadingScreen() : _mrtSelectionRow(),

            SizedBox(height: fontSizeText),

            // Only show booking UI if a station has been selected
            loadingInitialData ? SizedBox() : bookingSection(),
          ],
        );
      },
    );
  }
}
