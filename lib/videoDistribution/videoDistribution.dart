import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtuberchannel/videoDistribution/tomorrowLiveSchejule.dart';
import '../common.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart' as provider;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import 'livePage.dart';
import 'pastLive.dart';
import 'futureLive.dart';
import 'todayLiveSchejule.dart';

// ignore: camel_case_types
class videoDistribution extends StatelessWidget {
  const videoDistribution({Key? key}) : super(key: key);

  //const videoDistribution({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 1, // 最初に表示するタブ
      length: 5, // タブの数
      child: Scaffold(
        appBar: const PreferredSize(
          preferredSize:
              Size.fromHeight(kToolbarHeight), // カスタムAppBarの高さをナビゲーションバーと同じに設定
          child: CustomAppBar(),
        ),
        body: TabBarView(
          physics: kIsWeb ? const NeverScrollableScrollPhysics() : null, // Webの時だけスクロール禁止
          children: [
            Center(
              child: PastLive(),
            ),
            const Center(
              child: LivePage(),
            ),
            Center(
              child: TodayLiveScheduleTab(),
            ),
            Center(
              child: TomorrowLiveScheduleTab(),
            ),
            Center(
              child: FutureLive(),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      bottom: const TabBar(
        isScrollable: true,
        tabs: <Widget>[
          Tab(text: '過去アーカイブ'),
          Tab(text: '配信中'),
          Tab(text: '今日の配信'),
          Tab(text: '明日の配信'),
          Tab(text: '明日以降の配信'),
        ],
      ),
    );
  }
}

// ignore: must_be_immutable
class VideoWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final DateTime now;
  final double height;
  final String videoUrl;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // コンストラクタで初期化
  VideoWidget({
    Key? key, // key パラメータを追加
    required this.data,
    required this.now,
    required this.height,
    required this.videoUrl,
  })  : flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(),
        super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  MyHomePage videoPlayerInstance = const MyHomePage();
  bool isFavorite = false;
  final settingsProvider =
      FutureProvider.autoDispose<List<String>>((ref) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favorites') ?? [];
  });

