import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const Settings({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

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

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
    widget.onThemeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.green[300] : Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Colors.green[300],
      ),
      backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
      body: Padding(
        padding: EdgeInsets.fromLTRB(10, 10, 0, 10),
        child: Row(
          children: [
            Text(
              'Light Mode',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
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
            Text(
              'Dark Mode',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
