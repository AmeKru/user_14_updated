import 'package:flutter/material.dart';
import 'package:user_14_updated/data/get_data.dart';
import 'package:user_14_updated/utils/text_sizing.dart';

import '../data/global.dart';

///////////////////////////////////////////////////////////////
// News Announcement Page

class NewsAnnouncementWidget extends StatefulWidget {
  const NewsAnnouncementWidget({super.key});

  @override
  State<NewsAnnouncementWidget> createState() => NewsAnnouncementWidgetState();
}

class NewsAnnouncementWidgetState extends State<NewsAnnouncementWidget> {
  // BusData singleton instance
  BusData busData = BusData();

  // Local copy of news content used for rendering
  String newsContent = '';

  // Listener token for BusData ChangeNotifier
  late VoidCallback _busDataListener;

  // Fallback text shown when there are no announcements
  final String _fallback = 'No announcements at the moment';

  @override
  void initState() {
    super.initState();

    // Optional one-shot load if BusData may not have loaded yet
    // This will call notifyListeners when load completes
    busData.loadData();

    // Initialize local content from current BusData (may be empty)
    newsContent = busData.news;

    // Listener updates local state when BusData notifies
    _busDataListener = () {
      if (!mounted) return;
      final newNews = busData.news;
      if (newNews != newsContent) {
        setState(() {
          // Set State if changed
          newsContent = newNews;
        });
      }
    };

    // Subscribe to BusData notifications
    busData.addListener(_busDataListener);
  }

  @override
  void dispose() {
    // Clean up listener when widget is removed
    busData.removeListener(_busDataListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use fallback text when there are no announcements
    final displayText = (newsContent.trim().isEmpty) ? _fallback : newsContent;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(TextSizing.fontSizeText(context)),
          child: Container(
            // Announcement background color
            color: const Color(0xfffeb041),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                TextSizing.fontSizeHeading(context),
                TextSizing.fontSizeText(context),
                TextSizing.fontSizeHeading(context),
                TextSizing.fontSizeHeading(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with icon and title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.announcement,
                        color: Colors.blueGrey[900],
                        size: TextSizing.fontSizeHeading(context),
                      ),
                      SizedBox(
                        width: TextSizing.fontSizeMiniText(context) * 0.5,
                      ),
                      Flexible(
                        child: Text(
                          'Announcements',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: TextSizing.fontSizeHeading(context),
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TextSizing.fontSizeText(context)),
                  // Centered announcement text
                  Center(
                    child: Text(
                      displayText,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeText(context),
                        fontFamily: 'Roboto',
                        color: Colors.blueGrey[900],
                      ),
                    ),
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
  const NewsAnnouncement({super.key});

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
        backgroundColor: isDarkMode ? Colors.blueGrey[800] : Color(0xff014689),
        title: Text(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          'NP Announcements',
          style: TextStyle(
            color: isDarkMode ? Color(0xfffeb041) : Colors.white,
            fontSize: TextSizing.fontSizeHeading(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
        child: Column(
          children: [
            SizedBox(height: TextSizing.fontSizeText(context)),
            NewsAnnouncementWidget(),
          ],
        ),
      ),
    );
  }
}
