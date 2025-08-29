import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'googleCloudFunctions.dart';
import 'sideMenu.dart';
// import 'package:vtuberchannel/videoDistribution/livePage.dart';
import '/main.dart';
// import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:fluttertoast/fluttertoast.dart';

bool isOshiraseUpdated = false;
// ===============================
// Date/Time Format
// ===============================
String convertToJapanTime(String isoDateTime) {
  DateTime dateTime = DateTime.parse(isoDateTime);
  var japanTime = dateTime.toLocal();

  String formattedTime = DateFormat('HH:mm').format(japanTime);

  return formattedTime;
}

String convertToJapanDayTime(String isoDateTime) {
  try {
    DateTime dateTime = DateTime.parse(isoDateTime);
    // 端末のローカルタイムゾーンに変換
    final localTime = dateTime.toLocal();
    // フォーマット例: 2025/07/29 12:34
    String formattedTime = DateFormat('yyyy/MM/dd HH:mm').format(localTime);
    return formattedTime;
  } catch (e) {
    return isoDateTime;
  }
}

String convertToJapanDayDate(String isoDateTime) {
  DateTime dateTime = DateTime.parse(isoDateTime);
  var japanTime = dateTime.toLocal();

  String formattedTime = DateFormat('yyyy/MM/dd').format(japanTime);

  return formattedTime;
}

int convertToJapanDayTimeToPushId(String isoDateTime) {
  final random = Random();
  final ramdomId = random.nextInt(1000);
  DateTime dateTime = DateTime.parse(isoDateTime);
  var japanTime = dateTime.toLocal();
  String formattedTime = DateFormat('ddHHmm').format(japanTime);
  String idString = formattedTime + ramdomId.toString();
  return int.parse(idString);
}

tz.TZDateTime convertToPushTime(String isoDateTime) {
  // タイムゾーンデータの初期化
  tzdata.initializeTimeZones();
  // ローカルのタイムゾーンの設定
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  // フォーマットに基づいて文字列からDateTimeに変換
  DateTime dateTime = DateTime.parse(isoDateTime);
  // DateTimeからtz.TZDateTimeに変換
  tz.TZDateTime formattedTime = tz.TZDateTime.from(dateTime, tz.local);

  return formattedTime;
}

// ===============================
// UI Size
// ===============================
int row = 1;
double calculateItemHeight(BuildContext context) {
  // ここで各ウィジェットの高さを動的に計算するロジックを実装
  double thumbnailAspectRatio = 16 / 9;
  double titleHeight = 50.0; // タイトルの高さ
  double channelTitleHeight = 20.0; // チャンネルタイトルの高さ
  double dateHeight = 20.0; // 日時の高さ
  double spacingHeight = 8.0; // 余白や間隔の高さ
  double btmMargin = 11.0; // チャンネルサムネイルの高さ

  // サムネイルの高さをデバイスの幅に応じて計算
  double thumbnailHeight = 0.0;

  if (kIsWeb && row > 1) {
    (thumbnailHeight = (MediaQuery.of(context).size.width - 16) / row) /
        thumbnailAspectRatio;
  } else {
    thumbnailHeight = MediaQuery.of(context).size.width / thumbnailAspectRatio;
  }
  // 各要素の高さを足し合わせて全体の高さを計算
  return thumbnailHeight +
      spacingHeight +
      spacingHeight +
      titleHeight +
      channelTitleHeight +
      dateHeight +
      btmMargin +
      spacingHeight +
      6;
}

// ===============================
// Local Push
// ===============================
class pushNotification {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
      _plugin;

