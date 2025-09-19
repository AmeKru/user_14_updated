import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/get_morning_eta.dart';
import 'package:user_14_updated/utils/styling_line_and_buttons.dart';

class MorningScreen extends StatefulWidget {
  final Function(int) updateSelectedBox;
  final bool isDarkMode;

  const MorningScreen({
    super.key,
    required this.updateSelectedBox,
    required this.isDarkMode,
  });

  @override
  MorningScreenState createState() => MorningScreenState();
}

class MorningScreenState extends State<MorningScreen> {
  int selectedBox = 1;
  final BusData _busData = BusData();

  // Not used here
  // bool _isDarkMode = false;

  //void _toggleTheme(bool value) {
  //  setState(() {
  //    _isDarkMode = value;
  //  });
  // }

  void updateSelectedBox(int box) {
    setState(() {
      selectedBox = box;
      if (kDebugMode) {
        print('Printing selected box = $box');
      }
    });
    widget.updateSelectedBox(box);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    updateSelectedBox(1);
                    selectedMRT = 1;
                  }, // Update CLE
                  child: BoxMRT(
                    box: selectedBox,
                    mrt: 'KAP',
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),

              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    updateSelectedBox(2);
                    selectedMRT = 2;
                  }, // Update CLE
                  child: BoxMRT(
                    box: selectedBox,
                    mrt: 'CLE',
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        GetMorningETA(
          selectedBox == 1 ? _busData.arrivalTimeKAP : _busData.arrivalTimeCLE,
          isDarkMode: widget.isDarkMode,
        ),
      ],
    );
  }
}
