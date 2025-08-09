import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtuberchannel/videoDistribution/tomorrowLiveSchejule.dart';
import '../common.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart' as provider;
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 1, // 最初に表示するタブ
      length: 5, // タブの数
      child: Scaffold(
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: CustomAppBar(),
        ),
        body: TabBarView(
          physics: kIsWeb
              ? const NeverScrollableScrollPhysics()
              : null, // Webの時だけスクロール禁止
          children: [
            Center(child: PastLive()),
            const Center(child: LivePage()),
            Center(child: TodayLiveScheduleTab()),
            Center(child: TomorrowLiveScheduleTab()),
            Center(child: FutureLive()),
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

  VideoWidget({
    Key? key,
    required this.data,
    required this.now,
    required this.height,
    required this.videoUrl,
  })  : flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(),
        super(key: key);

  @override
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

  bool isTapEnabled = true;

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

  bool isHeartFilled = false;
  Widget buildSquareLayout(
      Map<String, dynamic> data, DateTime now, double height) {
    DateTime comparisonDateTime = DateTime.parse(data["comparisonDay"]);
    bool showButton = comparisonDateTime.isAfter(now);
    double screenWidth = MediaQuery.of(context).size.width;
    int row = 1;
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
        bool? pushRegi = snapshot.data;
        bool isLoading = snapshot.connectionState != ConnectionState.done;
        return InkWell(
          onTap: () {
            provider.Provider.of<YoutubePlayerState>(context, listen: false)
                .setVideoId(data["videoID"]);
          },
          child: Stack(children: [
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
                          width: screenWidth,
                          height: screenWidth * 9 / 16,
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
                                      borderRadius: BorderRadius.circular(12)),
                                  child: SwitchListTile(
                                    value: pushRegi ?? false,
                                    activeColor: Colors.blueAccent,
                                    inactiveTrackColor: Colors.white,
                                    inactiveThumbColor: Colors.blueAccent,
                                    trackOutlineColor:
                                        const WidgetStatePropertyAll(
                                            Colors.transparent),
                                    title: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            const SizedBox(width: 8.0),
                                            Icon(
                                              pushRegi == true
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
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4.0),
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
                                    onChanged: (isLoading || !isTapEnabled)
                                        ? null
                                        : (bool value) async {
                                            setState(() {
                                              isTapEnabled = false;
                                            });
                                            try {
                                              if (value) {
                                                await provider.Provider.of<
                                                        PushRegisterState>(
                                                  context,
                                                  listen: false,
                                                )
                                                    .getInstancepushNotification()
                                                    .registerMessage(data);
                                                showMessage(
                                                    context, "Push通知を登録しました");
                                              } else {
                                                await provider.Provider.of<
                                                        PushRegisterState>(
                                                  context,
                                                  listen: false,
                                                )
                                                    .getInstancepushNotification()
                                                    .removeNotification(
                                                        data["videoID"]);
                                                showMessage(
                                                    context, "Push通知を取り消しました");
                                              }
                                              setState(() {});
                                            } catch (e) {
                                              showMessage(
                                                  context, "Push通知の処理に失敗しました");
                                            } finally {
                                              setState(() {
                                                isTapEnabled = true;
                                              });
                                            }
                                          },
                                  ),
                                ),
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
                                            setState(() {});
                                          },
                                          splashColor: Colors.black,
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
    // ...（この関数は未使用なら削除してOK）...
  }

  Future<void> _handleTapWeb(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("この機能を使用するには、アプリ版をご利用ください。（Androidアプリは準備中です。）"),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                const String appStoreUrl =
                    'https://apps.apple.com/jp/app/id1611900581';
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
