import 'package:flutter/foundation.dart';

DateTime? timeNow;
int startAfternoonETA = 14;
int startAfternoonService = 11;
int selectedMRT = 0;
ValueNotifier<int> busIndex = ValueNotifier<int>(0);
int busMaxCapacity = 30;
bool isDarkMode = false;