  Future<void> registerMessage(Map<String, dynamic> data) async {
    int notificationID = convertToJapanDayTimeToPushId(data["comparisonDay"]);
    // ここを修正！payloadをFCMのdata.payloadと同じ構造に
    String payload = json.encode({
      "title": data["title"],
      "thumbnail": data["thumbnail"],
      "videoID": data["videoID"],
      "notificationId": notificationID,
      "comparisonDay": data["comparisonDay"],
      // 必要なら他の項目も追加
    });

    await _plugin.zonedSchedule(
      notificationID,
      "配信が始まります",
      data["title"],
      convertToPushTime(data["comparisonDay"]),
      NotificationDetails(
        android: AndroidNotificationDetails(
          data["videoID"],
          data["channelTitle"],
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          styleInformation:
              BigTextStyleInformation("${data["title"]}の配信が始まります"),
          icon: 'ic_notification',
          additionalFlags: Int32List.fromList([1]),
        ),
        iOS: const DarwinNotificationDetails(badgeNumber: 1),
      ),
      payload: payload,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> init() async {
    await _configureLocalTimeZone();
    const android = AndroidInitializationSettings('ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );
    final settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          showNotificationDialog(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  }

  // アプリ起動中に即時ダイアログを出したい場合
  void showDialogForImmediatePush(Map<String, dynamic> data) {
    String payload = json.encode({
      "notificationId": data["notificationId"] ?? "",
      "videoID": data["videoID"],
      "title": data["title"],
      "thumbnail": data["thumbnail"],
      "comparisonDay": data["comparisonDay"],
    });
    showNotificationDialog(payload);
  }

  Future<bool> checkRegistPushFromVideoId(String videoID) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (var element in pending) {
      if (element.payload != null) {
        Map<String, dynamic> payload = json.decode(element.payload!);
        if (payload['videoID'] == videoID) return true;
      }
    }
    return false;
  }

  Future<void> removeAllNotification() async {
    await _plugin.cancelAll();
  }

  Future<void> removeNotification(String notificationId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (var element in pending) {
      if (element.payload != null) {
        Map<String, dynamic> payload = json.decode(element.payload!);
        if (payload['videoID'] == notificationId) {
          final id = payload["notificationId"];
          await _plugin.cancel(id is int ? id : int.parse(id.toString()));
        }
      }
    }
  }
}

// バックグラウンド/未起動時の通知タップ
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  final payload = notificationResponse.payload;
  if (payload == null || payload.isEmpty) return;
  showNotificationDialog(payload);
}

// iOS 10未満用（ほぼ不要だが一応残す）
void onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) {
  didReceiveLocalNotificationStream.add(
    ReceivedNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    ),
  );
}
// class pushNotification {
//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
//       _flutterLocalNotificationsPlugin;

//   Future<void> registerMessage(Map<String, dynamic> data) async {
//     int notificationID = convertToJapanDayTimeToPushId(data["comparisonDay"]);
//     String jsonString =
//         '{"notificationId":"$notificationID","videoID":"${data["videoID"]}","title":"${data["title"]}","thumbnail":"${data["thumbnail"]}","comparisonDay":"${data["comparisonDay"]}"}';
//     Map<String, dynamic> payloadMap = json.decode(jsonString);
//     await _flutterLocalNotificationsPlugin.zonedSchedule(
//       notificationID,
//       "配信が始まります",
//       data["title"],
//       convertToPushTime(data["comparisonDay"]),
//       NotificationDetails(
//         android: AndroidNotificationDetails(
//           data["videoID"],
//           data["channelTitle"],
//           importance: Importance.max,
//           priority: Priority.high,
//           ongoing: true,
//           styleInformation:
//               BigTextStyleInformation(data["title"] + "の配信が始まります"),
//           icon: 'ic_notification',
//           additionalFlags: Int32List.fromList([1]),
//         ),
//         iOS: const DarwinNotificationDetails(
//           badgeNumber: 1,
//         ),
//       ),
//       payload: json.encode(payloadMap),
//       androidAllowWhileIdle: true,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//       matchDateTimeComponents: DateTimeComponents.time,
//     );
//   }

//   void checkForLocalPushNotifications() {
//     if (!kIsWeb) {
//       // int executionCount = 0; // 実行回数をカウントする変数
//       Timer.periodic(const Duration(seconds: 3), (timer) async {
//         // 実行回数をインクリメント
//         // executionCount++;
//         // 通知を取得
//         var pendingNotifications = await _flutterLocalNotificationsPlugin
//             .pendingNotificationRequests();
//         // 現在時刻
//         var now = DateTime.now();
//         print("Push Check:$now");

//         // 取得した通知を処理する
//         for (var notification in pendingNotifications) {
//           // 通知のペイロードから受信時刻を取得
//           if (notification.payload != null) {
//             var payloadMap = json.decode(notification.payload!);
//             var receivedTime = DateTime.parse(payloadMap['comparisonDay']);

//             // 受信時刻が現在時刻より過去の場合に処理を実行
//             if (receivedTime.isBefore(now)) {
//               // 通知に関する処理を実行
//               showNotificationDialog(notification.payload!);
//             }
//           }
//         }
//         // // 指定回数に達したらタイマーを停止
//         // if (executionCount >= 3) {
//         //   timer.cancel();
//         //   print("タイマーを停止しました。");
//         // }
//       });
//     }
//   }

