import 'package:flutter/foundation.dart';

// global variables, with values that can be changed
DateTime? timeNow;
int selectedMRT = 0;
bool isDarkMode = false;
ValueNotifier<int> busIndex = ValueNotifier<int>(0);

// global const variables
const int busMaxCapacity = 30;
const int startAfternoonETA = 14;
const int startAfternoonService = 11;
