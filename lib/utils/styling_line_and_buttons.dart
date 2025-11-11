import 'package:flutter/material.dart';

import '../data/global.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- line ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// A simple horizontal divider with padding above and below
//
// This widget draws a thin grey line that spans 90% of the screen width
// with vertical spacing before and after it
// Useful for visually separating sections in the UI

class DrawLine extends StatelessWidget {
  final double fontSizeText;
  const DrawLine({super.key, required this.fontSizeText});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: fontSizeText), // Space above the line
        Container(
          width: MediaQuery.of(context).size.width * 0.8, // 90% of screen width
          height: fontSizeText * 0.05, // Thin line
          color: Colors.blueGrey[900], // black color
        ),
        SizedBox(height: fontSizeText), // Space below the line
      ],
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- button ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// This widget is used for the two buttons to select either KAP or CLE MRT station
//
// Displays the MRT station name ("KAP" or "CLE") inside a rounded container
// The appearance changes based on:
// - Whether this box is currently selected (`box` matches `chosen`)
// - Whether dark mode is enabled (`isDarkMode`)

class BoxMRT extends StatelessWidget {
  final int box; // The currently selected box index from parent
  final String mrt; // The MRT station name ("KAP" or "CLE")
  final double fontSizeText;
  final double fontSizeHeading;

  const BoxMRT({
    super.key,
    required this.box,
    required this.mrt,
    required this.fontSizeText,
    required this.fontSizeHeading,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the index number for this MRT station
    // KAP is assigned 1, CLE is assigned 2
    int chosen = mrt == 'KAP' ? 1 : 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 0), // No animation delay
      height: fontSizeHeading * 1.8, // Fixed height for the box
      curve: Curves.easeOutCubic, // Animation curve (if duration > 0)
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          fontSizeText * 0.6,
        ), // Rounded corners
        child: Container(
          // Background color changes based on selection and dark mode
          color: box == chosen
              ? (isDarkMode ? Colors.blueGrey[400] : const Color(0xff014689))
              : (isDarkMode ? Colors.blueGrey[800] : Colors.blue[100]),
          child: Center(
            child: Text(
              mrt, // Display the MRT station name
              style: box == chosen
                  // Selected style: white, larger, bold
                  ? TextStyle(
                      color: Colors.white,
                      fontSize: fontSizeHeading,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    )
                  // Unselected style: smaller, color depends on dark mode
                  : TextStyle(
                      color: isDarkMode
                          ? Colors.blueGrey[100]
                          : Colors.blueGrey[800],
                      fontSize: fontSizeHeading,
                      fontFamily: 'Roboto',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