  bool pushRegi = false;
  // // ignore: unused_field
  // final Offset _position = const Offset(8, 8);

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _checkFavoriteStatus(String videoID) async {
    List<Map<String, dynamic>> favorites =
        await provider.Provider.of<FavoriteVideoData>(context, listen: false)
            .getFavoriteVideos();
    for (Map<String, dynamic> favorite in favorites) {
      if (favorite['videoID'] == videoID) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        return buildSquareLayout(widget.data, widget.now, widget.height);
      },
    );
  }

  // VideoWidget(this.data, this.now, this.height);
  bool isHeartFilled = false;
  Widget buildSquareLayout(
      Map<String, dynamic> data, DateTime now, double height) {
    DateTime comparisonDateTime = DateTime.parse(data["comparisonDay"]);
    bool showButton = comparisonDateTime.isAfter(now);
    bool isTapEnabled = true;
    // double height = calculateItemHeight(context);
    double screenWidth = MediaQuery.of(context).size.width;
    if (MediaQuery.of(context).size.width > 1000) {
      row = 3;
      screenWidth = (MediaQuery.of(context).size.width - 16) / row;
    } else if (MediaQuery.of(context).size.width > 600) {
      row = 2;
      screenWidth = (MediaQuery.of(context).size.width - 16) / row;
    }
    double height = calculateItemHeight(context);
    return FutureBuilder<bool>(
      future: provider.Provider.of<PushRegisterState>(context, listen: false)
          .getInstancepushNotification()
          .checkRegistPushFromVideoId(data["videoID"]),
      builder: (context, snapshot) {
        bool pushRegi = snapshot.data ?? false; // データがない場合はデフォルト値を使用
        return InkWell(
          onTap: () {
            provider.Provider.of<YoutubePlayerState>(context, listen: false)
                .setVideoId(data["videoID"]);
          },
          child: Stack(children: [
            // 通常のリストアイテムのビュー
            SizedBox(
              height: height,
              width: double.infinity,
              child: Container(
                key: GlobalKey(),
                decoration: const BoxDecoration(),
                margin: const EdgeInsets.only(bottom: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          // ContainerでAspectRatioをラップ
                          width: screenWidth, // 画面幅に合わせて設定
                          height: screenWidth * 9 / 16, // 16:9のアスペクト比を保つ
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl: data["thumbnail"],
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Image.asset('images/noImage1200300.png'),
                            ),
                          ),
                        ),
                        if (showButton)
                          Positioned(
                            bottom: 8,
                            child: ClipRect(
                              child: BackdropFilter(
                                key: GlobalKey(),
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 5.0,
                                  sigmaY: 5.0,
                                ),
                                child: Container(
                                    width: 250,
                                    height: 60,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: SwitchListTile(
                                      value: pushRegi,
                                      activeColor: Colors.blueAccent,
                                      inactiveTrackColor: Colors.white,
                                      inactiveThumbColor: Colors.blueAccent,
                                      trackOutlineColor:
                                          const WidgetStatePropertyAll(
                                              Colors.transparent),
                                      title: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // テキスト
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              const SizedBox(width: 8.0),
                                              Icon(
                                                pushRegi
                                                    ? Icons.notifications
                                                    : Icons.notifications_none,
                                                color: Colors.blueAccent,
                                              ),
                                              const SizedBox(width: 4.0),
                                              const Text(
                                                'Push通知',
                                                style: TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16.0,
                                                ),
                                              ), // アイコンとテキストの間隔
                                              // アイコン
                                            ],
                                          ),
                                          const SizedBox(
                                              height: 4.0), // １行目と２行目の間隔
                                          // ２行目のテキスト
                                          Text(
                                            convertToJapanDayTime(
                                                data["comparisonDay"]),
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.0,
                                            ),
                                            textAlign: TextAlign.start,
                                          ),
                                        ],
                                      ),
                                      onChanged: (bool value) async {
                                        if (!kIsWeb) {
                                          if (!isTapEnabled) {
                                            return;
                                          } else {
                                            await _handleTap(data);
                                            setState(() {
                                              isTapEnabled = true;
                                              // 他の処理もここで行う
                                            });
                                          }
                                        } else {
                                          await _handleTapWeb(data);
                                        }
                                      },
                                    )),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(left: 8.0)),
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: data["channelThumbnail"],
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 70,
                                child: Text(
                                  data["title"],
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data["channelTitle"],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 14.0),
                                        ),
                                        Text(
                                          convertToJapanDayTime(
                                              data["comparisonDay"]),
                                          style:
                                              const TextStyle(fontSize: 14.0),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.only(right: 8.0)),
                                  GestureDetector(
                                    // onTap: () async {
                                    //   // ボタンのタップ時の処理
                                    // },
                                    child: FutureBuilder<bool>(
                                      future:
                                          _checkFavoriteStatus(data['videoID']),
                                      builder: (context, snapshot) {
                                        final bool isFavorite =
                                            snapshot.data ?? false;
                                        return IconButton(
                                          icon: AnimatedContainer(
                                            width: 32,
                                            height: 32,
                                            duration:
                                                const Duration(seconds: 1),
                                            transform: Matrix4.diagonal3Values(
                                                1, 1, 1),
                                            child: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFavorite
                                                  ? Colors.red
                                                  : null,
                                            ),
                                          ),
                                          onPressed: () async {
                                            if (isFavorite) {
                                              await provider.Provider.of<
                                                          FavoriteVideoData>(
                                                      context,
                                                      listen: false)
                                                  .removeFavoriteVideo(
                                                      data['videoID']);
                                              showMessage(openContext,
                                                  "お気に入り動画から削除しました。");
                                            } else {
                                              await provider.Provider.of<
                                                          FavoriteVideoData>(
                                                      context,
                                                      listen: false)
                                                  .saveFavoriteVideo(data);
                                              showMessage(openContext,
                                                  "お気に入り動画に登録しました。");
                                            }
                                            // ボタンの表示を更新するためにsetStateを呼び出す
                                            setState(() {});
                                          },
                                          splashColor:
                                              Colors.black, // Rippleエフェクトの色を設定
                                          // highlightColor: Colors.blue, // Rippleエフェクトの色を設定
                                        );
                                      },
                                    ),
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.only(right: 8.0)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ]),
        );
      },
    );
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void> _handleTap(Map<String, dynamic> data) async {
    if (!pushRegi) {
      var status = await Permission.notification.status;
      if (status.isDenied || status == PermissionStatus.permanentlyDenied) {
        // ignore: use_build_context_synchronously
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) {
            return SimpleDialog(
              title: const Text(
                  "この機能を使用するには、設定アプリにて「通知を許可」に設定頂いたのち、再度アプリを開き直していただく必要があります。"),
              children: [
                SimpleDialogOption(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: const Text("設定アプリを起動する"),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("何もしないで閉じる"),
                ),
              ],
            );
          },
        );
      } else {
        // Push通知を設定
        pushRegi = true;
        // ignore: use_build_context_synchronously
        await provider.Provider.of<PushRegisterState>(context, listen: false)
            .getInstancepushNotification()
            .registerMessage(data);
        // ignore: use_build_context_synchronously
        showMessage(openContext, "Push通知を登録しました");
      }
    } else {
      // Push通知を取り消し
      pushRegi = false;
      await provider.Provider.of<PushRegisterState>(context, listen: false)
          .getInstancepushNotification()
          .removeNotification(data["videoID"]);
      // ignore: use_build_context_synchronously
      showMessage(openContext, "Push通知を取り消しました.");
    }

    // 非同期処理が終わった後にUIを更新
    setState(() {});
  }

  Future<void> _handleTapWeb(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text(
              "この機能を使用するには、アプリ版をご利用ください。（Androidアプリは準備中です。）"),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                const String appStoreUrl = 'https://apps.apple.com/jp/app/id1611900581';
                if (await canLaunch(appStoreUrl)) {
                  await launch(appStoreUrl);
                } else {
                  throw 'Could not launch $appStoreUrl';
                }
              },
              child: const Text("iOSアプリをインストールする"),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text("何もしないで閉じる"),
            ),
          ],
        );
      },
    );
  }

  void showMessage(BuildContext context, String msg) {
    CustomToast.showToast(context, msg);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
