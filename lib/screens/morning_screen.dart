import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/get_data.dart';
import '../data/global.dart';
import '../services/get_morning_eta.dart';
import '../utils/loading.dart';
import '../utils/styling_line_and_buttons.dart';
import '../utils/text_sizing.dart';

///////////////////////////////////////////////////////////////
// Class for Morning screen

class MorningScreen extends StatefulWidget {
  final Function(int) updateSelectedBox;

  const MorningScreen({super.key, required this.updateSelectedBox});

  @override
  MorningScreenState createState() => MorningScreenState();
}

class MorningScreenState extends State<MorningScreen>
    with WidgetsBindingObserver {
  int selectedBox = 0; // Default: no selection

  // the busData
  final BusData busData = BusData();

  // Listener token for BusData ChangeNotifier
  late VoidCallback _busDataListener;

  // Local loading flag driven by BusData
  bool _isLoading = true;

  // Cached lists to detect additions/removals
  List<DateTime> _lastArrivalKAP = [];
  List<DateTime> _lastArrivalCLE = [];
  List<DateTime> _lastDepartureKAP = [];
  List<DateTime> _lastDepartureCLE = [];

  // used to check for AppLifeCycle
  AppLifecycleState? _previousAppLifecycleState;
  DateTime? _lastBackgroundAt;
  final Duration _resumeCooldown = const Duration(seconds: 2);
  final Duration _inactivityStopDelay = const Duration(milliseconds: 900);

  // timers for AppLifeCycle
  Timer? _inactivityStopTimer;
  Timer? _lifecycleResetTimer;

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  @override
  void initState() {
    super.initState();
    selectedMRT = 0; // Ensure starts with no selection
    WidgetsBinding.instance.addObserver(this);

    // Initialize local loading state from BusData (may already be loaded)
    _isLoading = !busData.isDataLoaded;

    // Prime caches with current data snapshot
    _lastArrivalKAP = List<DateTime>.from(busData.arrivalTimeKAP);
    _lastArrivalCLE = List<DateTime>.from(busData.arrivalTimeCLE);
    _lastDepartureKAP = List<DateTime>.from(busData.departureTimeKAP);
    _lastDepartureCLE = List<DateTime>.from(busData.departureTimeCLE);

    // One-shot load in case BusData hasn't loaded yet
    busData.loadData();

    // Start BusData polling for morning screen so it updates independently
    // Adds a guard in case startPolling is already running or not implemented
    try {
      // Start polling bus data (adjust interval if desired)
      busData.startPolling(interval: const Duration(seconds: 30));
    } catch (_) {
      // If BusData doesn't implement startPolling or throws, ignore and rely on loadData()
    }

    // Listen for BusData updates so arrival/departure times refresh automatically
    _busDataListener = () {
      if (!mounted) return;

      // Detect whether BusData reports loaded
      final wasLoading = _isLoading;
      final nowLoaded = busData.isDataLoaded;
      bool changed = false;

      // Compare each list for additions/removals or content changes
      if (!_listsEqual(_lastArrivalKAP, busData.arrivalTimeKAP)) {
        _lastArrivalKAP = List<DateTime>.from(busData.arrivalTimeKAP);
        changed = true;
      }
      if (!_listsEqual(_lastArrivalCLE, busData.arrivalTimeCLE)) {
        _lastArrivalCLE = List<DateTime>.from(busData.arrivalTimeCLE);
        changed = true;
      }
      if (!_listsEqual(_lastDepartureKAP, busData.departureTimeKAP)) {
        _lastDepartureKAP = List<DateTime>.from(busData.departureTimeKAP);
        changed = true;
      }
      if (!_listsEqual(_lastDepartureCLE, busData.departureTimeCLE)) {
        _lastDepartureCLE = List<DateTime>.from(busData.departureTimeCLE);
        changed = true;
      }

      // If selectedBox refers to trips that no longer exist, deselect and notify parent
      if (selectedBox == 1) {
        final maxIndex = busData.arrivalTimeKAP.length;
        // if no trips left for this MRT, deselect
        if (maxIndex == 0 && selectedBox != 0) {
          selectedBox = 0;
          selectedMRT = 0;
          widget.updateSelectedBox(selectedBox);
          changed = true;
        }
      } else if (selectedBox == 2) {
        final maxIndex = busData.arrivalTimeCLE.length;
        if (maxIndex == 0 && selectedBox != 0) {
          selectedBox = 0;
          selectedMRT = 0;
          widget.updateSelectedBox(selectedBox);
          changed = true;
        }
      }

      // Update loading state and trigger rebuild only if something changed
      if (wasLoading != !nowLoaded) changed = true;

      if (changed) {
        setState(() {
          _isLoading = !busData.isDataLoaded;
        });
      }
    };
    busData.addListener(_busDataListener);
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
    WidgetsBinding.instance.removeObserver(this);
    busData.removeListener(_busDataListener);
    // Stop BusData polling when morning screen is disposed
    try {
      busData.stopPolling();
    } catch (e, st) {
      if (kDebugMode) {
        print("Error stopping polling: $e\n$st");
      }
    }
    // stop polling when screen disposed

    _inactivityStopTimer?.cancel();
    _inactivityStopTimer = null;
    _lifecycleResetTimer?.cancel();
    _lifecycleResetTimer = null;
    // cancel all timers when disposed

    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to check if app is used in foreground or open in background
  // (or is reopened from the background)

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the state is just a transient "inactive", ignore it entirely here.
    // Instead rely on hidden/paused as the true "background" indicators.
    switch (state) {
      case AppLifecycleState.hidden:
        // The app became not visible; schedule a delayed stop so we tolerate quick returns.
        if (kDebugMode) {
          print('Lifecycle hidden: scheduling delayed stop of polling');
        }
        _scheduleInactivityStop();
        // record the transition for later comparison
        _previousAppLifecycleState = state;
        break;

      case AppLifecycleState.paused:
        // Paused on many platforms is the real background; stop immediately (or you can delay).
        if (kDebugMode) {
          print('Lifecycle paused: stopping polling immediately (background)');
        }
        _cancelInactivityStopTimer();
        try {
          busData.stopPolling();
        } catch (e, st) {
          if (kDebugMode) print("Error stopping polling on paused: $e\n$st");
        }
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
            print(
              'Resumed after real background; restarting polling and refreshing',
            );
          }
          // Mark and restart polling safely; _restartPolling must be idempotent

          try {
            busData.startPolling(interval: const Duration(seconds: 30));
          } catch (e, st) {
            if (kDebugMode) {
              print("Error restarting polling on resume: $e\n$st");
            }
          }

          // Force immediate data refresh
          try {
            busData.loadData();
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
          print('Lifecycle detached: stopping polling and clearing guards');
        }
        _cancelInactivityStopTimer();
        try {
          busData.stopPolling();
        } catch (e, st) {
          if (kDebugMode) print("Error stopping polling on detached: $e\n$st");
        }
        _previousAppLifecycleState = state;
        _lastBackgroundAt = null;
        _lifecycleResetTimer?.cancel();
        _lifecycleResetTimer = null;
        break;
    }
  }

  void _scheduleInactivityStop() {
    if (_inactivityStopTimer?.isActive == true) {
      if (kDebugMode) print('Inactivity stop already scheduled; leaving it.');
      return;
    }

    _inactivityStopTimer = Timer(_inactivityStopDelay, () {
      _inactivityStopTimer = null;
      if (kDebugMode) print('Inactivity delay expired; stopping polling now');
      try {
        busData.stopPolling();
      } catch (e, st) {
        if (kDebugMode) {
          print("Error stopping polling after inactivity delay: $e\n$st");
        }
      }
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

  ///////////////////////////////////////////////////////////////
  // helper to compare DateTime lists
  bool _listsEqual(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////
  // So the corresponding path, information and visual box can be loaded

  void updateSelectedBox(int box) {
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
        print('Printing selectedBox = $selectedBox');
      }
    });
    widget.updateSelectedBox(selectedBox);
  }

  ///////////////////////////////////////////////////////////////
  // everything that is shown in the screen if morning and open

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('morning_screen built');
    }
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: fontSizeMiniText),

          ///////////////////////////////////////////////////////////////
          // The two buttons KAP and CLE
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(1),
                  child: BoxMRT(
                    box: selectedBox,
                    mrt: 'KAP',
                    fontSizeText: fontSizeText,
                    fontSizeHeading: fontSizeHeading,
                  ),
                ),
              ),
              SizedBox(width: fontSizeMiniText),
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(2),
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
        ),

        ///////////////////////////////////////////////////////////////
        // Shows bus arrival times, depending on selected MRT Station
        SizedBox(height: fontSizeText),
        if (_isLoading && selectedBox != 0)
          // Preserve existing UX: when BusData not ready, don't show ETAs
          const LoadingScreen()
        else if (selectedBox != 0)
          GetMorningETA(
            selectedBox == 1 ? busData.arrivalTimeKAP : busData.arrivalTimeCLE,
          ),
      ],
    );
  }
}
