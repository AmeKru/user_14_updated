import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  Future<LatLng?> getCurrentLocation() async {
    try {
      await Geolocator.checkPermission();
      await Geolocator.requestPermission();
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  void initCompass(Function(double) updateHeading) {
    FlutterCompass.events?.listen((CompassEvent event) {
      updateHeading(event.heading ?? 0.0);
    });
  }
}

class CompassPainter extends CustomPainter {
  final double direction;
  final double arcStartAngle;
  final double arcSweepAngle;

  CompassPainter({
    required this.direction,
    required this.arcStartAngle,
    required this.arcSweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 5;

    // Draw the blue arc indicating the direction
    Paint paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      _toRadians(arcStartAngle),
      _toRadians(arcSweepAngle),
      false,
      paint,
    );

    // Draw the arrow indicating the exact direction
    Paint arrowPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    double arrowLength = radius * 2.5;
    double arrowAngle = _toRadians(direction);
    Offset arrowBase = Offset(
      centerX + arrowLength * math.cos(arrowAngle),
      centerY + arrowLength * math.sin(arrowAngle),
    );

    double arrowTipLength = radius * 0.1;
    double arrowTipAngle = _toRadians(direction - 180);
    Offset arrowTip = Offset(
      centerX + arrowTipLength * math.cos(arrowTipAngle),
      centerY + arrowTipLength * math.sin(arrowTipAngle),
    );

    double arrowWidth = 10;
    canvas.drawLine(arrowBase, arrowTip, arrowPaint);
    canvas.drawCircle(arrowTip, arrowWidth / 2, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
