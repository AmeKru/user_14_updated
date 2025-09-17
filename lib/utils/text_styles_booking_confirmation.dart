import 'package:flutter/material.dart';

//////////////////////////////////////////////////////////////
// A reusable widget for displaying a label–value pair in a booking confirmation.
//
// Example:
// ┌───────────────────────────────┐
// │ Trip Number:      5           │
// └───────────────────────────────┘
//
// - [label] is the descriptive text (e.g., "Trip Number:").
// - [value] is the corresponding data (e.g., "5").
// - [size] controls the horizontal spacing between the label and the value
//   as a fraction of the screen width.

class BookingConfirmationText extends StatelessWidget {
  final String label; // The descriptive label text
  final String value; // The value to display next to the label
  final bool darkText; // if true then black text, else white text
  final double
  size; // Spacing between label and value (fraction of screen width)

  const BookingConfirmationText({
    super.key,
    required this.label,
    required this.value,
    required this.size,
    required this.darkText,
  });

  @override
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // ✅ Forces full horizontal width
      alignment: Alignment.center, // ✅ Aligns Row content to center
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        // ✅ Centers children inside Row
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          // Fixed-size box for the label
          SizedBox(
            height: 25, // Fixed height for alignment
            width: 100, // Fixed width so labels align vertically in a list
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 17,
                color: darkText ? Colors.blueGrey[900]! : Colors.white,
              ),
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * 0.3),

          // Fixed-size box for the value
          SizedBox(
            height: 25,
            width: 100, // Same width as label for clean alignment
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 17,
                color: darkText ? Colors.blueGrey[900]! : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
