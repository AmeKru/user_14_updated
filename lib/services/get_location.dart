import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Get Location ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// location service class
// used for handling location and compass functionality

class LocationService {
  //////////////////////////////////////////////////////////////////////////////
  // Retrieves the current GPS location of the device as a [LatLng].
  //
  // - Requests location permission if not already granted.
  // - Uses high accuracy mode for better precision.
  // - Returns `null` if location retrieval fails.

  Future<LatLng?> getCurrentLocation() async {
    try {
      // Ensure permissions are checked and requested
      await Geolocator.checkPermission();
      await Geolocator.requestPermission();

      // Updated: Use LocationSettings instead of deprecated desiredAccuracy
      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high, // Same as old desiredAccuracy
        distanceFilter: 0, // Always report location changes
      );

      // Get current position with the specified settings
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      // Convert to LatLng for map usage
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      // if (kDebugMode) {
      //   print('Error getting current location: $e');
      // }
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Initializes the compass sensor and listens for heading changes.
  //
  // - [updateHeading] is a callback that receives the new heading in degrees.
  // - Heading is `0.0` if unavailable.

  void initCompass(Function(double) updateHeading) {
    FlutterCompass.events?.listen((CompassEvent event) {
      updateHeading(event.heading ?? 0.0);
    });
  }
}

////////////////////////////////////////////////////////////////////////////////
// A custom painter that draws a compass arc and an arrow indicating direction.
//
// - [direction]: The current heading in degrees.
// - [arcStartAngle]: The starting angle of the arc in degrees.
// - [arcSweepAngle]: The sweep (length) of the arc in degrees.

class CompassPainter extends CustomPainter {
  final double direction;
  final double arcStartAngle;
  final double arcSweepAngle;
  final double fontSizeText;
  BuildContext context;

  CompassPainter({
    required this.direction,
    required this.arcStartAngle,
    required this.arcSweepAngle,
    required this.fontSizeText,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate center and radius for the compass
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 5;

    // === Draw the blue arc indicating the direction range ===
    Paint paint = Paint()
      ..color = Colors.blue
          .withAlpha(128) // 128 out of 255 = 50% opacity
      ..strokeWidth = fontSizeText
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      _toRadians(arcStartAngle), // Convert start angle to radians
      _toRadians(arcSweepAngle), // Convert sweep angle to radians
      false,
      paint,
    );

    // === Draw the arrow indicating the exact heading ===
    Paint arrowPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = fontSizeText * 0.15
      ..style = PaintingStyle.fill;

    // Arrow base (far end) position
    double arrowLength = radius * 2.5;
    double arrowAngle = _toRadians(direction);
    Offset arrowBase = Offset(
      centerX + arrowLength * math.cos(arrowAngle),
      centerY + arrowLength * math.sin(arrowAngle),
    );

    // Arrow tip (near center) position
    double arrowTipLength = radius * 0.1;
    double arrowTipAngle = _toRadians(direction - 180);
    Offset arrowTip = Offset(
      centerX + arrowTipLength * math.cos(arrowTipAngle),
      centerY + arrowTipLength * math.sin(arrowTipAngle),
    );

    // Draw arrow line and tip circle
    double arrowWidth = fontSizeText * 0.6;
    canvas.drawLine(arrowBase, arrowTip, arrowPaint);
    canvas.drawCircle(arrowTip, arrowWidth / 2, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Always repaint when new data is available
    return true;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Converts degrees to radians for drawing calculations.

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
