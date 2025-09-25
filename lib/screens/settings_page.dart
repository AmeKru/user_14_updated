import 'package:flutter/material.dart';
import 'package:user_14_updated/services/shared_preference.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

///////////////////////////////////////////////////////////////
// Settings Page

class Settings extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const Settings({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.isDarkMode;
  }

  ///////////////////////////////////////////////////////////////
  // To switch from Light to Dark Mode and vice versa

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
    widget.onThemeChanged(value);
    saveDarkMode(isDarkMode);
  }

  ///////////////////////////////////////////////////////////////
  // Page Layout

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: TextSizing.fontSizeHeading(context) * 2,
        iconTheme: IconThemeData(
          color: isDarkMode
              ? Colors.green[300]
              : Colors.white, // Arrow back color
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.green[300] : Colors.white,
            fontSize: TextSizing.fontSizeHeading(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Colors.green,
      ),
      backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
      body: Padding(
        padding: EdgeInsets.all(TextSizing.fontSizeHeading(context)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text
            Text(
              'Light Mode',
              style: TextStyle(
                color: isDarkMode ? Colors.blueGrey[100] : Colors.black,
                fontFamily: 'Roboto',
                fontSize: TextSizing.fontSizeText(context),
                fontWeight: isDarkMode ? FontWeight.normal : FontWeight.bold,
              ),
            ),

            // Spacing in between text and icon
            SizedBox(width: TextSizing.fontSizeMiniText(context)),

            // Sun icon for no Dark Mode, either filled in or not
            Icon(
              isDarkMode ? Icons.wb_sunny_outlined : Icons.wb_sunny,
              color: isDarkMode ? Colors.blueGrey[100] : Colors.black,
              size: TextSizing.fontSizeText(context) * 1.5,
            ),

            // Spacing in between switch and icon
            SizedBox(width: TextSizing.fontSizeMiniText(context)),

            // Switch to toggle Dark Mode On/Off
            Switch(
              value: isDarkMode,
              onChanged: (value) {
                toggleTheme(value);
              },
              activeThumbColor: Colors.green, // Thumb color when ON
              activeTrackColor: Colors.green[200], // Track color when ON
              inactiveThumbColor: Colors.grey, // Thumb color when OFF
              inactiveTrackColor: Colors.grey[200], // Track color when OFF
            ),

            // Spacing between switch and icon
            SizedBox(width: TextSizing.fontSizeMiniText(context)),

            // Moon Icon for Dark Mode, either filled or not
            Icon(
              isDarkMode ? Icons.brightness_2 : Icons.brightness_2_outlined,
              color: isDarkMode ? Colors.white : Colors.grey[600],
              size: TextSizing.fontSizeText(context) * 1.5,
            ),

            // Spacing between icon and text
            SizedBox(width: TextSizing.fontSizeMiniText(context)),

            // Text
            Text(
              'Dark Mode',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.grey[600],
                fontFamily: 'Roboto',
                fontSize: TextSizing.fontSizeText(context),
                fontWeight: isDarkMode ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