//   Future<void> _configureLocalTimeZone() async {
//     tz.initializeTimeZones();
//     // final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
//     // var timeZone = detroit.timeZone(timeInUtc.millisecondsSinceEpoch);
//     tz.setLocalLocation(tz.getLocation(tz.local.name));
//   }

//   Future<void> _initializeNotification() async {
//     //iOS設定
//     var initializationSettingsIOS = const DarwinInitializationSettings(
//         requestAlertPermission: true,
//         requestBadgePermission: true,
//         requestSoundPermission: true,
//         onDidReceiveLocalNotification: onDidReceiveLocalNotification);

//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('ic_notification');

//     InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );

//     // flutterLocalNotificationsPluginの初期化
//     await flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
//       onDidReceiveNotificationResponse:
//           (NotificationResponse notificationResponse) async {
//         final payload = notificationResponse.payload;
//         // 空文字なら何もしない
//         if (payload == null || payload.isEmpty) {
//           return;
//         }
//         showNotificationDialog(payload);
//       },
//     );
//     await _flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse:
//           (NotificationResponse notificationResponse) {
//         switch (notificationResponse.notificationResponseType) {
//           case NotificationResponseType.selectedNotification:
//             // showCustomView(notificationResponse.payload);
//             print("selectedNotification");
//             print(notificationResponse.payload);
//             break;
//           case NotificationResponseType.selectedNotificationAction:
//             // showCustomView(notificationResponse.payload);
//             print("selectedNotificationAction");
//             print(notificationResponse.payload);
//             // if (notificationResponse.actionId == navigationActionId) {
//             // }
//             break;
//         }
//         final payload = notificationResponse.payload;
//         // 空文字なら何もしない
//         if (payload == null || payload.isEmpty) {
//           return;
//         }
//         showNotificationDialog(payload);
//       },
//       onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
//     );
//   }

//   Future<bool> checkRegistPushFromVideoId(String videoID) async {
//     final List<PendingNotificationRequest> pendingNotifications =
//         await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
//     for (PendingNotificationRequest element in pendingNotifications) {
//       Map<String, dynamic> payload = json.decode(element.payload!);
//       if (payload['videoID'] == videoID) {
//         return true;
//       }
//     }
//     return false;
//   }

//   Future<void> removeAllNotification() async {
//     await _flutterLocalNotificationsPlugin.cancelAll();
//   }

//   Future<void> removeNotification(String notificationId) async {
//     final List<PendingNotificationRequest> pendingNotifications =
//         await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
//     for (PendingNotificationRequest element in pendingNotifications) {
//       Map<String, dynamic> payload = json.decode(element.payload!);
//       if (payload['videoID'] == notificationId) {
//         await _flutterLocalNotificationsPlugin
//             .cancel(int.parse(payload["notificationId"]));
//       }
//     }
//   }

//   Future<void> init() async {
//     await _configureLocalTimeZone();
//     await _initializeNotification();
//   }
// }

// @pragma('vm:entry-point')
// void notificationTapBackground(NotificationResponse notificationResponse) {
//   // ignore: avoid_print
//   print('notification(${notificationResponse.id}) action tapped: '
//       '${notificationResponse.actionId} with'
//       ' payload: ${notificationResponse.payload}');
//   if (notificationResponse.input?.isNotEmpty ?? false) {
//     // ignore: avoid_print
//     print(
//         'notification action tapped with input: ${notificationResponse.input}');
//   }
//   final payload = notificationResponse.payload;
//   // 空文字なら何もしない
//   if (payload == null || payload.isEmpty) {
//     return;
//   }
//   // 共通のダイアログ表示ロジックを呼び出す
//   showNotificationDialog(payload);
// }

// void onDidReceiveLocalNotification(
//     int id, String? title, String? body, String? payload) {
//   didReceiveLocalNotificationStream.add(
//     ReceivedNotification(
//       id: id,
//       title: title,
//       body: body,
//       payload: payload,
//     ),
//   );
// }

