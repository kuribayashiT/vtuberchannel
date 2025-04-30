import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../common.dart';

class PushSettingDetail extends StatefulWidget {
  const PushSettingDetail({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PushSettingDetailState createState() => _PushSettingDetailState();
}

class _PushSettingDetailState extends State<PushSettingDetail> {
  late pushNotification instance;
  List<PendingNotificationRequest> scheduledNotifications = [];

  @override
  void initState() {
    super.initState();
    instance = Provider.of<PushRegisterState>(context, listen: false)
        .getInstancepushNotification();
  }

  Future<List<PendingNotificationRequest>> _loadScheduledNotifications() async {
    final List<PendingNotificationRequest> pendingNotifications = await instance
        .flutterLocalNotificationsPlugin
        .pendingNotificationRequests();
    // 他の処理...
    return pendingNotifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push通知'),
        surfaceTintColor: Colors.transparent,
        // shape: const Border(bottom: BorderSide.none),
        backgroundColor: Colors.grey[200],
        actions: [
          IconButton(
            onPressed: () async {
              bool deleteAllPush = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Push通知を全て削除しますか？"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          // 「はい」が選択された場合、true を返す
                          Navigator.of(context).pop(true);
                        },
                        child: const Text("はい"),
                      ),
                      TextButton(
                        onPressed: () {
                          // 「いいえ」が選択された場合、false を返す
                          Navigator.of(context).pop(false);
                        },
                        child: const Text("いいえ"),
                      ),
                    ],
                  );
                },
              );
              // ダイアログの結果に応じて処理を行う
              if (deleteAllPush == true) {
                await instance.removeAllNotification();
                // ignore: use_build_context_synchronously
                Provider.of<PushRegisterState>(context, listen: false)
                    .updatePushRegisterState(true);
                // 非同期処理を待つ
                await Future.delayed(const Duration(seconds: 3));
                setState(() {
                  scheduledNotifications = [];
                  // favolitePageFlgChenge = true;
                });
              }
            },
            icon: const Icon(Icons.delete, size: 28.0),
          ),
        ],
      ),
      body: FutureBuilder<List<PendingNotificationRequest>>(
        future: _loadScheduledNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(); // データ取得中の表示
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            scheduledNotifications = snapshot.data!;
            if (scheduledNotifications.isEmpty) {
              return const Center(child: Text('Push通知が設定されている動画はありません。'));
            } else {
              return Container(
                color: Colors.grey[200],
                child: ListView.builder(
                  itemCount: scheduledNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = scheduledNotifications[index];
                    if (notification.payload != null) {
                      Map<String, dynamic> payloadMap =
                          json.decode(notification.payload!);
                      return Dismissible(
                        key: UniqueKey(),
                        onDismissed: (direction) async {
                          // アイテムが削除されるときの処理

                          Map<String, dynamic> payload =
                              json.decode(notification.payload!);
                          // 非同期メソッドを呼ぶ
                          await instance.removeNotification(payload["videoID"]);

                          // ignore: use_build_context_synchronously
                          Provider.of<PushRegisterState>(context, listen: false)
                              .updatePushRegisterState(true);
                          // 非同期処理を待つ
                          await Future.delayed(const Duration(seconds: 3));
                          setState(() {
                            scheduledNotifications.removeAt(index);
                            // favolitePageFlgChenge = true;
                          });
                        },
                        background: Container(
                          color: Colors.red, // スライド時の背景色
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        child: buildPushList(payloadMap),
                      );
                    }
                    return null;
                  },
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget buildPushList(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        height: 90.0,
        margin: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 160.0,
              height: 90.0,
              margin: const EdgeInsets.only(right: 4.0),
              child: data['thumbnail'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16.0), // 角丸の半径を設定
                      child: CachedNetworkImage(
                        imageUrl: data['thumbnail'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    )
                  : Container(),
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    convertToJapanDayTime(data["comparisonDay"]),
                    style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    data['title'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.0, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
