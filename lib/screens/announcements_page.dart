import 'package:flutter/material.dart';

import '../data/get_data.dart';
import '../data/global.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- News Announcement Page ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// NewsAnnouncementWidget class
// used for np announcement page, shows the announcements widget that is
// also used in the main sliding panel on map_page

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

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  //////////////////////////////////////////////////////////////////////////////
  // initState

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

  //////////////////////////////////////////////////////////////////////////////
  // get sizing at start

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  //////////////////////////////////////////////////////////////////////////////
  // dispose of listener when widget is destroyed

  @override
  void dispose() {
    // Clean up listener when widget is removed
    busData.removeListener(_busDataListener);
    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  // the yellow widget that shows the announcements

  @override
  Widget build(BuildContext context) {
    // Use fallback text when there are no announcements
    final displayText = (newsContent.trim().isEmpty) ? _fallback : newsContent;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(fontSizeText),
          child: Container(
            // Announcement background color
            color: const Color(0xfffeb041),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                fontSizeHeading,
                fontSizeText,
                fontSizeHeading,
                fontSizeHeading,
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
                        size: fontSizeHeading,
                      ),
                      SizedBox(width: fontSizeMiniText * 0.5),
                      Flexible(
                        child: Text(
                          'Announcements',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSizeHeading,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: fontSizeText),
                  // Centered announcement text
                  Center(
                    child: Text(
                      displayText,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSizeText,
                        fontFamily: 'Roboto',
                        color: newsContent.trim().isEmpty
                            ? const Color.fromRGBO(38, 50, 56, 0.5)
                            : Colors.blueGrey[900],
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

////////////////////////////////////////////////////////////////////////////////
// the actual announcement page

class NewsAnnouncement extends StatelessWidget {
  // for sizing
  final double fontSizeMiniText;
  final double fontSizeText;
  final double fontSizeHeading;

  const NewsAnnouncement({
    super.key,
    required this.fontSizeMiniText,
    required this.fontSizeText,
    required this.fontSizeHeading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: fontSizeHeading * 2,
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
            fontSize: fontSizeHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: isDarkMode ? Colors.blueGrey[900] : Colors.white,
        child: SafeArea(
          right: true,
          left: true,
          top: true,
          bottom: false,
          child: Column(
            children: [
              SizedBox(height: fontSizeText),
              NewsAnnouncementWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
