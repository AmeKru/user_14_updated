import 'dart:async';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_14_updated/amplifyconfiguration.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/data/global.dart';
import 'package:user_14_updated/models/model_provider.dart';
import 'package:user_14_updated/services/booking_confirmation.dart';
import 'package:user_14_updated/services/booking_service.dart';
import 'package:user_14_updated/services/shared_preference.dart';
import 'package:user_14_updated/utils/styling_line_and_buttons.dart';
import 'package:user_14_updated/utils/text_styles_booking_confirmation.dart';
import 'package:uuid/uuid.dart';

class AfternoonScreen extends StatefulWidget {
  final Function(int) updateSelectedBox;
  static int eveningService = 15;
  final bool isDarkMode;

  const AfternoonScreen({
    super.key,
    required this.updateSelectedBox,
    required this.isDarkMode,
  });

  @override
  AfternoonScreenState createState() => AfternoonScreenState();
}

class AfternoonScreenState extends State<AfternoonScreen> {
  int selectedBox = 0; // Default to no selection
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;
  bool confirmationPressed = false;
  DateTime currentTime = DateTime.now();
  String? bookingID;
  String selectedBusStop = '';
  BusData busData = BusData();
  List<DateTime> departureTimeKAP = [];
  List<DateTime> departureTimeCLE = [];
  int eveningService = 9;
  SharedPreferenceService prefsService = SharedPreferenceService();
  Future<Map<String, dynamic>?>? futureBookingData;
  bool _showBookingService = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _configureAmplify();
    futureBookingData = prefsService.getBookingData();
    Future.delayed(Duration(seconds: 15), () {
      setState(() {
        _showBookingService = false;
      });
    });
    if (kDebugMode) {
      print('Printing BusStop: ${busData.busStop}');
    }
  }

  Future<Map<String, dynamic>?> loadBookingData() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedBox = prefs.getInt('selectedBox');
    final bookedTripIndexKAP = prefs.getInt('bookedTripIndexKAP');
    final bookedTripIndexCLE = prefs.getInt('bookedTripIndexCLE');
    final busStop = prefs.getString('busStop');

    if (selectedBox != null) {
      return {
        'selectedBox': selectedBox,
        'bookedTripIndexKAP': bookedTripIndexKAP,
        'bookedTripIndexCLE': bookedTripIndexCLE,
        'busStop': busStop,
      };
    }
    return null; // No booking data
  }

  void _configureAmplify() async {
    final provider = ModelProvider();
    final amplifyApi = AmplifyAPI(
      options: APIPluginOptions(modelProvider: provider),
    );
    final dataStorePlugin = AmplifyDataStore(modelProvider: provider);

    Amplify.addPlugin(dataStorePlugin);
    Amplify.addPlugin(amplifyApi);
    Amplify.configure(amplifyconfig);

    if (kDebugMode) {
      print('Amplify configured');
    }
  }

  Future<void> create(String mrtStation, int tripNo, String busStop) async {
    try {
      final model = BOOKINGDETAILS5(
        id: Uuid().v4(),
        MRTStation: mrtStation,
        TripNo: tripNo,
        BusStop: busStop,
      );

      final request = ModelMutations.create(model);
      final response = await Amplify.API.mutate(request: request).response;

      final createdBOOKINGDETAILS5 = response.data;
      if (createdBOOKINGDETAILS5 == null) {
        safePrint('errors: ${response.errors}');
        return;
      }

      String id = createdBOOKINGDETAILS5.id;
      setState(() {
        bookingID = id;
      });
      safePrint('Mutation result: $bookingID');
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }

    mrtStation == 'KAP' ? countKAP(tripNo, busStop) : countCLE(tripNo, busStop);
  }

  Future<int?> countBooking(String mrt, int tripNo) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq(mrt)
            .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo)),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        if (kDebugMode) {
          print('$count');
        }
      } else {
        count = 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$e');
      }
    }
    return count;
  }

  Future<BOOKINGDETAILS5?> searchInstance(
    String mrt,
    int tripNo,
    String busStop,
  ) async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: (BOOKINGDETAILS5.MRTSTATION
          .eq(mrt)
          .and(
            BOOKINGDETAILS5.TRIPNO
                .eq(tripNo)
                .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
          )),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;

    // Debugging: Print out the fetched data
    if (data != null) {
      if (kDebugMode) {
        print('Booking found: $data');
      }
    } else {
      if (kDebugMode) {
        print('No booking found');
      }
    }
    return data;
  }

  Future<void> minus(String mrt, int tripNo, String busStop) async {
    if (kDebugMode) {
      print('Getting in Minus function');
    }
    final BOOKINGDETAILS5? bookingToDelete = await searchInstance(
      mrt,
      tripNo,
      busStop,
    );
    if (bookingToDelete != null) {
      //final request = ModelMutations.delete(bookingToDelete);
      //final response = await Amplify.API.mutate(request: request).response;
      if (bookingToDelete.MRTStation == 'KAP') {
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      } else {
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
      }
    } else {
      if (kDebugMode) {
        print('No booking deleted');
      }
    }
  }

  Future<BOOKINGDETAILS5?> readByID() async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.ID.eq(bookingID),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<void> delete() async {
    final BOOKINGDETAILS5? bookingToDelete = await readByID();
    if (bookingToDelete != null) {
      //final request = ModelMutations.delete(bookingToDelete);
      //final response = await Amplify.API.mutate(request: request).response;
      if (bookingToDelete.MRTStation == 'KAP') {
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      } else {
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
      }
    } else {
      if (kDebugMode) {
        print('No booking found with ID: $bookingID');
      }
    }
  }

  Future<void> countCLE(int tripNo, String busStop) async {
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLEAfternoon.classType,
      where: CLEAfternoon.TRIPNO
          .eq(tripNo)
          .and(CLEAfternoon.BUSSTOP.eq(busStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    if (kDebugMode) {
      print('Row found');
    }

    // If data1 != null delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION
          .eq('CLE')
          .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    final int count = data2?.length ?? 0;
    if (kDebugMode) {
      print('$count');
    }

    // Create the row if count is greater than 0
    if (count > 0) {
      final model = CLEAfternoon(
        BusStop: busStop,
        TripNo: tripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      await Amplify.API.mutate(request: request4).response;
    }
  }

  Future<void> countKAP(int tripNo, String busStop) async {
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAPAfternoon.classType,
      where: KAPAfternoon.TRIPNO
          .eq(tripNo)
          .and(KAPAfternoon.BUSSTOP.eq(busStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    if (kDebugMode) {
      print('Row found');
    }

    // If data1 != null delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION
          .eq('KAP')
          .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    final int count = data2?.length ?? 0;
    if (kDebugMode) {
      print('$count');
    }

    // Create the row if count is greater than 0
    if (count > 0) {
      final model = KAPAfternoon(
        BusStop: busStop,
        TripNo: tripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      await Amplify.API.mutate(request: request4).response;
    }
  }

  void showBusStopSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: Colors.cyan[50],
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 5),
                Text(
                  'Choose bus stop: ',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: busData.busStop.length - 2,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: ListTile(
                          title: Text(
                            busData.busStop[index + 2],
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedBusStop = busData.busStop[index + 2];
                              if (kDebugMode) {
                                print("selectedBusStop = $selectedBusStop");
                              }
                              busIndex = index + 2;
                              if (kDebugMode) {
                                print("bus index = {busIndex}");
                              }
                            });
                            // Handle bus stop selection here
                            Navigator.pop(context); // Close the bottom sheet
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void updateSelectedBox(int box) {
    if (!confirmationPressed) {
      setState(() {
        selectedBox = box;
      });
      widget.updateSelectedBox(box);
    }
  }

  void updateBookingStatusKAP(int index, bool newValue) {
    setState(() {
      if (confirmationPressed) {
        // If confirmation is pressed, allow changing selection
        confirmationPressed = false;
      } else {
        if (newValue) {
          // If the trip is selected, update the booked trip index
          bookedTripIndexKAP = index;
        } else {
          // If the trip is deselected, reset the booked trip index if it matches
          if (bookedTripIndexKAP == index) {
            bookedTripIndexKAP = null;
          }
        }
      }
    });
  }

  void updateBookingStatusCLE(int index, bool newValue) {
    setState(() {
      if (confirmationPressed) {
        // If confirmation is pressed, allow changing selection
        confirmationPressed = false;
      } else {
        if (newValue) {
          // If the trip is selected, update the booked trip index
          bookedTripIndexCLE = index;
        } else {
          // If the trip is deselected, reset the booked trip index if it matches
          if (bookedTripIndexCLE == index) {
            bookedTripIndexCLE = null;
          }
        }
      }
    });
  }

  List<DateTime> getDepartureTimes() {
    if (selectedBox == 1) {
      return busData.departureTimeKAP;
    } else {
      return busData.departureTimeCLE;
    }
  }

  String formatTime(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void showBookingConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 2),
                  Text(
                    'Booking Confirmed!',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Thank you for booking with us. Your booking has been confirmed',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                BookingConfirmationText(
                  label: 'Trip Number: ',
                  value:
                      '${selectedBox == 1 ? bookedTripIndexKAP! + 1 : bookedTripIndexCLE! + 1}',
                  // size: 0.15,
                  size: 0.30,
                  darkText: true,
                ),
                BookingConfirmationText(
                  label: 'Time: ',
                  value: formatTime(
                    getDepartureTimes()[selectedBox == 1
                        ? bookedTripIndexKAP!
                        : bookedTripIndexCLE!],
                  ),
                  // size: 0.31,
                  size: 0.30,
                  darkText: true,
                ),
                BookingConfirmationText(
                  label: 'Station: ',
                  value: selectedBox == 1 ? 'KAP' : 'CLE',
                  // size: 0.26,
                  size: 0.30,
                  darkText: true,
                ),
                BookingConfirmationText(
                  label: 'Bus Stop: ',
                  value: selectedBusStop,
                  // size: 0.23,
                  size: 0.30,
                  darkText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String selectedStation = selectedBox == 1 ? 'KAP' : 'CLE';
    Color darkText = widget.isDarkMode ? Colors.white : Colors.black;

    return FutureBuilder<Map<String, dynamic>?>(
      future: futureBookingData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error loading data')));
        } else if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          selectedBox = data['selectedBox'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Select MRT:',
                  style: TextStyle(
                    color: darkText,
                    //color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            updateSelectedBox(1);
                          });
                        },
                        child: BoxMRT(
                          box: selectedBox,
                          mrt: 'KAP',
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            updateSelectedBox(2);
                          });
                        },
                        child: BoxMRT(
                          box: selectedBox,
                          mrt: 'CLE',
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 5),
              _showBookingService
                  ? BookingService(
                      departureTimes: getDepartureTimes(),
                      eveningService: eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: busData.departureTimeKAP,
                      departureTimeCLE: busData.departureTimeCLE,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      updateBookingStatusKAP: updateBookingStatusKAP,
                      updateBookingStatusCLE: updateBookingStatusCLE,
                      confirmationPressed: true,
                      countBooking: countBooking,
                      isDarkMode: widget.isDarkMode,
                      showBusStopSelectionBottomSheet:
                          showBusStopSelectionBottomSheet,
                      selectedBusStop: selectedStation,
                      onPressedConfirm: () {
                        setState(() {
                          confirmationPressed = true;
                          create(
                            selectedStation,
                            selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1,
                            selectedBusStop,
                          );
                        });
                        showBookingConfirmationDialog(context);
                      },
                    )
                  : BookingConfirmation(
                      eveningService: eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: data['KAPDepartureTime'] ?? [],
                      departureTimeCLE: data['CLEDepartureTime'] ?? [],
                      bookedTripIndexKAP: data['bookedTripIndexKAP'],
                      bookedTripIndexCLE: data['bookedTripIndexCLE'],
                      getDepartureTimes: getDepartureTimes,
                      busStop: data['busStop'],
                      isDarkMode: widget.isDarkMode,
                      onCancel: () {
                        setState(() {
                          confirmationPressed = false;
                          if (kDebugMode) {
                            print('Cancelling the booking...');
                          }

                          if (data['bookedTripIndexCLE'] != null ||
                              data['bookedTripIndexKAP'] != null) {
                            final tripNo = selectedBox == 1
                                ? data['bookedTripIndexKAP'] + 1
                                : data['bookedTripIndexCLE'] + 1;
                            // Ensure all necessary variables are non-null
                            if (data['busStop'] != null) {
                              if (kDebugMode) {
                                print(
                                  'Calling Minus with: $selectedStation, $tripNo, ${data['busStop']}',
                                );
                              }
                              minus(selectedStation, tripNo, data['busStop']);
                            } else {
                              if (kDebugMode) {
                                print(
                                  'One or more values were null: Station: $selectedStation, BusStop: ${data['busStop']}, Box: $selectedBox, Index: $tripNo',
                                );
                              }
                            }
                          }
                        });
                        prefsService.clearBookingData();
                        futureBookingData = prefsService.getBookingData();
                      },
                    ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Select MRT:', style: TextStyle(color: darkText)),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          updateSelectedBox(1);
                        });
                      }, // Update CLE
                      child: BoxMRT(
                        box: selectedBox,
                        mrt: 'KAP',
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  ),

                  SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          updateSelectedBox(2);
                        });
                      }, // Update CLE
                      child: BoxMRT(
                        box: selectedBox,
                        mrt: 'CLE',
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 5),
            if (selectedBox != 0)
              //showBookingDetails
              confirmationPressed
                  ? BookingConfirmation(
                      eveningService: eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: departureTimeKAP,
                      departureTimeCLE: departureTimeCLE,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      getDepartureTimes: getDepartureTimes,
                      busStop: selectedBusStop,
                      isDarkMode: widget.isDarkMode,
                      onCancel: () {
                        setState(() {
                          confirmationPressed = false;
                          if (kDebugMode) {
                            print('Cancelling the booking...');
                          }

                          if (bookedTripIndexCLE != null ||
                              bookedTripIndexKAP != null) {
                            final tripNo = selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1;
                            // Ensure all necessary variables are non-null
                            if (kDebugMode) {
                              print(
                                'Calling Minus with: $selectedStation, $tripNo, $selectedBusStop',
                              );
                            }
                            minus(selectedStation, tripNo, selectedBusStop);
                          }
                        });
                        prefsService.clearBookingData();
                        futureBookingData = prefsService.getBookingData();
                      },
                    )
                  : BookingService(
                      departureTimes: getDepartureTimes(),
                      eveningService: eveningService,
                      selectedBox: selectedBox,
                      departureTimeKAP: busData.departureTimeKAP,
                      departureTimeCLE: busData.departureTimeCLE,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      updateBookingStatusKAP: updateBookingStatusKAP,
                      updateBookingStatusCLE: updateBookingStatusCLE,
                      confirmationPressed: confirmationPressed,
                      countBooking: countBooking,
                      isDarkMode: widget.isDarkMode,
                      showBusStopSelectionBottomSheet:
                          showBusStopSelectionBottomSheet,
                      selectedBusStop: selectedStation,
                      onPressedConfirm: () {
                        setState(() {
                          confirmationPressed = true;
                          //showBookingDetails = true;
                          create(
                            selectedStation,
                            selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1,
                            selectedBusStop,
                          );
                        });
                        showBookingConfirmationDialog(context);
                      },
                    ),
          ],
        );
      },
    );
  }
}
