// Package
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/googleCloudFunctions.dart';
import 'package:vtuberchannel/sideMenu.dart';

class eventCalendar extends StatefulWidget {
  @override
  _eventCalendarState createState() => _eventCalendarState();
}

class _eventCalendarState extends State<eventCalendar> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  Map<String, List<dynamic>> events = {};
  List<dynamic> selectedEvents = [];

  @override
  void initState() {
    super.initState();

    getEventData();
  }

  Future<void> getEventData() async {
    try {
      // Google Cloud Functionsを呼び出してデータを取得
      final List<dynamic> fetchedEvents =
          await GoogleCloudFunctions.getEventData();
      // EventFilter クラスを使用

      setState(() {
        final List<String> officeData =
            Provider.of<SelectedCategorie>(context, listen: false).officeOrder;
        String formattedDate = DateFormat('M/d').format(selectedDay);
        if (officeData.isEmpty) {
          events = _parseEvents(fetchedEvents);
          selectedEvents = events[formattedDate] ?? [];
        } else {
          Map<String, List<dynamic>> filteredEvents =
              filterEventsByOffice(fetchedEvents, officeData);
          //データの変換
          List<Map<String, List<dynamic>>> resultList =
              convertMapToList(filteredEvents);
          events = _parseEvents(resultList);
          selectedEvents = events[formattedDate] ?? [];
        }
      });
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  List<Map<String, List<dynamic>>> convertMapToList(
      Map<String, List<dynamic>> mapData) {
    List<Map<String, List<dynamic>>> resultList = [];

    // Map の各エントリを個別の Map にしてリストに追加
    mapData.forEach((key, value) {
      resultList.add({key: value});
    });

    return resultList;
  }

  Map<String, List<dynamic>> _parseEvents(List<dynamic> rawData) {
    final Map<String, List<dynamic>> parsedEvents = {};

    for (var item in rawData) {
      item.forEach((dateString, eventList) {
        try {
          // 日付文字列が空でないことを確認
          if (dateString.isNotEmpty) {
            final dateParts = dateString.split('/');

            // 日付文字列が2つの部分に分かれていることを確認
            if (dateParts.length == 2) {
              final month = int.tryParse(dateParts[0]); // 月をパース
              final day = int.tryParse(dateParts[1]); // 日をパース

              if (month != null && day != null) {
                final String eventDate = "$month/$day";
                // イベントをMapに追加
                parsedEvents[eventDate] ??= [];

                // eventListがList型の場合
                if (eventList is List) {
                  eventList.forEach((event) {
                    if (event is Map) {
                      // イベントがMapの場合、必要な情報を取り出してリストに追加
                      //final eventName = event['name'] ?? 'No Name';
                      parsedEvents[eventDate]!.add(event);
                    }
                  });
                }
              } else {
                print('Invalid date parts: $dateParts');
              }
            } else {
              print('Invalid date string format: $dateString');
            }
          } else {
            print('Empty date string: $dateString');
          }
        } catch (e) {
          print('Error parsing date: $dateString, error: $e');
        }
      });
    }

    return parsedEvents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベントカレンダー'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2015, 1, 1),
            lastDay: DateTime.utc(2050, 1, 1),
            focusedDay: focusedDay,
            locale: 'ja_JP',
            selectedDayPredicate: (day) {
              return isSameDay(selectedDay, day);
            },
            onDaySelected: (selectedDayParam, focusedDayParam) {
              setState(() {
                selectedDay = selectedDayParam;
                focusedDay = focusedDayParam;
                String formattedDate = DateFormat('M/d').format(selectedDay);
                selectedEvents = events[formattedDate] ?? [];
              });
            },
            eventLoader: (day) {
              String formattedDate = DateFormat('M/d').format(day);
              return events[formattedDate] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, eventList) {
                if (eventList.isNotEmpty) {
                  // if(eventList[]["eventType"]=="birthday"){

                  // }
                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: eventList.map((event) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
                return null;
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // フォーマット切り替えボタンを非表示
            ),
          ),
          const SizedBox(height: 16),
          // 選択中の日付を表示
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                DateFormat('yyyy年M月d日').format(selectedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: selectedEvents.length,
              itemBuilder: (context, index) {
                String anniversaryText = '不明';
                if (selectedEvents[index]['eventType'] == "createAt") {
                  String fixDateFormat(String date) {
                    final parts = date.replaceAll('/', '-').split('-');
                    final year = parts[0];
                    final month = parts[1].padLeft(2, '0'); // 月をゼロ埋め
                    final day = parts[2].padLeft(2, '0'); // 日をゼロ埋め
                    return '$year-$month-$day';
                  }

                  final createdAtRaw =
                      selectedEvents[index]['createdAt']; // "2020-12-5" など
                  final fixedDate = fixDateFormat(createdAtRaw);
                  final createdAtDate = DateTime.parse(fixedDate);
                  final currentYear = DateTime.now().year;
                  final eventYear = createdAtDate.year;
                  final yearDifference = currentYear - eventYear;

                  if (yearDifference >= 0) {
                    anniversaryText = '$yearDifference周年';
                  } else {
                    anniversaryText = '未来のイベント';
                  }
                } else if (selectedEvents[index]['eventType'] == "birthday") {
                  anniversaryText = '誕生日';
                }
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  leading: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(
                        selectedEvents[index]['channelThumbnail'] ??
                            'https://via.placeholder.com/50',
                      ),
                    ),
                  ),
                  title: Text(
                    selectedEvents[index]['name'] ?? 'タイトルなし',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedEvents[index]['office'] ?? 'サブタイトルなし',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        anniversaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