List<BuildContext> dialogContexts = [];
// 共通のダイアログ表示ロジック
void showNotificationDialog(String payload) {
  final Map<String, dynamic> notificationData = json.decode(payload);
  final String title = notificationData['title'];
  final String thumbnailUrl = notificationData['thumbnail'];
  final String videoId = notificationData['videoID'];

  Provider.of<PushRegisterState>(openContext, listen: false)
      .getInstancepushNotification()
      .removeNotification(videoId);
  showDialog(
      context: openContext,
      builder: (BuildContext context) {
        dialogContexts.add(context);
        return AlertDialog(
          title: const Text('配信が始まります'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              const SizedBox(height: 8),
              Image.network(thumbnailUrl), // 画像を表示
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 全て削除ボタンが押されたときの処理
                closeAllDialogs(); // ダイアログを閉じる
              },
              child: const Text('Push通知を全て削除'),
            ),
            TextButton(
              onPressed: () {
                // キャンセルボタンが押されたときの処理
                Provider.of<PushRegisterState>(openContext, listen: false)
                    .getInstancepushNotification()
                    .removeNotification(videoId);
                Navigator.pop(context); // ダイアログを閉じる
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // OKボタンが押されたときに行いたい処理
                Provider.of<YoutubePlayerState>(context, listen: false)
                    .setVideoId(videoId);
                Navigator.pop(context); // ダイアログを閉じる
              },
              child: const Text('視聴する'),
            ),
          ],
        );
      });
}

void closeAllDialogs() {
  for (BuildContext context in dialogContexts) {
    Navigator.of(context).pop();
  }
  dialogContexts.clear(); // ダイアログリストをクリアする
}

// ===============================
// Toast/Message
// ===============================
void showToast(String masg) {
  Fluttertoast.showToast(
    msg: masg,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.TOP, // 上部に表示するために設定
    backgroundColor: Colors.black.withOpacity(0.8),
    textColor: Colors.white,
    timeInSecForIosWeb: 1,
    fontSize: 16.0,
  );
}

class CustomToast extends StatelessWidget {
  final String message;

  const CustomToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: SafeArea(
            top: true,
            bottom: true,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 48.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[800]!.withOpacity(0.85),
                    Colors.grey[600]!.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 36.0,
        left: 24.0,
        right: 24.0,
        child: CustomToast(message: message),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}

// ===============================
// カスタムリストView
// ===============================
class FasterScrollPhysics extends BouncingScrollPhysics {
  const FasterScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  FasterScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FasterScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // スクロール速度を倍にする
    return super.applyPhysicsToUserOffset(position, offset * 1.3);
  }
}

Future<void> initializeCategoriesOrder(context) async {
  final Map<String, dynamic> fetchedCategoriesMap =
      await GoogleCloudFunctions.getOfficeData();

  List<String> fetchedCategories = fetchedCategoriesMap.keys.toList();
  if (fetchedCategories.isNotEmpty &&
      fetchedCategoriesMap[fetchedCategories.first] is List &&
      (fetchedCategoriesMap[fetchedCategories.first] as List).isNotEmpty &&
      (fetchedCategoriesMap[fetchedCategories.first][0] as Map<String, dynamic>)
          .containsKey('order')) {
    fetchedCategories.sort((a, b) {
      final aOrder = (fetchedCategoriesMap[a][0]['order'] ?? 9999) as int;
      final bOrder = (fetchedCategoriesMap[b][0]['order'] ?? 9999) as int;
      return aOrder.compareTo(bOrder);
    });
  }
  // Providerにセット
  Provider.of<SelectedCategorie>(context, listen: false)
      .setCategoriesOrder(fetchedCategories);

  // アイコンもセットしたい場合
  Map<String, String> icons = {};
  fetchedCategoriesMap.forEach((officeName, vtuberList) {
    final vtuberWithIcon = vtuberList.firstWhere(
      (vtuber) => vtuber['officeFlg'] == true,
      orElse: () => null,
    );
    if (vtuberWithIcon != null && vtuberWithIcon['channelThumbnail'] != null) {
      icons[officeName] = vtuberWithIcon['channelThumbnail'];
    } else {
      icons[officeName] = "";
    }
  });
  Provider.of<SelectedCategorie>(context, listen: false).setOfficeIcons(icons);
}

// ===============================
// Firebase
// ===============================
class FirebaseRemoteConfigService {
  void initRemoteConfig() async {
    /// インスタンスの作成
    final remoteConfig = FirebaseRemoteConfig.instance;

    /// シングルトンオブジェクトの取得
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(minutes: 5),
    ));

    /// アプリ内デフォルトパラメータ値の設定
    await remoteConfig.setDefaults(const {
      "tetetetst": "Hello, world!",
    });

    /// 値をフェッチ
    await remoteConfig.fetchAndActivate();
  }
}

