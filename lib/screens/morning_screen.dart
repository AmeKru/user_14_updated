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
  int selectedBox = 0; // Default: no selection
  final BusData busData = BusData();

  @override
  void initState() {
    super.initState();
    selectedMRT = 0; // Ensure starts with no selection
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
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
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
                  child: BoxMRT(
                    box: selectedBox,
                    mrt: 'KAP',
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),
              SizedBox(width: TextSizing.fontSizeMiniText(context)),
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(2),
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

        ///////////////////////////////////////////////////////////////
        // Shows bus arrival times, depending on selected MRT Station
        SizedBox(height: TextSizing.fontSizeText(context)),
        if (selectedBox != 0)
          GetMorningETA(
            selectedBox == 1 ? busData.arrivalTimeKAP : busData.arrivalTimeCLE,
            isDarkMode: widget.isDarkMode,
          ),
      ],
    );
  }
}
