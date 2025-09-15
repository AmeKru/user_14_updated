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
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        SizedBox(width: MediaQuery.of(context).size.width * size * 0.1),
        // Fixed-size box for the label
        SizedBox(
          height: 25, // Fixed height for alignment
          width: 200, // Fixed width so labels align vertically in a list
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              color: darkText ? Colors.blueGrey[900]! : Colors.white,
            ),
          ),
        ),

        // Dynamic horizontal spacing between label and value
        SizedBox(width: MediaQuery.of(context).size.width * size * 0.5),

        // The value text
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            color: darkText ? Colors.blueGrey[900]! : Colors.white,
          ),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * size * 0.1),
      ],
    );
  }
}
