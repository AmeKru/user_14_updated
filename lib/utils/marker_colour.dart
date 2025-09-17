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
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "B23" && currentValue == 3) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "SPH" && currentValue == 4) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "SIT" && currentValue == 5) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "B44" && currentValue == 6) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "B37" && currentValue == 7) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "MAP" && currentValue == 8) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "HSC" && currentValue == 9) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "LCT" && currentValue == 10) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  } else if (markerName == "B72" && currentValue == 11) {
    return (darkMode ? Colors.lightGreenAccent : Colors.pink[800]!);
  }

  if (darkMode == true) {
    return Colors.cyanAccent[100]!;
  }
  return Color(0xff002345);
}

// TODO: check which Bus goes on which route
Color getBusMarkerColor(String busNumber, int selectedBox, bool darkMode) {
  if (selectedBox == 1 && (busNumber == 'Bus1' || busNumber == 'Bus2')) {
    return (darkMode ? Color(0xfffeb041) : Colors.pink[700]!);
  } else if (selectedBox == 2 && busNumber == 'Bus3') {
    return (darkMode ? Color(0xfffeb041) : Colors.pink[700]!);
  }
  if (darkMode == true) {
    return Colors.cyanAccent[100]!;
  }
  return Color(0xff002345);
}
