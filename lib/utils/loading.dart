import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoadingScreen extends StatefulWidget {
  final isDarkMode;
  const LoadingScreen({required this.isDarkMode});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: widget.isDarkMode ? Colors.lightBlue[900] : Colors.lightBlue[100],
        body: Center(
            child: SpinKitSpinningLines(
                color: Colors.white,
                size: 80.0
            )
        )
    );
  }
}

class LoadingScroll extends StatefulWidget {
  final bool isDarkMode;
  const LoadingScroll({required this.isDarkMode});

  @override
  State<LoadingScroll> createState() => _LoadingScrollState();
}

class _LoadingScrollState extends State<LoadingScroll> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        Container(
          color: widget.isDarkMode ? Colors.lightBlue[900] : Colors.lightBlue[100],
          child: Center(
            child: SpinKitWave(
                color: Colors.white,
                size: 30.0
            ),
          ),
        )
      ],
    );
  }
}

