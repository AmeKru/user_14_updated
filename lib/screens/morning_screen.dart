import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/get_morning_eta.dart';
import 'package:user_14_updated/utils/styling_line_and_buttons.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

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
  void dispose() {
    // Clean up listener when widget is removed
    WidgetsBinding.instance.removeObserver(this);
    busData.removeListener(_busDataListener);
    // Stop BusData polling when morning screen is disposed
    try {
      busData.stopPolling();
    } catch (_) {
      // If BusData doesn't implement stopPolling, ignore
    }
    super.dispose();
  }

  // TODO: need to differentiate resume after inactive or paused as inactive happens very often
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restart polling immediately
      try {
        busData.startPolling(interval: const Duration(seconds: 30));
      } catch (_) {}

      // Force immediate data refresh
      busData.loadData();

      // Rebuild UI to reflect fresh data
      if (mounted) setState(() {});
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Stop polling to conserve resources
      try {
        busData.stopPolling();
      } catch (_) {}
    }
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
    return Column(
      children: [
        SizedBox(height: TextSizing.fontSizeMiniText(context)),
        Text(
          'Select MRT',
          maxLines: 1, //  limits to 1 lines
          overflow: TextOverflow.ellipsis, // clips text if not fitting
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: TextSizing.fontSizeText(context),
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        SizedBox(height: TextSizing.fontSizeMiniText(context)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: TextSizing.fontSizeMiniText(context),
          ),

          ///////////////////////////////////////////////////////////////
          // The two buttons KAP and CLE
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(1),
                  child: BoxMRT(box: selectedBox, mrt: 'KAP'),
                ),
              ),
              SizedBox(width: TextSizing.fontSizeMiniText(context)),
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(2),
                  child: BoxMRT(box: selectedBox, mrt: 'CLE'),
                ),
              ),
            ],
          ),
        ),

        ///////////////////////////////////////////////////////////////
        // Shows bus arrival times, depending on selected MRT Station
        SizedBox(height: TextSizing.fontSizeText(context)),
        if (_isLoading)
          // Preserve existing UX: when BusData not ready, don't show ETAs
          const SizedBox()
        else if (selectedBox != 0)
          GetMorningETA(
            selectedBox == 1 ? busData.arrivalTimeKAP : busData.arrivalTimeCLE,
          ),
      ],
    );
  }

  // helper to compare DateTime lists
  bool _listsEqual(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
