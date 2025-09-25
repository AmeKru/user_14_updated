import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

///////////////////////////////////////////////////////////////
// News Announcement Page

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
    super.initState();
    _loadData();
    newsContent = busData.news;
    if (kDebugMode) {
      print('Printing _NewsContent: $newsContent');
    }
  }

  Future<void> _loadData() async {
    await busData.loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(TextSizing.fontSizeMiniText(context)),
          child: Container(
            color: Color(0xfffeb041),
            child: Padding(
              padding: EdgeInsets.all(
                TextSizing.fontSizeMiniText(context) * 0.5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: TextSizing.fontSizeMiniText(context) * 0.5,
                      ),
                      Icon(
                        Icons.announcement,
                        color: Colors.blueGrey[900],
                        size: TextSizing.fontSizeHeading(context),
                      ),
                      SizedBox(
                        width: TextSizing.fontSizeMiniText(context) * 0.5,
                      ),
                      Text(
                        'Announcements',
                        style: TextStyle(
                          fontSize: TextSizing.fontSizeHeading(context),
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[900],
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TextSizing.fontSizeText(context)),
                  Row(
                    children: [
                      SizedBox(
                        width: TextSizing.fontSizeMiniText(context) * 0.5,
                      ),
                      Padding(
                        padding: EdgeInsets.all(
                          TextSizing.fontSizeMiniText(context),
                        ),
                        child: Text(
                          textAlign: TextAlign.center,
                          newsContent,
                          style: TextStyle(
                            fontSize: TextSizing.fontSizeText(context),
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
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
        toolbarHeight: TextSizing.fontSizeHeading(context) * 2,
        iconTheme: IconThemeData(
          color: isDarkMode
              ? Color(0xfffeb041)
              : Colors.white, // Arrow back color
        ),
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Color(0xfffeb041),
        title: Text(
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          'NP Announcements',
          style: TextStyle(
            color: isDarkMode ? Color(0xfffeb041) : Colors.white,
            fontSize: TextSizing.fontSizeHeading(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
        child: Column(
          children: [
            SizedBox(height: TextSizing.fontSizeText(context)),
            NewsAnnouncementWidget(isDarkMode: isDarkMode),
          ],
        ),
      ),
    );
  }
}
