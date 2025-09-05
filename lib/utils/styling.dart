import 'package:flutter/material.dart';

class DrawLine extends StatelessWidget {
  const DrawLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 1,
          color: Colors.grey,
        ),
        SizedBox(height: 10),
      ],
    );
  }
}

class MRT_Box extends StatelessWidget {
  final int box;
  final String MRT;

  const MRT_Box({required this.box, required this.MRT});

  @override
  Widget build(BuildContext context) {
    int chosen = MRT == 'KAP' ? 1 : 2;

    return AnimatedContainer(
      duration: Duration(milliseconds: 0),
      height: box == chosen ? 70 : 40,
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          color: box == chosen ? Colors.blueAccent : Colors.grey,
          child: Center(
            child: Text(
              MRT,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
