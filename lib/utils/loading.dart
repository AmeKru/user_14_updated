import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
// flutter_spinkit provides a variety of animated loading indicators

//////////////////////////////////////////////////////////////
// A full-screen loading screen widget.
// Displays a centered spinning lines animation while the app is busy
// (e.g., during initial data load or a blocking operation).
// The background color changes depending on whether dark mode is enabled.

class LoadingScreen extends StatefulWidget {
  final bool isDarkMode; // Explicitly typed for clarity and safety
  const LoadingScreen({super.key, required this.isDarkMode});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set background color based on dark mode
      backgroundColor: widget.isDarkMode ? Colors.blueGrey[900] : Colors.white,

      // Center the loading animation in the middle of the screen
      body: Center(
        child: SpinKitSpinningLines(
          color: Colors.grey, // Spinner color
          size: 80.0, // Spinner size in logical pixels
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// Used when choosing a button, whilst the Bus list loads.
// This is a smaller, inline loading indicator rather than a full-screen one.
// A compact loading widget intended for use inside scrollable content.
// Typically shown while a list (e.g., bus list) is loading after a user action.
// The background color adapts to dark mode.

class LoadingScroll extends StatefulWidget {
  final bool isDarkMode; // Explicitly typed for consistency
  const LoadingScroll({super.key, required this.isDarkMode});

  @override
  State<LoadingScroll> createState() => _LoadingScrollState();
}

class _LoadingScrollState extends State<LoadingScroll> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add some vertical spacing above the loader
        const SizedBox(height: 10),

        // Container to hold the loading animation
        Container(
          // Background color changes based on dark mode
          color: widget.isDarkMode ? Colors.blueGrey[900] : Colors.white,

          // Center the loading animation horizontally
          child: Center(
            child: SpinKitWave(
              color: Colors.blueGrey[200], // Color of the wave animation
              size: 30.0, // Size of the animation
            ),
          ),
        ),
      ],
    );
  }
}
