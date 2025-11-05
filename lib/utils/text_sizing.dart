import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class TextSizing {
  static late Size size;

  static void setSize(BuildContext context) {
    size = MediaQuery.of(context).size;
    return;
  }

  static bool isTabletOrLandscapeMode(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final landscapeMode =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return shortestSide >= 600 || landscapeMode;
  }

  static bool isLandscapeMode(BuildContext context) {
    final landscapeMode =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return landscapeMode;
  }

  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  static double shortestSide(BuildContext context) {
    return (size.width < size.height ? size.width : size.height) *
        2; // check if works better
  }

  static double fontSizeText(
    BuildContext context, {
    double iphoneFactor = 0.02,
    double androidFactor = 0.015,
    bool respectAccessibility = true,
  }) {
    final baseFactor = Platform.isAndroid ? androidFactor : iphoneFactor;
    double textFontSize = shortestSide(context) * baseFactor;

    if (respectAccessibility) {
      textFontSize = MediaQuery.of(context).textScaler.scale(textFontSize);
    }

    return textFontSize;
  }

  /////////////////////////////////////////////////////////////////////
  // Returns a bigger font size

  static double fontSizeHeading(BuildContext context) {
    double headingFontSize = fontSizeText(context) * 1.7;
    return headingFontSize;
  }

  /////////////////////////////////////////////////////////////////////
  // returns a smaller font size

  static double fontSizeMiniText(BuildContext context) {
    double miniFontSize = fontSizeText(context) * 0.6;
    return miniFontSize;
  }
}