// ===============================
// office Filter
// ===============================
List<dynamic> filterByOfficeIndices(List<dynamic> originalList,
    Set<String> selectedOffice, String orderOption) {
  List<dynamic> filteredList = [];
  List<String> stringListFromSet = selectedOffice.toList();
  if (stringListFromSet.isEmpty) {
    return originalList;
  }
  for (var office in stringListFromSet) {
    for (var originalItem in originalList) {
      if (originalItem['office'] == office) {
        filteredList.add(originalItem);
      }
    }
  }
  switch (orderOption) {
    case 'video':
      return filteredList;
    case 'rankingDatayoutube':
      filteredList.sort((a, b) {
        var rankingDatayoutubeA = a['youtubeSubscriberCount'];
        var rankingDatayoutubeB = b['youtubeSubscriberCount'];
        // Nullチェックを追加して、Nullのデータを無視する
        if (rankingDatayoutubeA == null || rankingDatayoutubeB == null) {
          return 0; // Nullのデータは無視するため、並び替えをしない
        }

        // 数値に変換してから比較を行う
        int? countA = int.tryParse(rankingDatayoutubeA);
        int? countB = int.tryParse(rankingDatayoutubeB);

        if (countA == null || countB == null) {
          return 0; // 数値に変換できない場合も並び替えをしない
        }
        return countB.compareTo(countA);
      });
      return filteredList;
    case 'rankingDatavideoCount':
      filteredList.sort((a, b) {
        var rankingDatavideoCountA = a['videoCount'];
        var rankingDatavideoCountB = b['videoCount'];
        // Nullチェックを追加して、Nullのデータを無視する
        if (rankingDatavideoCountA == null || rankingDatavideoCountB == null) {
          return 0; // Nullのデータは無視するため、並び替えをしない
        }

        // 数値に変換してから比較を行う
        int? countA = int.tryParse(rankingDatavideoCountA);
        int? countB = int.tryParse(rankingDatavideoCountB);

        if (countA == null || countB == null) {
          return 0; // 数値に変換できない場合も並び替えをしない
        }
        return countB.compareTo(countA);
      });
      return filteredList;
    case 'rankingDataWeeklyLiveViewRanking':
      filteredList.sort((a, b) {
        var rankingDatavideoCountA = a['concurrent_viewers'];
        var rankingDatavideoCountB = b['concurrent_viewers'];
        // Nullチェックを追加して、Nullのデータを無視する
        if (rankingDatavideoCountA == null || rankingDatavideoCountB == null) {
          return 0; // Nullのデータは無視するため、並び替えをしない
        }

        // 数値に変換してから比較を行う
        int? countA = int.tryParse(rankingDatavideoCountA);
        int? countB = int.tryParse(rankingDatavideoCountB);

        if (countA == null || countB == null) {
          return 0; // 数値に変換できない場合も並び替えをしない
        }
        return countB.compareTo(countA);
      });
      return filteredList;
    case 'rankingDataTwitter':
      // NULLのデータを持つ要素をフィルタリングして新しいリストを作成
      List<dynamic> filteredList = originalList
          .where((element) => element['twitterFollowerCount'] != null)
          .toList();
      filteredList.sort((a, b) {
        var twitterFollowerCountA = a['twitterFollowerCount'];
        var twitterFollowerCountB = b['twitterFollowerCount'];
        //     // Nullチェックを追加して、Nullのデータを無視する
        // if (twitterFollowerCountA == null || twitterFollowerCountB == null) {
        //   return 0; // Nullのデータは無視するため、並び替えをしない
        // }

        // 数値に変換してから比較を行う
        int? countA = int.tryParse(twitterFollowerCountA);
        int? countB = int.tryParse(twitterFollowerCountB);

        if (countA == null || countB == null) {
          return 0; // 数値に変換できない場合も並び替えをしない
        }
        return countB.compareTo(countA); // 多い順に並び替える
      });
      return filteredList;
    default:
      return filteredList;
  }
}

