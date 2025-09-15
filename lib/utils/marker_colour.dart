import 'package:flutter/material.dart';

//////////////////////////////////////////////////////////////
// Returns a [Color] for a map marker based on:
// - The marker's name (`markerName`)
// - The current value (`currentValue`)
// - Whether dark mode is enabled (`darkMode`)
//
// Certain marker names combined with specific `currentValue`s
// will be highlighted in RED, if not then they are by default BLUE

Color getMarkerColor(String markerName, int currentValue, bool darkMode) {
  if (markerName == "ENT" && currentValue == 2) {
    return Colors.red;
  } else if (markerName == "B23" && currentValue == 3) {
    return Colors.red;
  } else if (markerName == "SPH" && currentValue == 4) {
    return Colors.red;
  } else if (markerName == "SIT" && currentValue == 5) {
    return Colors.red;
  } else if (markerName == "B44" && currentValue == 6) {
    return Colors.red;
  } else if (markerName == "B37" && currentValue == 7) {
    return Colors.red;
  } else if (markerName == "MAP" && currentValue == 8) {
    return Colors.red;
  } else if (markerName == "HSC" && currentValue == 9) {
    return Colors.red;
  } else if (markerName == "LCT" && currentValue == 10) {
    return Colors.red;
  } else if (markerName == "B72" && currentValue == 11) {
    return Colors.red;
  }

  if (darkMode == true) {
    return Colors.cyanAccent[100]!;
  }
  return Colors.blue[900]!;
}
