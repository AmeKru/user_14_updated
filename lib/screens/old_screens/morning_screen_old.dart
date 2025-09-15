import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/get_morning_ETA.dart';
import 'package:user_14_updated/utils/styling_line_and_buttons.dart';

class MorningScreen extends StatefulWidget {
  final Function(int) updateSelectedBox;
  final bool isDarkMode;

  MorningScreen({required this.updateSelectedBox, required this.isDarkMode});

  @override
  _MorningScreenState createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  int selectedBox = 1;
  BusData _BusData = BusData();
  bool _isDarkMode = false;

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void updateSelectedBox(int box) {
    setState(() {
      selectedBox = box;
      print('Printing selectedbox = $box');
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
                  child: MRT_Box(
                    box: selectedBox,
                    MRT: 'KAP',
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
                  child: MRT_Box(
                    box: selectedBox,
                    MRT: 'CLE',
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        GetMorningETA(
          selectedBox == 1 ? _BusData.KAPArrivalTime : _BusData.CLEArrivalTime,
          isDarkMode: widget.isDarkMode,
        ),
      ],
    );
  }
}