List<dynamic> filterByOfficeVtuber(Map<String, dynamic> originalMap,
    Set<String> selectedOffice, List<String> officeData, List<String> order) {
  List<dynamic> filteredList = [];
  List<String> stringListFromSet = selectedOffice.toList();

  if (stringListFromSet.isEmpty) {
    for (var office in officeData) {
      if (originalMap.containsKey(office)) {
        filteredList.addAll(originalMap[office]);
      }
    }
  } else {
    for (var office in order) {
      if (selectedOffice.contains(office) && originalMap.containsKey(office)) {
        filteredList.addAll(originalMap[office]);
      }
    }
  }

  return filteredList;
}

Map<String, List<dynamic>> filterEventsByOffice(
    List<dynamic> fetchedEvents, List<String> officeData) {
  Map<String, List<dynamic>> filteredEvents = {};

  for (var event in fetchedEvents) {
    (event as Map<String, dynamic>).forEach((date, eventList) {
      // officeData に一致するイベントだけをフィルタリング
      final filteredList = (eventList as List)
          .where((e) => officeData.contains(e['office']))
          .toList();

      if (filteredList.isNotEmpty) {
        filteredEvents[date] = filteredList;
      }
    });
  }

  return filteredEvents;
}

// ===============================
// PushRegisterState
// ===============================
// アプリケーション全体の状態を管理するためのProvider
class PushRegisterState with ChangeNotifier {
  bool _pushRegisterState = false; // 選択されたカテゴリを保持する変数
  bool get pushRegisterState => _pushRegisterState;
  pushNotification _pushNotificationInstance = pushNotification();
  pushNotification get pushNotificationInstance => _pushNotificationInstance;

  // 更新を通知するメソッド
  void updatePushRegisterState(bool newPushRegisterState) {
    _pushRegisterState = newPushRegisterState;
    _pushNotificationInstance = pushNotification();
    notifyListeners(); // 変更をリスナーに通知
    _pushRegisterState = false;
  }

  // 更新を通知するメソッド
  void updatePushNotificationRegisterState(bool newPushRegisterState) {
    _pushNotificationInstance = pushNotification();
    notifyListeners(); // 変更をリスナーに通知
    _pushRegisterState = false;
  }

  pushNotification getInstancepushNotification() {
    return _pushNotificationInstance;
  }
}

