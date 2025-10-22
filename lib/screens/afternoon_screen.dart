import 'dart:async'; // For using Future, async/await, and delayed actions
import 'dart:math'; //

// Amplify packages for API and DataStore functionality
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
// Flutter UI framework
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart'; // Local bus data helper
import 'package:user_14_updated/data/global.dart'; // Global variables
import 'package:user_14_updated/models/model_provider.dart'; // Amplify model provider
import 'package:user_14_updated/services/booking_confirmation.dart'; // Booking confirmation UI
import 'package:user_14_updated/services/booking_service.dart'; // Booking servicing confirmation UI
import 'package:user_14_updated/services/shared_preference.dart'; // SharedPreferences wrapper
import 'package:user_14_updated/utils/booking_data_consistent_format.dart'; // to have a singular format for booking, no matter if it is loaded from save, or from server
import 'package:user_14_updated/utils/loading.dart'; // For loading
import 'package:user_14_updated/utils/styling_line_and_buttons.dart'; // Styling helpers
import 'package:user_14_updated/utils/text_sizing.dart'; // sizing, so it stays consistent
import 'package:user_14_updated/utils/text_styles_booking_confirmation.dart'; // Text style helpers
// For generating unique IDs
import 'package:uuid/uuid.dart';

////////////////////////////////////////////////////////////////////////////////
// enum to check what BookingStatus the booking has

enum BookingStatus { unknown, noBooking, validBooking, invalidBooking }

////////////////////////////////////////////////////////////////////////////////

/// ////////////////////////////////////////////////////////////////////////////
/// --- Afternoon Screen---
/// ////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// AfternoonScreen class
// Displays the afternoon booking interface, handles user selection,
// booking creation, and integration with Amplify backend.

class AfternoonScreen extends StatefulWidget {
  final Function(int)
  updateSelectedBox; // Callback to parent when selection changes
  const AfternoonScreen({required this.updateSelectedBox, super.key});
  @override
  State<AfternoonScreen> createState() => _AfternoonScreenState();
}

