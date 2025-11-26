import 'package:flutter/foundation.dart';

DateTime? timeNow;
int startAfternoonETA = 14;
int startAfternoonService = 10;
int selectedMRT = 0;
ValueNotifier<int> busIndex = ValueNotifier<int>(
  0,
); // todo: adjust and make string instead, makes it easier
int busMaxCapacity = 30;
bool isDarkMode = false;
