import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

///////////////////////////////////////////////////////////////
// Information Page

class InformationPage extends StatefulWidget {
  final bool isDarkMode; // For layout

  const InformationPage({super.key, required this.isDarkMode});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  BusData busData = BusData();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await busData.loadData();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      ///////////////////////////////////////////////////////////////
      // Top Bar
      appBar: AppBar(
        toolbarHeight: TextSizing.fontSizeHeading(context) * 2,
        // Arrow back
        iconTheme: IconThemeData(
          color: widget.isDarkMode
              ? Colors.cyan[200]
              : Colors.white, // Arrow back color
        ),
        backgroundColor: widget.isDarkMode ? Colors.blueGrey[800] : Colors.cyan,
        title: Text(
          'Information',
          style: TextStyle(
            fontSize: TextSizing.fontSizeHeading(context),
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.cyan[200] : Colors.white,
          ),
        ),
      ),

      ///////////////////////////////////////////////////////////////
      // Body of screen
      body: Container(
        color: widget.isDarkMode ? Colors.blueGrey[900] : Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(TextSizing.fontSizeText(context)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: TextSizing.fontSizeMiniText(context)),
                      Text(
                        'Morning Schedule',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: TextSizing.fontSizeHeading(context),
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      SizedBox(
                        height: TextSizing.fontSizeHeading(context) * 1.2,
                      ),

                      _buildScheduleSection(
                        TextSizing.isTablet(context)
                            ? 'King Albert Park MRT Station to NP Campus'
                            : 'KAP MRT Station to NP Campus',
                        busData.arrivalTimeKAP,
                        2,
                      ),
                      SizedBox(height: TextSizing.fontSizeText(context) * 2),
                      _buildScheduleSection(
                        TextSizing.isTablet(context)
                            ? 'Clementi MRT Station (CLE) to NP Campus'
                            : 'CLE MRT Station to NP Campus',
                        busData.arrivalTimeCLE,
                        1,
                      ),

                      SizedBox(height: TextSizing.fontSizeText(context) * 3),
                      Text(
                        'Afternoon Schedule',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: TextSizing.fontSizeHeading(context),
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      Text(
                        '(Bus Departure Times shown here refer to Bus Stop ENT)',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: TextSizing.fontSizeMiniText(context),
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.blueGrey[100]
                              : Colors.black,
                        ),
                      ),
                      SizedBox(
                        height: TextSizing.fontSizeHeading(context) * 1.2,
                      ),

                      _buildScheduleSection(
                        TextSizing.isTablet(context)
                            ? 'NP Campus to King Albert Park MRT Station (KAP)'
                            : 'NP Campus to KAP MRT Station',
                        busData.departureTimeKAP,
                        2,
                      ),
                      SizedBox(height: TextSizing.fontSizeText(context) * 2),
                      _buildScheduleSection(
                        TextSizing.isTablet(context)
                            ? 'NP Campus to Clementi MRT Station (CLE)'
                            : 'NP Campus to CLE MRT Station',
                        busData.departureTimeCLE,
                        1,
                      ),
                      SizedBox(height: TextSizing.fontSizeText(context) * 3),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  ///////////////////////////////////////////////////////////////
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
          style: TextStyle(
            fontSize: TextSizing.fontSizeText(context),
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: TextSizing.fontSizeText(context)),
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
            width: TextSizing.fontSizeText(context) * 0.1,
            color: widget.isDarkMode ? Colors.blueGrey[900]! : Colors.white,
          ),

          children: _buildTableRows(times, columns),
        ),
      ],
    );
  }

  ///////////////////////////////////////////////////////////////
  // Combines the table Rows

  List<TableRow> _buildTableRows(List<DateTime> times, int columns) {
    List<TableRow> rows = [];

    if (columns == 2) {
      // Header row
      rows.add(
        _buildTableRow([
          'Trip',
          TextSizing.isTablet(context) ? 'Bus A Departure Time' : 'Bus A',
          'Trip',
          TextSizing.isTablet(context) ? 'Bus B Departure Time' : 'Bus B',
        ], 0),
      );

      for (int i = 0; i < times.length; i += 2) {
        rows.add(
          _buildTableRow([
            (i + 1).toString(),
            _formatTime(times[i]),
            if (i + 1 < times.length) (i + 2).toString() else '',
            if (i + 1 < times.length) _formatTime(times[i + 1]) else '',
          ], (i ~/ 2) + 1), // row index (1-based after header)
        );
      }
    } else if (columns == 1) {
      rows.add(
        _buildTableRow([
          'Trip',
          TextSizing.isTablet(context) ? 'Bus A Departure Time' : 'Bus A',
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

  ///////////////////////////////////////////////////////////////
  // so time is in the format hh:mm

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  ///////////////////////////////////////////////////////////////
  // Returns one row with Trip Nr and Time

  TableRow _buildTableRow(List<String> data, int rowIndex) {
    return TableRow(
      children: List.generate(data.length, (colIndex) {
        // Decide background color
        Color bgColor;
        if (rowIndex == 0) {
          // First row (header)
          bgColor = widget.isDarkMode ? Colors.blueGrey[800]! : Colors.cyan;
        } else {
          // Column-based coloring
          bgColor = (colIndex % 2 == 0)
              ? (widget.isDarkMode ? Colors.blueGrey[700]! : Colors.cyan[100]!)
              : (widget.isDarkMode ? Colors.blueGrey[600]! : Colors.cyan[50]!);
        }

        return Container(
          color: bgColor,
          padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
          child: Text(
            maxLines: 1, //  limits to 1 lines (optional)
            overflow: TextOverflow.clip, // clips text if not fitting
            data[colIndex],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,

              fontSize: TextSizing.fontSizeText(context),
              color:
                  (colIndex % 2 == 0 && widget.isDarkMode ||
                      !widget.isDarkMode && rowIndex == 0)
                  ? (widget.isDarkMode ? Colors.cyan[200] : Colors.white)
                  : (widget.isDarkMode ? Colors.white : Colors.black),
            ),
          ),
        );
      }),
    );
  }
}