class _AfternoonScreenState extends State<AfternoonScreen>
    with WidgetsBindingObserver {
  // Flag to prevent multiple confirmations
  bool? confirmationPressed = false;

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

  //////////////////////////////////////////////////////////////////////////////
  // Init function (called when first built)
  @override
  void initState() {
    super.initState();
    selectedBox = selectedMRT; // sync with global if needed
    WidgetsBinding.instance.addObserver(this);

    // Initialize the future once and cache it
    futureBookingData = prefsService.getBookingData();

    // Defer running the restore check until after the first frame so setState
    // inside the loader will not run during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // don't await here; we spawn the async task safely
      _loadAndCheckIfSavedBookingValid();
    });

    loadInitialData();
    _restartPolling();

    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
    }

    // Make the listener a synchronous VoidCallback that spawns an async task.
    _busDataListener = () {
      // Spawn the async handler without awaiting so the listener API remains sync.
      _onBusDataChanged();
    };
    _busData.addListener(_busDataListener!);

    if (kDebugMode) {
      print("TimeNow ready: $timeNow");
    }
    _didRestoreSnapshot = false;
  }

  // Async handler invoked by the sync listener
  Future<void> _onBusDataChanged() async {
    if (!mounted) return;
    try {
      final previousStatus = _bookingStatus;
      _bookingStatus = await _loadAndCheckIfSavedBookingValid();

      if (_bookingStatus == BookingStatus.invalidBooking) {
        // Avoid scheduling multiple cleanups: set guard synchronously first
        if (_isClearingBooking) return;
        _isClearingBooking = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            _isClearingBooking = false;
            return;
          }
          // Run cleanup and ensure guard is cleared afterwards
          _deleteLocalBookingAndNotify(
            message: 'Your previously selected trip was removed',
          ).whenComplete(() {
            _isClearingBooking = false;
          });
        });
        return;
      }

      if (previousStatus != _bookingStatus) {
        setState(() {});
      }
    } catch (e, st) {
      if (kDebugMode) print('Error in busDataListener: $e\n$st');
    }
  }

  void _restartPolling() {
    try {
      _busData.stopPolling();
    } catch (e, st) {
      if (kDebugMode) print("Error stopping polling before restart: $e\n$st");
    }
    _busData.startPolling(interval: const Duration(seconds: 30));
  }

  Future<void> loadInitialData() async {
    await _waitForTimeAndCheckBooking();
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
    try {
      _busData.stopPolling();
    } catch (e, st) {
      if (kDebugMode) {
        print("Error stopping polling: $e\n$st");
      }
    }
    // stop polling when screen disposed
    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to check if app is used in foreground or open in background
  // (or is reopened from the background)

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restart polling immediately
      try {
        _restartPolling();
      } catch (e, st) {
        if (kDebugMode) {
          print(
            "Error restarting polling in change of AppLifecycleState: $e\n$st",
          );
        }
      }

      // Force immediate data refresh
      _busData.loadData();

      // Rebuild UI to reflect fresh data
      if (mounted) setState(() {});
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Stop polling to conserve resources
      try {
        _busData.stopPolling();
      } catch (e, st) {
        if (kDebugMode) {
          print(
            "Error stopping polling in change of AppLifecycleState: $e\n$st",
          );
        }
      }
    }
  }

  Future<void> onResume() async {
    await _waitForTimeAndCheckBooking();
  }

  //////////////////////////////////////////////////////////////////////////////

  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Amplify and Creating Booking ---
  ///  /////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Configures Amplify with DataStore and API plugins.
  // Uses the generated amplifyconfiguration.dart file.

  //Future<void> _configureAmplify() async {
  //try {
  //if (!Amplify.isConfigured) {
  //final provider = ModelProvider();
  // Amplify.addPlugin(AmplifyDataStore(modelProvider: provider));
  // Amplify.addPlugin(
  //  AmplifyAPI(options: APIPluginOptions(modelProvider: provider)),
  // );
  // await Amplify.configure(amplifyconfig);
  // if (kDebugMode) print('Amplify configured');
  //  }
  //  } catch (e, st) {
  //  if (kDebugMode) {
  //  print('Amplify configuration error: $e\n$st');
  //}
  // }
  //}

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
    int? checkIfTripFull = await countBooking(mrtStation, tripNo);
    if (checkIfTripFull == busMaxCapacity) {
      if (kDebugMode) {
        print(
          'Create Booking failed as Bus already full - checkIfTripFull: $checkIfTripFull BusMaxCapacity: $busMaxCapacity',
        );
      }
      return false;
    }

    try {
      final model = BOOKINGDETAILS5(
        id: const Uuid().v4(),
        MRTStation: mrtStation,
        TripNo: tripNo,
        BusStop: busStop,
      );

      final response = await Amplify.API
          .mutate(request: ModelMutations.create(model))
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
        busIndex: busIndex,
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
            bookedTripIndexCLE = bookedTripIndexCLE; // keep existing as-is
          } else {
            bookedTripIndexCLE = idx;
            bookedTripIndexKAP = bookedTripIndexKAP; // keep existing as-is
          }
          bookedDepartureTime = departure;
          selectedBusStop = booking.busStop;
          // other fields used by BookingConfirmation:
          // busIndex already present; keep it
          _bookingStatus = newStatus;
          // Do not flip confirmationPressed here if you show confirmation via dialog;
          // if you need to show BookingConfirmation widget inline, set confirmationPressed = true here.
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
      _updateCount(mrtStation == 'KAP', tripNo, busStop);
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

    // Load booking status (ensure this call also populates any local booking fields like bookedDepartureTime)
    _bookingStatus = await _loadAndCheckIfSavedBookingValid();

    // Capture a single reference to "now" for consistent comparisons in this method
    final now = DateTime.now();

    switch (_bookingStatus) {
      case BookingStatus.validBooking:
        // Booking is fine, but check if departure has already passed
        if (bookedDepartureTime != null && bookedDepartureTime!.isBefore(now)) {
          if (kDebugMode) print('Booking has expired → invalid');

          // Mark invalid and ensure we set the clearing guard synchronously
          _bookingStatus = BookingStatus.invalidBooking;
          if (!_isClearingBooking) _isClearingBooking = true;

          try {
            await _deleteLocalBookingAndNotify(
              message: 'Your booking has expired',
            );
          } finally {
            _isClearingBooking = false;
          }

          if (!mounted) return;
          setState(() => selectedBox = 0);
          widget.updateSelectedBox(selectedBox);
        }
        break;

      case BookingStatus.invalidBooking:
        // Cleanup if booking is invalid or old
        if (!_isClearingBooking) _isClearingBooking = true;
        try {
          final success = await deleteBookingOnServerByID();
          if (success == true) {
            await _deleteLocalBookingAndNotify(
              message: 'Your previously selected trip was removed',
            );
          } else {
            if (!mounted) return;
            _showAsyncSnackBar(
              'Could not delete booking on server. Please try again later.',
            );
          }
        } catch (e) {
          if (kDebugMode) print('Error deleting booking on server: $e');
        } finally {
          _isClearingBooking = false;
        }

        if (!mounted) return;
        setState(() => selectedBox = 0);
        widget.updateSelectedBox(selectedBox);
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
  // Reads a booking from the backend using the stored bookingID.
  // Returns the bookingdetails5 object if found, otherwise null.

  Future<BOOKINGDETAILS5?> _readBookingByID() async {
    if (bookingID == null) return null;
    try {
      final response = await _retry(() async {
        // Add a short timeout so the query won't hang indefinitely
        final call = Amplify.API
            .query(
              request: ModelQueries.list(
                BOOKINGDETAILS5.classType,
                where: BOOKINGDETAILS5.ID.eq(bookingID!),
              ),
            )
            .response;
        return await call.timeout(const Duration(seconds: 8));
      }, attempts: 2);

      final items = response.data?.items;
      return (items?.isNotEmpty == true) ? items!.first : null;
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
                BOOKINGDETAILS5.classType,
                where: BOOKINGDETAILS5.ID.eq(id),
              ),
            )
            .response;
        return await call.timeout(const Duration(seconds: 8));
      }, attempts: 2);

      final items = resp.data?.items;
      return items?.isNotEmpty == true;
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

  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Deleting Booking ---
  ///  /////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Supposed to delete Booking Confirmation locally (through sharedPreferences)
  // And show SnackBar after deletion, if message is '', no snackBar is shown

  Future<void> _deleteLocalBookingAndNotify({required String message}) async {
    if (!mounted || _isClearingBooking) return;
    _isClearingBooking = true;

    try {
      // Close any open dialog
      // Capture navigator/messenger synchronously in a null-safe way
      final NavigatorState? nav = Navigator.maybeOf(
        context,
        rootNavigator: true,
      );

      // Close any open dialog
      try {
        if (nav?.canPop() == true) {
          nav!.maybePop();
        }
      } catch (_) {}

      // Clear prefs
      try {
        await prefsService.clearBookingData();
      } catch (e) {
        if (kDebugMode) print('Error clearing prefs: $e');
      }

      if (!mounted) return;

      // Reset local state
      setState(() {
        busIndex = 0;
        selectedMRT = 0;
        selectedBox = 0;
        bookedTripIndexKAP = null;
        bookedTripIndexCLE = null;
        bookingID = null;
        confirmationPressed = false;
        _bookingStatus = BookingStatus.noBooking;

        // Reset the future so FutureBuilder resolves cleanly
        futureBookingData = Future.value(null);
      });

      if (kDebugMode) print('Deleted Local Booking Data');

      // Show feedback (use messenger captured earlier)
      if (message.isNotEmpty) {
        _showAsyncSnackBar(message);
      }

      // Notify parent (safe because we checked mounted above and setState ran)
      if (mounted) widget.updateSelectedBox(selectedBox);
    } finally {
      _isClearingBooking = false;
      _bookingStatus = BookingStatus.noBooking; // ensure consistent state
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Deletes a booking on server using the stored bookingID
  // true => Successfully deleted
  // false => error during deletion, booking might still exist
  // null => booking is cannot be found (no such trip exists anymore)
  // After successful deletion, updates the passenger count for that trip.

  Future<bool?> deleteBookingOnServerByID() async {
    final booking = await _readBookingByID();
    if (booking == null) {
      if (kDebugMode) print('No booking found with ID: $bookingID');
      return null;
    }

    try {
      // Attempt delete
      await Amplify.API
          .mutate(request: ModelMutations.delete(booking))
          .response;

      // After delete, verify the ID is gone with retries
      bool stillExists = true;
      try {
        final exists = await _retry(() async {
          return await _doesBookingExistByID(booking.id);
        }, attempts: 3);

        stillExists =
            exists ?? true; // null = inconclusive => assume still exists
      } catch (e, st) {
        if (kDebugMode) print('Post-delete verification error: $e\n$st');
        stillExists = true;
      }

      if (stillExists) {
        // Capture messenger synchronously before any awaits (none here, but keep pattern)
        if (mounted) {
          _showAsyncSnackBar(
            'Failed to confirm deletion on server. Your booking remains saved and will be retried.',
          );
        }
        if (kDebugMode) {
          print('Booking still exists after delete attempt: ${booking.id}');
        }
        return false;
      } else {
        // Deletion confirmed: update counts on server
        await _updateCount(
          booking.MRTStation == 'KAP',
          booking.TripNo,
          booking.BusStop,
        );
        if (kDebugMode) print('Booking deleted and verified: ${booking.id}');
        return true;
      }
    } catch (e, st) {
      if (kDebugMode) print('Error deleting booking by ID: $e\n$st');
      if (mounted) {
        _showAsyncSnackBar('Error deleting booking. Please try again later.');
      }
      return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  /// //////////////////////////////////////////////////////////////////////////
  /// --- Local saves, loads, checks if locally saved stuff is still valid ---
  /// //////////////////////////////////////////////////////////////////////////

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
      'bookedDepartureTime': booking
          .departure, // must be DateTime or null (saveBookingData requires DateTime)
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
    final newFuture = prefsService.getBookingData();
    if (!mounted) return;
    setState(() {
      futureBookingData = newFuture;
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

    final departure = safeDateTime(bookingData['bookedDepartureTime']);
    if (departure != null) {
      final today = DateTime.now();
      final bookingDate = DateTime(
        departure.year,
        departure.month,
        departure.day,
      );
      final currentDate = DateTime(today.year, today.month, today.day);
      if (bookingDate.isBefore(currentDate)) {
        if (kDebugMode) print('Booking is from a past date → invalid');
        return BookingStatus.invalidBooking;
      }
    }

    final persistedBookingID = bookingData['bookingID'] as String?;
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
          final BOOKINGDETAILS5? serverBooking = await _readBookingByID();

          if (serverBooking != null) {
            // Parse server map safely (no context use here)
            final map = serverBooking.toMap().cast<String, dynamic>();
            final List<DateTime> list = getDepartureTimes();

            // If index is invalid, mark departure as null
            final DateTime? serverDeparture =
                (map['TripNo'] - 1 == null ||
                    map['TripNo'] - 1 < 0 ||
                    map['TripNo'] - 1 >= list.length)
                ? null
                : list[map['TripNo']];

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
    return BookingStatus.invalidBooking;
  }

  //////////////////////////////////////////////////////////////////////////////

  ///  /////////////////////////////////////////////////////////////////////////
  /// --- Helper ---
  ///  /////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////

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
  // Updates the selected box index and notifies parent widget.
  // If the same box is tapped twice, it will be deselected.

  void updateSelectedBox(int box) {
    if (confirmationPressed == false) {
      if (!mounted) return;
      setState(() {
        // If the same box is tapped again, deselect it
        if (selectedBox == box) {
          selectedBox = 0;
          selectedMRT = 0; // reset global
        } else {
          selectedBox = box;
          selectedMRT = box; // update global
        }
        if (kDebugMode) {
          print('Selected box updated: $selectedBox');
        }

        // Notify parent widget of change synchronously inside setState
        widget.updateSelectedBox(selectedBox);
      });
    }
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
      print('KAP booking index: $bookedTripIndexCLE');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Updates the passenger count for a specific trip and bus stop.
  // If a count record exists, it is deleted and replaced with the new count.
  // If no bookings remain, no new record is created.

  Future<void> _updateCount(bool isKAP, int tripNo, String busStop) async {
    final ModelType<Model> classType = isKAP
        ? KAPAfternoon.classType
        : CLEAfternoon.classType;

    final whereClause = isKAP
        ? KAPAfternoon.TRIPNO.eq(tripNo).and(KAPAfternoon.BUSSTOP.eq(busStop))
        : CLEAfternoon.TRIPNO.eq(tripNo).and(CLEAfternoon.BUSSTOP.eq(busStop));

    try {
      // Step 1: Delete existing count record if present (use retry and timeout)
      final existing = await _retry(() async {
        final call = Amplify.API
            .query(request: ModelQueries.list(classType, where: whereClause))
            .response;
        return await call.timeout(const Duration(seconds: 8));
      }, attempts: 2);

      final items = existing.data?.items;
      final existingRow = (items != null && items.isNotEmpty)
          ? items.first
          : null;
      if (existingRow != null) {
        await Amplify.API
            .mutate(request: ModelMutations.delete(existingRow))
            .response;
      }

      // Step 2: Count current bookings (use retry)
      final countResult = await _retry(() async {
        return await countBooking(isKAP ? 'KAP' : 'CLE', tripNo);
      }, attempts: 2);

      // If countResult is null, treat as inconclusive and skip changes to avoid accidental deletions
      if (countResult == null) {
        if (kDebugMode) {
          print(
            'Counting bookings inconclusive, skipping count update for $tripNo at $busStop',
          );
        }
        return;
      }
      final count = countResult;

      // Step 3: If there are bookings, create a new count record
      if (count > 0) {
        final model = isKAP
            ? KAPAfternoon(BusStop: busStop, TripNo: tripNo, Count: count)
            : CLEAfternoon(BusStop: busStop, TripNo: tripNo, Count: count);

        await Amplify.API
            .mutate(request: ModelMutations.create(model))
            .response;
      }

      if (kDebugMode) {
        print(
          'Updated count for ${isKAP ? 'KAP' : 'CLE'} trip $tripNo at $busStop → $count',
        );
      }
    } catch (e, st) {
      if (kDebugMode) print('Error updating count: $e\n$st');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Counts the number of bookings for a given MRT station and trip number.
  // Returns the count as an integer, or null if an error occurs.

  Future<int?> countBooking(String mrt, int tripNo) async {
    try {
      // Use retry/timeout guard to be resilient
      final response = await _retry(() async {
        final call = Amplify.API
            .query(
              request: ModelQueries.list(
                BOOKINGDETAILS5.classType,
                where: BOOKINGDETAILS5.MRTSTATION
                    .eq(mrt)
                    .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo)),
              ),
            )
            .response;
        return await call.timeout(const Duration(seconds: 8));
      }, attempts: 2);

      // Count the number of matching bookings (watch for pagination if dataset grows)
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

  //////////////////////////////////////////////////////////////////////////////
  // Returns the list of departure times based on the currently selected MRT station.
  // If `selectedBox` is 1 → return KAP departure times, otherwise return CLE departure times.

  List<DateTime> getDepartureTimes([int? box]) => (box ?? selectedBox) == 1
      ? _busData.departureTimeKAP
      : _busData.departureTimeCLE;

  //////////////////////////////////////////////////////////////////////////////

  /// //////////////////////////////////////////////////////////////////////////
  /// --- UI Helpers ---
  /// //////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Shows a bottom sheet allowing the user to select a bus stop.
  // Updates `selectedBusStop` and `busIndex` when a stop is chosen.

  void showBusStopSelectionBottomSheet(BuildContext context) {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // so we can round corners
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.65, // finite height for the sheet
          child: Material(
            color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
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
                    SizedBox(height: TextSizing.fontSizeMiniText(context)),
                    Text(
                      'Choose bus stop:',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: TextSizing.fontSizeHeading(context),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
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
                              color: isDarkMode
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
                fontSize: TextSizing.fontSizeText(context),
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
    showDialog(
      context: context,
      builder: (_) {
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
                    size: TextSizing.fontSizeHeading(context),
                  ), // Success icon
                  SizedBox(width: TextSizing.fontSizeMiniText(context)),
                  Expanded(
                    child: Text(
                      softWrap: true,
                      'Booking Confirmed!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: TextSizing.fontSizeHeading(context),
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
              horizontal: TextSizing.fontSizeText(context),
              vertical: TextSizing.fontSizeMiniText(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  softWrap: true,
                  'Thank you for booking with us. Your booking has been confirmed.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: TextSizing.fontSizeText(context),
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: TextSizing.fontSizeHeading(context)),

                SingleChildScrollView(
                  child: ListBody(
                    children: [
                      // Trip number display
                      BookingConfirmationText(
                        label: 'Trip:',
                        // safe trip display: use local indices but guard null
                        value:
                            '${(selectedBox == 1 ? bookedTripIndexKAP : bookedTripIndexCLE) != null ? (selectedBox == 1 ? bookedTripIndexKAP! + 1 : bookedTripIndexCLE! + 1) : '-'}',
                        size: 0.60,
                        darkText: isDarkMode ? false : true,
                      ),
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
                      // Departure time display
                      BookingConfirmationText(
                        label: 'Time:',
                        value: bookedDepartureTime != null
                            ? formatTime(bookedDepartureTime!)
                            : '-',
                        size: 0.60,
                        darkText: isDarkMode ? false : true,
                      ),
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
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
                      ),
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
                      // Bus stop display
                      BookingConfirmationText(
                        label: 'Bus Stop:',
                        value: selectedBusStop.isNotEmpty
                            ? selectedBusStop
                            : '-',
                        size: 0.60,
                        darkText: isDarkMode ? false : true,
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
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: TextSizing.fontSizeText(context),
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
      padding: EdgeInsets.symmetric(
        horizontal: TextSizing.fontSizeMiniText(context),
      ),
      child: Row(
        children: [
          // KAP selection box
          Expanded(
            child: GestureDetector(
              onTap: () => updateSelectedBox(1), // Select KAP
              child: BoxMRT(box: selectedBox, mrt: 'KAP'),
            ),
          ),
          SizedBox(
            width: TextSizing.fontSizeMiniText(context),
          ), // Space between boxes
          // CLE selection box
          Expanded(
            child: GestureDetector(
              onTap: () => updateSelectedBox(2), // Select CLE
              child: BoxMRT(box: selectedBox, mrt: 'CLE'),
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
            ? _busData.departureTimeKAP
            : _busData.departureTimeCLE;
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
        newBookedDepartureTime = raw['bookedDepartureTime'] is DateTime
            ? raw['bookedDepartureTime'] as DateTime
            : null;
        newSelectedBusStop = raw['busStop'] as String? ?? '';
        newBookingID = raw['bookingID'] as String?;
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
    } catch (e) {
      if (kDebugMode) print('Restore booking failed: $e');
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
    final int currentBox = selectedBox;

    return FutureBuilder<Map<String, dynamic>?>(
      future: futureBookingData,
      builder: (context, snapshot) {
        // 1. While waiting for the future to complete → show loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingScreen());
        }

        // 2. If there was an error loading the data → show error message
        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading data', softWrap: true),
          );
        }

        // 3. If booking data exists → restore state
        if (snapshot.hasData && snapshot.data != null && !_didRestoreSnapshot) {
          _didRestoreSnapshot = true;
          _restoreFromDataOnce(snapshot.data!);
        }

        // If booking is invalid → schedule cleanup (guarded so it only runs once)
        if (_bookingStatus == BookingStatus.invalidBooking &&
            !_isClearingBooking) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await deleteBookingOnServerByID();
            await _deleteLocalBookingAndNotify(
              message: 'Invalid booking has been deleted',
            );
          });
        }

        // Returned widget that is shown on screen
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: TextSizing.fontSizeMiniText(context)),

            // Title: "Select MRT"
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Select MRT',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: TextSizing.fontSizeText(context),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),

            SizedBox(height: TextSizing.fontSizeMiniText(context)),

            // MRT station selection row (KAP / CLE)
            _mrtSelectionRow(),

            SizedBox(height: TextSizing.fontSizeText(context)),

            // Only show booking UI if a station has been selected
            if (currentBox != 0)
              // If booking has already been confirmed → show BookingConfirmation widget
              (confirmationPressed == true)
                  ? BookingConfirmation(
                      selectedBox: currentBox,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      bookedDepartureTime: bookedDepartureTime,
                      busStop: selectedBusStop,
                      onCancel: () async {
                        // Cancel booking → reset confirmation state and delete booking if exists
                        if (!mounted) return;
                        setState(() => confirmationPressed = null);
                        bool? deleted = await deleteBookingOnServerByID();

                        if (deleted == true) {
                          await _deleteLocalBookingAndNotify(
                            message: 'Booking has been Cancelled.',
                          );
                          setState(() => confirmationPressed = false);
                        } else {
                          setState(() => confirmationPressed = true);
                          _showAsyncSnackBar('Could not delete Booking.');
                        }
                      },
                    )
                  // If booking not yet confirmed → show BookingService widget
                  : (confirmationPressed == false)
                  ? BookingService(
                      departureTimes: getDepartureTimes(currentBox),
                      selectedBox: currentBox,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      updateBookingStatusKAP: updateBookingStatusKAP,
                      updateBookingStatusCLE: updateBookingStatusCLE,
                      countBooking: countBooking,
                      showBusStopSelectionBottomSheet:
                          showBusStopSelectionBottomSheet,
                      selectedBusStop: selectedBusStop,
                      onPressedConfirm: () async {
                        // Capture values synchronously to avoid races across awaits
                        final boxAtTap = currentBox;
                        final idx = boxAtTap == 1
                            ? bookedTripIndexKAP
                            : bookedTripIndexCLE;
                        final selectedBusStopAtTap = selectedBusStop;
                        final stationAtTap = boxAtTap == 1
                            ? 'KAP'
                            : boxAtTap == 2
                            ? 'CLE'
                            : '';

                        if (idx == null ||
                            selectedBusStopAtTap.isEmpty ||
                            stationAtTap.isEmpty) {
                          _showAsyncSnackBar(
                            'Please select a trip and bus stop.',
                          );
                          return;
                        }

                        bool? bookingValid = await createBooking(
                          stationAtTap,
                          idx + 1,
                          selectedBusStopAtTap,
                        );

                        if (bookingValid != true) {
                          _showAsyncSnackBar(
                            'Could not book. Trip is already fully booked.',
                          );
                          setState(() {
                            confirmationPressed = false;
                          });
                          return;
                        }
                        if (!mounted) return;

                        setState(() => confirmationPressed = true);

                        // Capture the dialog function synchronously
                        void showDialogFn() =>
                            showBookingConfirmationDialog(context);

                        if (!mounted) return;
                        showDialogFn();
                      },
                    )
                  : Column(
                      children: [
                        Text(
                          'Cancelling Booking...',
                          style: TextStyle(
                            color: Colors.blueGrey[200],
                            fontSize: TextSizing.fontSizeText(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        LoadingScroll(),
                      ],
                    ),
          ],
        );
      },
    );
  }
}
