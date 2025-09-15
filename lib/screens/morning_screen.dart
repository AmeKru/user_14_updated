import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/services/get_morning_ETA.dart';
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
  _MorningScreenState createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  int selectedBox = 0; // Default: no selection
  final BusData busData = BusData();

  @override
  void initState() {
    super.initState();
    selectedMRT = 0; // Ensure starts with no selection
  }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 5),
        Text(
          'Select MRT',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(1),
                  child: MRT_Box(
                    box: selectedBox,
                    MRT: 'KAP',
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(2),
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
        const SizedBox(height: 16),
        if (selectedBox != 0)
          GetMorningETA(
            selectedBox == 1 ? busData.KAPArrivalTime : busData.CLEArrivalTime,
            isDarkMode: widget.isDarkMode,
          ),
      ],
    );
  }
}
