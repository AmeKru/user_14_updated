import 'package:flutter/material.dart';

import '../data/global.dart';
import '../services/shared_preference.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Settings page ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Settings class
// used for settings page, at the moment only functionality is to toggle DarkMode

class Settings extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;

  const Settings({super.key, required this.onThemeChanged});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  ////////////////////////////////////////////////////////////////////////////////
  // initState

  @override
  void initState() {
    super.initState();
  }

  ////////////////////////////////////////////////////////////////////////////////
  // set sizes at start

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  ////////////////////////////////////////////////////////////////////////////////
  // To switch from Light to Dark Mode and vice versa

  void toggleTheme(bool value) {
    if (!mounted) return;
    setState(() {
      // sets state when called to update complete UI at once
      isDarkMode = value;
    });
    widget.onThemeChanged(value); // tells parent to also do the same
    // saves the value so that when app is reopened, will remember settings
    final SharedPreferenceService prefsService = SharedPreferenceService();
    prefsService.saveDarkMode(isDarkMode);
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Page Layout

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: fontSizeHeading * 2,
        iconTheme: IconThemeData(
          color: isDarkMode
              ? Colors.green[300]
              : Colors.white, // Arrow back color
          size: fontSizeText,
        ),
        title: Text(
          maxLines: 1, //  limits to 1 lines
          overflow: TextOverflow.ellipsis, // clips text if not fitting
          'Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.green[300] : Colors.white,
            fontSize: fontSizeHeading,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Color(0xff014689),
        centerTitle: true,
      ),
      backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
      body: Padding(
        padding: EdgeInsets.all(fontSizeHeading),
        child: SafeArea(
          right: true,
          left: true,
          top: true,
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Text
                    Flexible(
                      child: Text(
                        'Light Mode',
                        maxLines: 1, //  limits to 1 lines
                        overflow:
                            TextOverflow.ellipsis, // clips text if not fitting
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.blueGrey[100]
                              : Colors.black,
                          fontFamily: 'Roboto',
                          fontSize: fontSizeText,
                          fontWeight: isDarkMode
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ),

                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: fontSizeHeading * 5.5,
                          height: fontSizeHeading * 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Sun icon for no Dark Mode, either filled in or not
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Icon(
                                    isDarkMode
                                        ? Icons.wb_sunny_outlined
                                        : Icons.wb_sunny,
                                    color: isDarkMode
                                        ? Colors.blueGrey[100]
                                        : Colors.black,
                                    size: fontSizeText * 1.5,
                                  ),
                                ),
                              ),

                              // Spacing in between switch and icon
                              SizedBox(
                                width:
                                    TextSizing.fontSizeMiniText(context) * 0.8,
                              ),

                              // Switch to toggle Dark Mode On/Off
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    height: fontSizeHeading * 2,
                                    child: Switch(
                                      value: isDarkMode,
                                      onChanged: (value) {
                                        toggleTheme(value);
                                      },
                                      activeThumbColor:
                                          Colors.green, // Thumb color when ON
                                      activeTrackColor: Colors
                                          .green[200], // Track color when ON
                                      inactiveThumbColor:
                                          Colors.grey, // Thumb color when OFF
                                      inactiveTrackColor: Colors
                                          .grey[200], // Track color when OFF
                                    ),
                                  ),
                                ),
                              ),

                              // Spacing between switch and icon
                              SizedBox(
                                width:
                                    TextSizing.fontSizeMiniText(context) * 0.8,
                              ),

                              // Moon Icon for Dark Mode, either filled or not
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Icon(
                                    isDarkMode
                                        ? Icons.brightness_2
                                        : Icons.brightness_2_outlined,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[600],
                                    size: fontSizeText * 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Text
                    Flexible(
                      child: Text(
                        'Dark Mode',
                        maxLines: 1, //  limits to 1 lines
                        overflow:
                            TextOverflow.ellipsis, // clips text if not fitting
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.grey[600],
                          fontFamily: 'Roboto',
                          fontSize: fontSizeText,
                          fontWeight: isDarkMode
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
