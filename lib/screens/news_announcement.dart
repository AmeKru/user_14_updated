import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';

class NewsAnnouncementWidget extends StatefulWidget {
  final bool isDarkMode;
  const NewsAnnouncementWidget({super.key, required this.isDarkMode});

  @override
  State<NewsAnnouncementWidget> createState() => NewsAnnouncementWidgetState();
}

class NewsAnnouncementWidgetState extends State<NewsAnnouncementWidget> {
  BusData busData = BusData();
  String newsContent = '';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    newsContent = busData.news;
    if (kDebugMode) {
      print('Printing _NewsContent: $newsContent');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
            color: Color(0xfffeb041),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.announcement, color: Colors.blueGrey[900]),
                      SizedBox(width: 5.0),
                      Text(
                        'Announcements',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(newsContent, style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NewsAnnouncement extends StatelessWidget {
  final bool isDarkMode;

  const NewsAnnouncement({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: isDarkMode
              ? Color(0xfffeb041)
              : Colors.white, // Arrow back color
        ),
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Color(0xfffeb041),
        title: Text(
          'NP News Announcements',
          style: TextStyle(
            color: isDarkMode ? Color(0xfffeb041) : Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
        child: NewsAnnouncementWidget(isDarkMode: isDarkMode),
      ),
    );
  }
}
