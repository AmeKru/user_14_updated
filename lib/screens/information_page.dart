import 'package:flutter/material.dart';

import '../data/get_data.dart';
import '../data/global.dart';
import '../utils/loading.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Information Page ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// InformationPage class
// used for information page, shows the complete schedule of the bus trips offered

class InformationPage extends StatefulWidget {
  const InformationPage({super.key});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  // BusData singleton instance
  BusData busData = BusData();

  // Loading state for this page (driven by BusData)
  bool _isLoading = true;

  // Listener token for BusData ChangeNotifier
  late VoidCallback _busDataListener;

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  //////////////////////////////////////////////////////////////////////////////
  // initState
  @override
  void initState() {
    super.initState();

    // Initialize local loading state from BusData (may already be loaded)
    _isLoading = !busData.isDataLoaded;

    // One-shot load in case BusData hasn't loaded yet
    busData.loadData();

    // Listen for BusData updates and update local state accordingly
    _busDataListener = () {
      if (!mounted) return;
      setState(() {
        // reflect BusData's loaded flag; when false -> show loading
        _isLoading = !busData.isDataLoaded;
      });
    };
    busData.addListener(_busDataListener);
  }

  //////////////////////////////////////////////////////////////////////////////
  // to set variables at start
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  //////////////////////////////////////////////////////////////////////////////
  // remove listeners when this widget is trashed
  @override
  void dispose() {
    // Clean up listener when widget is removed
    busData.removeListener(_busDataListener);
    super.dispose();
  }

  /////////////////////////////////////////////////////////////////////////////
  // the information page

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top Bar
      appBar: AppBar(
        toolbarHeight: fontSizeHeading * 2,
        // Arrow back
        iconTheme: IconThemeData(
          color: isDarkMode
              ? Colors.cyan[200]
              : Colors.white, // Arrow back color
          size: fontSizeText,
        ),
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Color(0xff014689),
        title: Text(
          'Information',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSizeHeading,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.cyan[200] : Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      // Body of screen
      body: Container(
        color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          right: true,
          left: true,
          top: true,
          bottom: false,
          child: _isLoading
              ? Center(child: LoadingScreen())
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(fontSizeText),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: fontSizeMiniText),
                        Text(
                          'Morning Schedule',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: fontSizeHeading,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        SizedBox(height: fontSizeHeading * 1.2),

                        _buildScheduleSection(
                          TextSizing.isTabletOrLandscapeMode(context)
                              ? 'King Albert Park MRT Station (KAP)  to NP Campus'
                              : 'KAP MRT Station to NP Campus',
                          busData.morningTimesKAP,
                          2,
                        ),
                        SizedBox(height: fontSizeText * 2),
                        _buildScheduleSection(
                          TextSizing.isTabletOrLandscapeMode(context)
                              ? 'Clementi MRT Station (CLE) to NP Campus'
                              : 'CLE MRT Station to NP Campus',
                          busData.morningTimesCLE,
                          1,
                        ),

                        SizedBox(height: fontSizeText * 3),
                        Text(
                          textAlign: TextAlign.center,
                          softWrap: true,
                          'Afternoon Schedule',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: fontSizeHeading,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '(Bus Departure Times shown here refer to Bus Stop ENT)',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: fontSizeMiniText,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.blueGrey[100]
                                : Colors.black,
                          ),
                        ),
                        SizedBox(height: fontSizeHeading * 1.2),

                        _buildScheduleSection(
                          TextSizing.isTabletOrLandscapeMode(context)
                              ? 'NP Campus to King Albert Park MRT Station (KAP)'
                              : 'NP Campus to KAP MRT Station',
                          busData.afternoonTimesKAP,
                          2,
                        ),
                        SizedBox(height: fontSizeText * 2),
                        _buildScheduleSection(
                          TextSizing.isTabletOrLandscapeMode(context)
                              ? 'NP Campus to Clementi MRT Station (CLE)'
                              : 'NP Campus to CLE MRT Station',
                          busData.afternoonTimesCLE,
                          1,
                        ),
                        SizedBox(height: fontSizeText * 3),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Helpers for build ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Widget that returns Tables for Trip and departure time

  Widget _buildScheduleSection(
    String title,
    List<DateTime> times,
    int columns,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          softWrap: true,
          style: TextStyle(
            fontSize: fontSizeText,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),

        SizedBox(height: fontSizeText),
        Table(
          columnWidths: columns == 2
              ? {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(2),
                }
              : {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
          border: TableBorder.all(
            width: fontSizeText * 0.1,
            color: isDarkMode ? Colors.blueGrey[900]! : Colors.white,
          ),

          children: _buildTableRows(times, columns),
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // Combines the table Rows

  List<TableRow> _buildTableRows(List<DateTime> times, int columns) {
    List<TableRow> rows = [];

    if (columns == 2) {
      // Header row
      rows.add(
        _buildTableRow([
          'Trip',
          TextSizing.isLandscapeMode(context)
              ? 'Bus A Departure Time'
              : 'Bus A',
          'Trip',
          TextSizing.isLandscapeMode(context)
              ? 'Bus B Departure Time'
              : 'Bus B',
        ], 0),
      );

      for (int i = 0; i < times.length; i += 2) {
        rows.add(
          _buildTableRow([
            (i + 1).toString(),
            _formatTime(times[i]),
            if (i + 1 < times.length) (i + 2).toString() else '',
            if (i + 1 < times.length) _formatTime(times[i + 1]) else '',
          ], (i ~/ 2) + 1),
        );
      }
    } else if (columns == 1) {
      rows.add(
        _buildTableRow([
          'Trip',
          TextSizing.isLandscapeMode(context)
              ? 'Bus A Departure Time'
              : 'Bus A',
        ], 0),
      );

      for (int i = 0; i < times.length; i++) {
        rows.add(
          _buildTableRow([(i + 1).toString(), _formatTime(times[i])], i + 1),
        );
      }
    }

    return rows;
  }

  //////////////////////////////////////////////////////////////////////////////
  // so time is in the format hh:mm

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  //////////////////////////////////////////////////////////////////////////////
  // Returns one row with Trip Nr and Time

  TableRow _buildTableRow(List<String> data, int rowIndex) {
    return TableRow(
      children: List.generate(data.length, (colIndex) {
        // Decide background color
        Color bgColor;
        if (rowIndex == 0) {
          // First row (header)
          bgColor = isDarkMode ? Colors.blueGrey[800]! : Color(0xff014689);
        } else {
          // Column-based coloring
          bgColor = (colIndex % 2 == 0)
              ? (isDarkMode ? Colors.blueGrey[700]! : Colors.blue[100]!)
              : (isDarkMode ? Colors.blueGrey[600]! : Colors.blue[50]!);
        }

        return Container(
          color: bgColor,
          padding: EdgeInsets.all(fontSizeMiniText),
          child: Text(
            maxLines: 1, //  limits to 1 lines
            overflow: TextOverflow.ellipsis, // clips text if not fitting
            data[colIndex],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSizeText,
              color: (rowIndex == 0)
                  ? (isDarkMode ? Colors.cyan[200] : Colors.white)
                  : (isDarkMode ? Colors.white : Colors.black),
            ),
          ),
        );
      }),
    );
  }
}
