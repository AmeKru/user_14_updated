import 'package:flutter/material.dart';

//////////////////////////////////////////////////////////////
// Returns a [Color] for a map marker based on:
// - The marker's name (`markerName`)
// - The current value (`currentValue`)
// - Whether dark mode is enabled (`darkMode`)
//
// Certain marker names combined with specific `currentValue`s
// will be highlighted in a different colour

Color getMarkerColor(String markerName, int currentValue, bool darkMode) {
  if (markerName == "ENT" && currentValue == 2) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "B23" && currentValue == 3) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "SPH" && currentValue == 4) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "SIT" && currentValue == 5) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "B44" && currentValue == 6) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "B37" && currentValue == 7) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "MAP" && currentValue == 8) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "HSC" && currentValue == 9) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "LCT" && currentValue == 10) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  } else if (markerName == "B72" && currentValue == 11) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[900]!);
  }

  if (darkMode == true) {
    return Colors.cyanAccent[100]!;
  }
  return Color(0xff002345);
}

Color getBusMarkerColor(String busNumber, int selectedBox, bool darkMode) {
  if (darkMode == true) {
    return Color(0xfffeb041);
  }
  return Colors.pink[600]!;
}