// ===============================
// Admob
// ===============================
class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? "ca-app-pub-3940256099942544/6300978111" // Androidのデモ用バナー広告ID
          : 'ca-app-pub-1929244717899448/9184487113';
    } else if (Platform.isIOS) {
      return kDebugMode
          ? "ca-app-pub-3940256099942544/2934735716" // iOSのデモ用バナー広告ID
          : 'ca-app-pub-1929244717899448/7216500680';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  DateTime lastInterstitialShown =
      DateTime.now().subtract(const Duration(minutes: 2));
  final Duration _interstitialInterval = Duration(minutes: 2);

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? "ca-app-pub-3940256099942544/1033173712" // Androidのデモ用インタースティシャル広告ID
          : 'ca-app-pub-1929244717899448/4271071785';
    } else if (Platform.isIOS) {
      return kDebugMode
          ? "ca-app-pub-3940256099942544/4411468910" // iosのデモ用インタースティシャル広告ID
          : 'ca-app-pub-1929244717899448/9824192586';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return '<YOUR_ANDROID_REWARDED_AD_UNIT_ID>';
    } else if (Platform.isIOS) {
      return '<YOUR_IOS_REWARDED_AD_UNIT_ID>';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? "ca-app-pub-3940256099942544/2247696110" // Androidのデモ用ネイティブ広告ID
          : 'ca-app-pub-1929244717899448/3808037351';
    } else if (Platform.isIOS) {
      return kDebugMode
          ? "ca-app-pub-3940256099942544/3986624511" // iosのデモ用ネイティブ広告ID
          : 'ca-app-pub-1929244717899448/9175383959';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static NativeTemplateStyle nativeTemplateStyle = NativeTemplateStyle(
      // Required: Choose a template.
      templateType: TemplateType.medium,
      // Optional: Customize the ad's style.
      mainBackgroundColor: Colors.transparent,
      cornerRadius: 10.0,
      callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.monospace,
          size: 16.0),
      primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.italic,
          size: 16.0),
      secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0),
      tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue,
          style: NativeTemplateFontStyle.normal,
          size: 16.0));

  // Native Ads
  final int maxNativeAds;
  final List<NativeAd?> _nativeAds = [];
  int _currentNativeAdIndex = 0;

  AdHelper({this.maxNativeAds = 3});

  void loadNativeAds() {
    if (_nativeAds.length >= maxNativeAds) return;
    for (int i = _nativeAds.length; i < maxNativeAds; i++) {
      final ad = NativeAd(
        adUnitId: nativeAdUnitId,
        request: const AdRequest(),
        factoryId: 'listTile',
        listener: NativeAdListener(
          onAdLoaded: (ad) => _nativeAds.add(ad as NativeAd),
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            _nativeAds.add(null);
          },
        ),
      );
      ad.load();
    }
  }

  Widget buildNextNativeAdWidget() {
    if (_nativeAds.isEmpty || _currentNativeAdIndex >= _nativeAds.length) {
      loadNativeAds();
      return const SizedBox();
    }
    final ad = _nativeAds[_currentNativeAdIndex];
    // 使い回し防止: 返却したadはリストからremoveして二重利用を防ぐ
    if (ad != null) {
      _nativeAds.removeAt(_currentNativeAdIndex);
      // インデックス調整
      if (_currentNativeAdIndex >= _nativeAds.length) {
        _currentNativeAdIndex = 0;
      }
      return AdWidget(ad: ad);
    } else {
      _nativeAds.removeAt(_currentNativeAdIndex);
      if (_currentNativeAdIndex >= _nativeAds.length) {
        _currentNativeAdIndex = 0;
      }
      return const SizedBox();
    }
  }

  void disposeNativeAds() {
    for (final ad in _nativeAds) {
      ad?.dispose();
    }
    _nativeAds.clear();
    _currentNativeAdIndex = 0;
  }

  // Banner Ads
  List<BannerAd?> bannerAds = [];
  void loadBannerAds() {
    for (int i = 0; i < 1; i++) {
      if (Platform.isIOS || Platform.isAndroid) {
        BannerAd(
            adUnitId: AdHelper.bannerAdUnitId,
            request: const AdRequest(),
            size: AdSize.banner,
            listener: BannerAdListener(
              onAdLoaded: (ad) {
                bannerAds.add(ad as BannerAd); // リストに広告を追加
              },
              onAdFailedToLoad: (ad, err) {
                bannerAds.add(null);
              },
            )).load();
      }
    }
  }

  int _currentBannerAdIndex = 0;
  Widget buildBannerAdWidgetNextAd() {
    if (bannerAds.isEmpty || bannerAds.length < _currentBannerAdIndex) {
      return const SizedBox();
    }
    if (bannerAds.length - 1 == _currentBannerAdIndex) {
      loadBannerAds();
    }
    final ad = bannerAds[_currentBannerAdIndex];
    _currentBannerAdIndex =
        (_currentBannerAdIndex + 1) % bannerAds.length; // 次の広告のインデックスを更新
    if (ad != null) {
      return AdWidget(ad: ad);
    } else {
      return const SizedBox();
    }
  }

  // InterstitialAd Ads
  List<InterstitialAd?> interstitialAds = [];
  void loadInterstitialAds() {
    for (int i = 0; i < 1; i++) {
      if (Platform.isIOS || Platform.isAndroid) {
        // iOS用の処理
        InterstitialAd.load(
            adUnitId: AdHelper.interstitialAdUnitId,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              // Called when an ad is successfully received.
              onAdLoaded: (ad) {
                ad.fullScreenContentCallback = FullScreenContentCallback(
                    onAdShowedFullScreenContent: (ad) {},
                    onAdImpression: (ad) {},
                    onAdFailedToShowFullScreenContent: (ad, err) {
                      ad.dispose();
                    },
                    onAdDismissedFullScreenContent: (ad) {
                      ad.dispose();
                    },
                    onAdClicked: (ad) {});
                debugPrint('$ad loaded.');
                interstitialAds.add(ad);
              },
              // Called when an ad request failed.
              onAdFailedToLoad: (LoadAdError error) {
                debugPrint('InterstitialAd failed to load: $error');
              },
            ));
      }
    }
  }

  int _currentInterstitialAdAdIndex = 0;
  Future<void> interstitialAdShow() async {
    if (DateTime.now().difference(lastInterstitialShown) >
        _interstitialInterval) {
      // 無限再帰防止: 広告がロードされていない場合はreturnのみ
      if (interstitialAds.isEmpty ||
          _currentInterstitialAdAdIndex >= interstitialAds.length) {
        loadInterstitialAds();
        return;
      }
      lastInterstitialShown = DateTime.now();
      int count = await _loadInterAdCount();
      count++;
      // カウントが5の倍数になったらInterstitialAdを表示
      if (count % InterstitialADInterval == 0) {
        if (interstitialAds.isEmpty ||
            interstitialAds.length < _currentInterstitialAdAdIndex) {
          return;
        }
        if (interstitialAds.length - 1 == _currentInterstitialAdAdIndex) {
          loadInterstitialAds();
        }
        final ad = interstitialAds[_currentBannerAdIndex];
        _currentInterstitialAdAdIndex = (_currentInterstitialAdAdIndex + 1) %
            interstitialAds.length; // 次の広告のインデックスを更新
        if (ad != null) {
          ad.show();
        }
      }
      // カウントを保存
      _saveTnterCount(count);
    }
  }

  Future<int> _loadInterAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt('interAdCount') ?? 0;
    return count;
  }

  Future<void> _saveTnterCount(int newCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('interAdCount', newCount);
  }

  /// NativeAdインスタンスを生成して返す（AdWidgetは返さない）
  NativeAd buildNextNativeAd() {
    final ad = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {},
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    );
    ad.load();
    return ad;
  }
}

