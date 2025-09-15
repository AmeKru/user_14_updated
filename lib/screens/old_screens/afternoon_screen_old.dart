import 'dart:async';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
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

  AfternoonScreen({required this.updateSelectedBox, required this.isDarkMode});

  @override
  _AfternoonScreenState createState() => _AfternoonScreenState();
}

class _AfternoonScreenState extends State<AfternoonScreen> {
  int selectedBox = 0; // Default to no selection
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;
  bool confirmationPressed = false;
  DateTime currentTime = DateTime.now();
  String? BookingID;
  String selectedBusStop = '';
  BusData _BusData = BusData();
  List<DateTime> KAP_DT = [];
  List<DateTime> CLE_DT = [];
  int _eveningService = 9;
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
    print('Printing BusStop: ${_BusData.BusStop}');
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

    print('Amplify configured');
  }

  Future<void> create(String _MRTStation, int _TripNo, String _BusStop) async {
    try {
      final model = BOOKINGDETAILS5(
        id: Uuid().v4(),
        MRTStation: _MRTStation,
        TripNo: _TripNo,
        BusStop: _BusStop,
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
        BookingID = id;
      });
      safePrint('Mutation result: $BookingID');
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }

    _MRTStation == 'KAP'
        ? countKAP(_TripNo, _BusStop)
        : countCLE(_TripNo, _BusStop);
  }

  Future<int?> countBooking(String MRT, int TripNo) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq(MRT)
            .and(BOOKINGDETAILS5.TRIPNO.eq(TripNo)),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        print('$count');
      } else {
        count = 0;
      }
    } catch (e) {
      print('$e');
    }
    return count;
  }

  Future<BOOKINGDETAILS5?> Search_Instance(
    String MRT,
    int TripNo,
    String BusStop,
  ) async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: (BOOKINGDETAILS5.MRTSTATION
          .eq(MRT)
          .and(
            BOOKINGDETAILS5.TRIPNO
                .eq(TripNo)
                .and(BOOKINGDETAILS5.BUSSTOP.eq(BusStop)),
          )),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;

    // Debugging: Print out the fetched data
    if (data != null) {
      print('Booking found: $data');
    } else {
      print('No booking found');
    }
    return data;
  }

  Future<void> Minus(String _MRT, int _TripNo, String _BusStop) async {
    print('Getting in Minus function');
    final BOOKINGDETAILS5? bookingToDelete = await Search_Instance(
      _MRT,
      _TripNo,
      _BusStop,
    );
    if (bookingToDelete != null) {
      final request = ModelMutations.delete(bookingToDelete);
      final response = await Amplify.API.mutate(request: request).response;
      if (bookingToDelete.MRTStation == 'KAP')
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      else
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
    } else {
      print('No booking deleted');
    }
  }

  Future<BOOKINGDETAILS5?> readByID() async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.ID.eq(BookingID),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<void> delete() async {
    final BOOKINGDETAILS5? bookingToDelete = await readByID();
    if (bookingToDelete != null) {
      final request = ModelMutations.delete(bookingToDelete);
      final response = await Amplify.API.mutate(request: request).response;
      if (bookingToDelete.MRTStation == 'KAP') {
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      } else {
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
      }
    } else {
      print('No booking found with ID: $BookingID');
    }
  }

  Future<void> countCLE(int _TripNo, String _BusStop) async {
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLEAfternoon.classType,
      where: CLEAfternoon.TRIPNO
          .eq(_TripNo)
          .and(CLEAfternoon.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

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
          .and(BOOKINGDETAILS5.TRIPNO.eq(_TripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    final int count = data2?.length ?? 0;
    print('$count');

    // Create the row if count is greater than 0
    if (count > 0) {
      final model = CLEAfternoon(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      await Amplify.API.mutate(request: request4).response;
    }
  }

  Future<void> countKAP(int _TripNo, String _BusStop) async {
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAPAfternoon.classType,
      where: KAPAfternoon.TRIPNO
          .eq(_TripNo)
          .and(KAPAfternoon.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

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
          .and(BOOKINGDETAILS5.TRIPNO.eq(_TripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    final int count = data2?.length ?? 0;
    print('$count');

    // Create the row if count is greater than 0
    if (count > 0) {
      final model = KAPAfternoon(
        BusStop: _BusStop,
        TripNo: _TripNo,
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
                  itemCount: _BusData.BusStop.length - 2,
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
                            _BusData.BusStop[index + 2],
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedBusStop = _BusData.BusStop[index + 2];
                              print("selectedbusStop = ${selectedBusStop}");
                              busIndex = index + 2;
                              print("bus index = {busIndex}");
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
      return _BusData.KAPDepartureTime;
    } else {
      return _BusData.CLEDepartureTime;
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
                  value:
                      '${formatTime(getDepartureTimes()[selectedBox == 1 ? bookedTripIndexKAP! : bookedTripIndexCLE!])}',
                  // size: 0.31,
                  size: 0.30,
                  darkText: true,
                ),
                BookingConfirmationText(
                  label: 'Station: ',
                  value: '${selectedBox == 1 ? 'KAP' : 'CLE'}',
                  // size: 0.26,
                  size: 0.30,
                  darkText: true,
                ),
                BookingConfirmationText(
                  label: 'Bus Stop: ',
                  value: '$selectedBusStop',
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
                        child: MRT_Box(
                          box: selectedBox,
                          MRT: 'KAP',
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
                        child: MRT_Box(
                          box: selectedBox,
                          MRT: 'CLE',
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
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      KAPDepartureTime: _BusData.KAPDepartureTime,
                      CLEDepartureTime: _BusData.CLEDepartureTime,
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
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      KAPDepartureTime: data['KAPDepartureTime'] ?? [],
                      CLEDepartureTime: data['CLEDepartureTime'] ?? [],
                      bookedTripIndexKAP: data['bookedTripIndexKAP'],
                      bookedTripIndexCLE: data['bookedTripIndexCLE'],
                      getDepartureTimes: getDepartureTimes,
                      busStop: data['busStop'],
                      isDarkMode: widget.isDarkMode,
                      onCancel: () {
                        setState(() {
                          confirmationPressed = false;
                          print('Cancelling the booking...');

                          if (data['bookedTripIndexCLE'] != null ||
                              data['bookedTripIndexKAP'] != null) {
                            final tripNo = selectedBox == 1
                                ? data['bookedTripIndexKAP'] + 1
                                : data['bookedTripIndexCLE'] + 1;
                            // Ensure all necessary variables are non-null
                            if (selectedStation != null &&
                                selectedBox != null &&
                                data['busStop'] != null) {
                              print(
                                'Calling Minus with: $selectedStation, $tripNo, ${data['busStop']}',
                              );
                              Minus(selectedStation, tripNo, data['busStop']);
                            } else {
                              print(
                                'One or more values were null: Station: $selectedStation, BusStop: ${data['busStop']}, Box: $selectedBox, Index: $tripNo',
                              );
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
                      child: MRT_Box(
                        box: selectedBox,
                        MRT: 'KAP',
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
                      child: MRT_Box(
                        box: selectedBox,
                        MRT: 'CLE',
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
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      KAPDepartureTime: KAP_DT,
                      CLEDepartureTime: CLE_DT,
                      bookedTripIndexKAP: bookedTripIndexKAP,
                      bookedTripIndexCLE: bookedTripIndexCLE,
                      getDepartureTimes: getDepartureTimes,
                      busStop: selectedBusStop,
                      isDarkMode: widget.isDarkMode,
                      onCancel: () {
                        setState(() {
                          confirmationPressed = false;
                          print('Cancelling the booking...');

                          if (bookedTripIndexCLE != null ||
                              bookedTripIndexKAP != null) {
                            final tripNo = selectedBox == 1
                                ? bookedTripIndexKAP! + 1
                                : bookedTripIndexCLE! + 1;
                            // Ensure all necessary variables are non-null
                            if (selectedStation != null &&
                                selectedBox != null &&
                                selectedBusStop != null) {
                              print(
                                'Calling Minus with: $selectedStation, $tripNo, $selectedBusStop',
                              );
                              Minus(selectedStation, tripNo, selectedBusStop!);
                            } else {
                              print(
                                'One or more values were null: Station: $selectedStation, BusStop: $selectedBusStop, Box: $selectedBox, Index: $tripNo',
                              );
                            }
                          }
                        });
                        prefsService.clearBookingData();
                        futureBookingData = prefsService.getBookingData();
                      },
                    )
                  : BookingService(
                      departureTimes: getDepartureTimes(),
                      eveningService: _eveningService,
                      selectedBox: selectedBox,
                      KAPDepartureTime: _BusData.KAPDepartureTime,
                      CLEDepartureTime: _BusData.CLEDepartureTime,
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
