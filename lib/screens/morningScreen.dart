import 'package:flutter/material.dart';
import 'package:user_14_updated/data/getData.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/getMorningETA.dart';
import 'package:user_14_updated/utils/styling.dart';

class Morning_Screen extends StatefulWidget {
  final Function(int) updateSelectedBox;

  Morning_Screen({required this.updateSelectedBox});

  @override
  _Morning_ScreenState createState() => _Morning_ScreenState();
}

class _Morning_ScreenState extends State<Morning_Screen> {
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
                  child: MRT_Box(box: selectedBox, MRT: 'KAP'),
                ),
              ),

              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    updateSelectedBox(2);
                    selectedMRT = 2;
                  }, // Update CLE
                  child: MRT_Box(box: selectedBox, MRT: 'CLE'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        GetMorningETA(
          selectedBox == 1 ? _BusData.KAPArrivalTime : _BusData.CLEArrivalTime,
        ),
      ],
    );
  }
}