class NativeAdContainer extends StatefulWidget {
  final double width;
  final double height;
  const NativeAdContainer({required this.width, required this.height, Key? key})
      : super(key: key);

  @override
  State<NativeAdContainer> createState() => _NativeAdContainerState();
}

class _NativeAdContainerState extends State<NativeAdContainer> {
  NativeAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _ad = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() {
            _isLoaded = false;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _ad == null ? const SizedBox.shrink() : AdWidget(ad: _ad!),
    );
  }
}

//=================================================
// Top Title
//=================================================
class ChangeTopTitle with ChangeNotifier {
  Widget _topTitle = const SizedBox();
  Widget _saveTopTitle = const SizedBox(); // Titleに表示するWidget

  Widget get topTitle => _topTitle;
  Widget get saveTopTitle => _saveTopTitle;

  // メッセージを更新するメソッド
  void updateTopTitle(Widget newTitle) {
    _topTitle = newTitle;
    notifyListeners(); // 変更をリスナーに通知
  }

  void updateSaveTopTitle(Widget newTitle) {
    _saveTopTitle = newTitle; // 変更をリスナーに通知
  }
}

//=================================================
// Capture
//=================================================
Future<Uint8List?> captureScreenAndShare(
    GlobalKey repaintBoundaryglobalKey) async {
  try {
    showProgressDialog(openContext);
    RenderRepaintBoundary boundary = repaintBoundaryglobalKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List bytes = byteData!.buffer.asUint8List();

    // 画像を一時的なファイルに保存
    String tempDirPath = await _getTemporaryDirectoryPath();
    final File imageFile = await File('$tempDirPath/image.png').create();
    await imageFile.writeAsBytes(bytes);

    // ダイアログにキャプチャを表示
    Navigator.pop(openContext);
    showDialog(
      context: openContext,
      builder: (BuildContext context) {
        String url = 'https://itunes.apple.com/jp/app/apple-store/id1611900581';
        if (Platform.isAndroid) {
          url = 'https://itunes.apple.com/jp/app/apple-store/id1611900581';
        } else if (Platform.isIOS) {
          url = 'https://itunes.apple.com/jp/app/apple-store/id1611900581';
        }
        return AlertDialog(
          title: const Text('キャプチャの表示'),
          content: Image.memory(bytes),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // キャプチャをシェア
                Share.shareFiles([imageFile.path],
                    subject: 'アプリキャプチャをシェアします', text: url);
                Navigator.of(context).pop();
              },
              child: const Text('共有する'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    // ignore: use_build_context_synchronously
    Navigator.pop(openContext);
    showDialog(
      context: openContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('エラー'),
          content: Text('キャプチャの取得中にエラーが発生しました: $e'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  return null;
}

Future<String> _getTemporaryDirectoryPath() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

//=================================================
// Progress
//=================================================
void showProgressDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // ダイアログの外側をタップしても閉じないようにする
    builder: (BuildContext context) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(), // グルグル（進捗インディケーター）
              SizedBox(height: 20), // 適切な間隔を設定
              Text('Processing...'), // テキストメッセージ
            ],
          ),
        ),
      );
    },
  );
}
