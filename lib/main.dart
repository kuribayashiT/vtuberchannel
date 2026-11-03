import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:vtuberchannel/Chat/ThreadListPage.dart';
import 'package:vtuberchannel/firebase_options.dart';
import 'favorite_screen.dart';
import 'youtubeplayer.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'eventCalendar.dart';
import 'package:flutter/cupertino.dart';
import 'package:vtuberchannel/option/appInfo.dart';
import 'package:vtuberchannel/option/oshirase.dart';
import 'package:vtuberchannel/option/pushSetting.dart';
import 'package:vtuberchannel/option/setting.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../webView.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:provider/provider.dart';
import 'common.dart';
import 'videoDistribution/videoDistribution.dart';
import 'news/news.dart';
import 'ranking.dart';
import 'vtuberList.dart';
import './sideMenu.dart';

// import 'dart:html' as html;

Widget topTitle = const SizedBox();
double CupertinoTabBarHight = 0.0;
int YoutubeNativeADInterval = 7;
int InterstitialADInterval = 50;
final AdHelper adHelper = AdHelper(maxNativeAds: 3);
// ignore: prefer_typing_uninitialized_variables
var openContext;
bool appLaunchByPushTapFlg = false;
Map<String, dynamic> notificationDataAppLaunchByPushTap = {};
String titleAppLaunchByPushTap = "";
String thumbnailUrlAppLaunchByPushTap = "";
String videoIdAppLaunchByPushTap = "";
bool favolitePageFlgChenge = false; // グローバルなフラグ
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values);

  MobileAds.instance.initialize();
  if (kIsWeb) {
    // Webプラットフォーム向けの処理をここに書く
    // アプリの初期化
    WidgetsFlutterBinding.ensureInitialized();

    // スプラッシュ画面を非表示にする
    // html.document.getElementById('splash')?.remove();

    await initializeDateFormatting('ja_JP').then(
      (_) {
        runApp(MyApp(""));
      },
    );
  } else {
    // iOSやAndroid向けの処理をここに書く
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // await Firebase.initializeApp();

    // pushInstance
    var pushInstance = pushNotification();
    await pushInstance.init();

    var details = await pushInstance.flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();

    // Local Pushの監視
    // pushInstance.checkForLocalPushNotifications();
    if (details != null) {
      final payload = details.notificationResponse?.payload;
      // 空文字なら何もしない
      if (payload == null || payload.isEmpty) {
        await initializeDateFormatting('ja_JP').then(
          (_) {
            runApp(MyApp(""));
          },
        );
      } else {
        await initializeDateFormatting('ja_JP').then(
          (_) {
            runApp(MyApp(payload));
          },
        );
      }
    } else {
      await initializeDateFormatting('ja_JP').then(
        (_) {
          runApp(MyApp(""));
        },
      );
    }
  }
}

class MyApp extends StatelessWidget {
  //const MyApp({super.key});
  final String payload;
  MyApp(this.payload);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<YoutubePlayerState>(
          create: (context) => YoutubePlayerState(),
        ),
        ChangeNotifierProvider<FavoriteVideoData>(
          create: (context) => FavoriteVideoData(),
        ),
        ChangeNotifierProvider<SelectedCategorie>(
          create: (context) => SelectedCategorie(),
        ),
        ChangeNotifierProvider<PushRegisterState>(
          create: (context) => PushRegisterState(),
        ),
        ChangeNotifierProvider<ChangeTopTitle>(
          create: (context) => ChangeTopTitle(),
        )
      ],
      child: MaterialApp(
        navigatorObservers: [routeObserver],
        home: MyHomePage(payload: payload),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String? payload;
  const MyHomePage({Key? key, this.payload}) : super(key: key);

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, RouteAware {
  final AppLifecycleObserver appLifecycleObserver = AppLifecycleObserver();
  late CupertinoTabController _tabController;
  late ChangeTopTitle mTitleState;
  String? oldOshiraseJson;
  double xPosition = 0.0;
  double yPosition = 0.0;
  final GlobalKey _globalKey = GlobalKey();
  final GlobalKey repaintBoundaryglobalKey = GlobalKey();
  late YoutubePlayerState _youtubePlayerState;
  int _selectedIndex = 0;
  List<Widget> _pages = [];
  @override
  void didPopNext() {
    debugPrint("popされて、この画面に戻ってきました!");
  }

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
    _tabController.addListener(_handleTabSelection);
    mTitleState = Provider.of<ChangeTopTitle>(context, listen: false);
    mTitleState.addListener(_handleTopTitleChange); // リスナーを登録
    WidgetsBinding.instance.addObserver(appLifecycleObserver);
    setupFirebaseMessagingListener();
    _pages = [
      videoDistribution(key: _globalKey),
      NewsPage(),
      vtuberList(),
      ranking(),
      ThreadListPage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeCategoriesOrder(context);
    });

    /// Firebase Remote Configの初期化
    FirebaseRemoteConfigService().initRemoteConfig();
    WidgetsBinding.instance.addObserver(this);
    // pushNotification instance = pushNotification();
    _controller = _createWebViewController();

    _youtubePlayerState = YoutubePlayerState();
    fetchOldOshirase();

    if (kIsWeb) {
      // Webプラットフォーム向けの処理をここに書く
    } else {
      // iOSやAndroid向けの処理をここに書く
      adHelper.loadInterstitialAds();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.payload != null && widget.payload != "") {
        showNotificationDialog(widget.payload!);
      }
    });
  }

  void setupFirebaseMessagingListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // 通知データのpayloadを取得
      final payload = message.data['payload'] ?? '';
      if (payload.isNotEmpty) {
        showNotificationDialog(payload);
      }
    });
  }

  Future<void> fetchOldOshirase() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Set<String> _selectedCategories = {};
    _selectedCategories.addAll(prefs.getStringList('selectedCategories') ?? []);
    // ↑この_setSelectedCategoriesはもう使わないので、上2行も不要なら消してOK
    oldOshiraseJson = prefs.getString('oldOshiraseJson');
    fetchRemoteConfig();
  }

  Future<void> fetchRemoteConfig() async {
    try {
      await FirebaseRemoteConfig.instance.fetchAndActivate();
      String jsonData = FirebaseRemoteConfig.instance.getString("noticeJson");
      YoutubeNativeADInterval =
          FirebaseRemoteConfig.instance.getInt("YoutubeNativeADInterval");
      if (YoutubeNativeADInterval == 0) {
        YoutubeNativeADInterval = 5;
      }
      InterstitialADInterval =
          FirebaseRemoteConfig.instance.getInt("IntersticialADInterval");
      if (InterstitialADInterval == 0) {
        InterstitialADInterval = 5;
      }
      Map<String, dynamic> newOshiraseJson =
          Map<String, dynamic>.from(json.decode(jsonData));
      _checkNewOshirase(newOshiraseJson);
      // if (widget.payload != "") {
      //   showNotificationDialog(widget.payload!);
      // }
    } catch (e) {
      print('Error fetching remote config: $e');
      isOshiraseUpdated = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    didReceiveLocalNotificationStream.close();
    mTitleState.removeListener(_handleTopTitleChange);
    _youtubePlayerState.removeListener(_handlePlayerStateChange);
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeObserver(appLifecycleObserver);

    super.dispose();
  }

  void _handleTabSelection() {
    // タブが変更されたときの処理をここに記述
    print('Tab selected: ${_tabController.index}');
    if (kIsWeb) {
      // Webプラットフォーム向けの処理をここに書く
    } else {
      // iOSやAndroid向けの処理をここに書く
      adHelper.interstitialAdShow();
    }
    if (_tabController.index != 2) {
      Provider.of<ChangeTopTitle>(context, listen: false)
          .updateTopTitle(const SizedBox());
    } else {
      Provider.of<ChangeTopTitle>(context, listen: false).saveTopTitle;
      Provider.of<ChangeTopTitle>(context, listen: false).updateTopTitle(
          Provider.of<ChangeTopTitle>(context, listen: false).saveTopTitle);
    }
  }

  void _checkNewOshirase(Map<String, dynamic> newOshiraseJson) {
    if (oldOshiraseJson == null) {
      isOshiraseUpdated = true;
      return;
    }
    String newoshiraseJson = json.encode(newOshiraseJson);
    setState(() {
      if (newoshiraseJson == oldOshiraseJson) {
        isOshiraseUpdated = false;
      } else {
        isOshiraseUpdated = true;
      }
    });
  }

  void _handlePlayerStateChange() {
    setState(() {
      // プレイヤーの状態が変更されたときの処理をここに記述
    });
  }

  void _handleTopTitleChange() {
    // Future.delayedを使用して、setStateの実行を遅延させる
    Future.delayed(Duration.zero, () {
      setState(() {
        if (_selectedIndex == 2) {
        } else {
          Provider.of<ChangeTopTitle>(context, listen: false)
              .updateTopTitle(const SizedBox());
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FlutterAppBadger.removeBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    openContext = context;
    CupertinoTabBarHight = CupertinoTabBar(items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.play_arrow),
        label: 'Play',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.comment),
        label: 'News',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'vtuber',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.forum),
        label: 'Chat',
      )
    ]).preferredSize.height;
    return Consumer<YoutubePlayerState>(
        builder: (context, youtubePlayerState, child) {
      return RepaintBoundary(
          key: repaintBoundaryglobalKey,
          child: Stack(children: [
            // 他のウィジェット
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Scaffold(
                drawer: const SideMenu(),
                drawerEnableOpenDragGesture: false,
                appBar: AppBar(
                  centerTitle: true,
                  title: Consumer<ChangeTopTitle>(
                      builder: (openContext, changeTopTitle, child) {
                    return changeTopTitle.topTitle;
                  }),
                  systemOverlayStyle: const SystemUiOverlayStyle(
                    statusBarBrightness: Brightness.light, // for iOS
                    statusBarIconBrightness: Brightness.dark, // for Android
                  ),
                  scrolledUnderElevation: 0.0,
                  surfaceTintColor: Colors.transparent,
                  // shape: const Border(bottom: BorderSide.none),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Builder(
                    builder: (context) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48, // タップエリアを広げる
                            height: 48,
                            child: IconButton(
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                              icon: const Icon(Icons.rule, size: 30.0),
                            ),
                          ),
                          // if (!kIsWeb) const Spacer(), // 余白を確保
                          // if (!kIsWeb)
                          //   SizedBox(
                          //     width: 8, // 明示的にタップエリアを確保
                          //     height: 48,
                          //     child: IconButton(
                          //       onPressed: () async {
                          //         await captureScreenAndShare(repaintBoundaryglobalKey);
                          //       },
                          //       padding: EdgeInsets.zero, // 余計なパディングをなくす
                          //       constraints: BoxConstraints(), // デフォルトの制約を解除
                          //       icon: const Icon(Icons.camera_alt_outlined, size: 30.0),
                          //     ),
                          //   ),
                        ],
                      );
                    },
                  ),

                  actions: [
                    if (kIsWeb)
                      IconButton(
                        onPressed: () async {
                          const String appStoreUrl =
                              'https://apps.apple.com/jp/app/id1611900581';
                          if (await canLaunch(appStoreUrl)) {
                            await launch(appStoreUrl);
                          } else {
                            throw 'Could not launch $appStoreUrl';
                          }
                        },
                        icon: const Icon(Icons.apple_outlined, size: 28.0),
                      ),
                    IconButton(
                      onPressed: () async {
                        // 画面A
                        favolitePageFlgChenge = true;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FavoriteVideosList(
                              fetchData: fetchData,
                            ),
                          ),
                        ).then((value) {
                          favolitePageFlgChenge = false;
                        });
                      },
                      icon: const Icon(Icons.favorite_sharp,
                          size: 28.0, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => eventCalendar()),
                        );
                      },
                      icon: const Icon(Icons.calendar_month, size: 28.0),
                    ),
                    IconButton(
                        onPressed: () {
                          setting();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => setting()),
                          );
                        },
                        icon: Stack(
                          children: [
                            const Icon(Icons.settings, size: 28.0),
                            if (isOshiraseUpdated)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                  child: const Text(
                                    ' ', // バッジの数字など
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        )),
                  ],
                ),
                extendBodyBehindAppBar: true,
                body: CupertinoTabScaffold(
                  controller: _tabController,
                  tabBar: CupertinoTabBar(
                    currentIndex: _selectedIndex,
                    onTap: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.play_arrow),
                        label: 'Play',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.comment),
                        label: 'News',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person),
                        label: 'vtuber',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.format_list_numbered),
                        label: 'Ranking',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.forum),
                        label: 'Chat',
                      ),
                    ],
                  ),
                  tabBuilder: (BuildContext context, int index) {
                    return CupertinoTabView(
                      builder: (BuildContext context) {
                        return _pages[index];
                      },
                    );
                  },
                ),
              ),
            ),
          ]));
    });
  }

  Future<List<Map<String, dynamic>>> fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? favoriteVideosJson = prefs.getStringList('favorites');
    if (favoriteVideosJson == null) {
      return [];
    }
    List<Map<String, dynamic>> favoriteVideos = favoriteVideosJson.map((json) {
      return jsonDecode(json) as Map<String, dynamic>;
    }).toList();
    return favoriteVideos;
  }
}

Future<void> hideProgressDialog(BuildContext context) async {
  Navigator.of(context).pop(); // ダイアログを閉じる
}

void pushToPushSettingDetail() {
  Navigator.push(
    openContext,
    MaterialPageRoute(
      builder: (context) => const PushSettingDetail(),
    ),
  );
}

void pushToOshirase() {
  Navigator.push(
    openContext,
    MaterialPageRoute(
        builder: (context) => const osirase(), maintainState: false),
  );
}

void pushToAppInfo() {
  Navigator.push(
    openContext,
    MaterialPageRoute(
      builder: (context) => appInfo(),
    ),
  );
}

void pushToTermsOfService() {
  Navigator.push(
    openContext,
    MaterialPageRoute(
        builder: (context) =>
            // ignore: prefer_const_constructors
            WebViewPage(
                key: UniqueKey(),
                url: 'https://www.ios-app-develop.com/vchannel',
                title: "利用規約")),
  );
}

void pushToWebView(String url, String title) {
  if (kIsWeb) {
    // Webの場合はブラウザでURLを開く
    _launchUrl(url);
  } else {
    Navigator.push(
      openContext,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          key: UniqueKey(), // 新しいキーを生成する
          url: url,
          title: title,
        ),
      ),
    );
  }
}

Future<void> _launchUrl(String url) async {
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch $url';
  }
}

class OverlayWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => YoutubePlayerView(),
        ),
      ],
    );
  }
}

//=================================================
// 要リファクタリング箇所　ファイル分割
//=================================================
class FavoriteVideoData with ChangeNotifier {
  List<String> _favorites = []; // 選択されたFavoriteを保持する変数

  List<String> get favorites => _favorites;

  // お気に入り動画情報を保存する関数
  Future<void> saveFavoriteVideo(Map<String, dynamic> videoData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList('favorites') ?? [];
    favorites.add(jsonEncode(videoData));
    await prefs.setStringList('favorites', favorites);
    // notifyListeners();
  }

  // お気に入り動画情報を取得する関数
  Future<List<Map<String, dynamic>>> getFavoriteVideos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList('favorites') ?? [];
    List<Map<String, dynamic>> favoriteVideos = _favorites.map((json) {
      return jsonDecode(json) as Map<String, dynamic>;
    }).toList();
    // notifyListeners();
    return favoriteVideos;
  }

  // お気に入りを解除する関数
  Future<void> removeFavoriteVideo(String videoID) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favoriteVideosJson = prefs.getStringList('favorites') ?? [];
    List<Map<String, dynamic>> favoriteVideos = favoriteVideosJson.map((json) {
      return jsonDecode(json) as Map<String, dynamic>;
    }).toList();
    favoriteVideos.removeWhere((video) => video['videoID'] == videoID);
    List<String> updatedFavoriteVideosJson = favoriteVideos.map((video) {
      return jsonEncode(video);
    }).toList();
    _favorites = updatedFavoriteVideosJson;
    await prefs.setStringList('favorites', updatedFavoriteVideosJson);
    if (favolitePageFlgChenge) {
      notifyListeners();
    }
  }

  // お気に入りを解除する関数
  Future<void> removeFavoriteAllVideo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> updatedFavoriteVideosJson = [];
    _favorites = updatedFavoriteVideosJson;
    await prefs.setStringList('favorites', updatedFavoriteVideosJson);
    if (favolitePageFlgChenge) {
      notifyListeners();
    }
  }
}
//=================================================
// 要リファクタリング箇所　ファイル分割
//=================================================

// late YoutubePlayerController controller;
bool isPlayable = true;

late WebViewController _controller;

WebViewController _createWebViewController() {
  late WebViewController ctrl;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
    ctrl = WebViewController.fromPlatformCreationParams(params);
  } else {
    ctrl = WebViewController();
  }
  ctrl
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
        'Mobile/15E148 Safari/604.1')
    ..setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (NavigationRequest request) {
        final url = request.url;
        if (url.contains('youtube.com') ||
            url.contains('youtu.be') ||
            url.contains('googlevideo.com') ||
            url.contains('ytimg.com') ||
            url.contains('gstatic.com') ||
            url.contains('google.com')) {
          return NavigationDecision.navigate;
        }
        return NavigationDecision.prevent;
      },
      onPageFinished: (String url) {
        ctrl.runJavaScript('''
          (function() {
            var style = document.createElement('style');
            style.textContent = `
              ytm-mobile-topbar-renderer,
              ytm-pivot-bar-renderer,
              ytm-slim-video-action-bar-renderer,
              ytm-section-list-renderer,
              ytm-comments-entry-point-header-renderer,
              ytm-item-section-renderer,
              ytm-button-renderer,
              ytm-like-button-renderer,
              .responsive-container.ytm-watch,
              .slim-video-information-renderer,
              .slim-video-metadata-renderer,
              #player-container-outer { margin:0 !important; padding:0 !important; }
              ytm-app, .page-container, #content {
                background: #000 !important;
              }
            `;
            document.head.appendChild(style);

            function fitPlayer() {
              var player = document.getElementById('player-container-id')
                        || document.querySelector('#movie_player')
                        || document.querySelector('ytm-player')
                        || document.querySelector('.html5-video-container')
                        || document.querySelector('video');
              if (player) {
                player.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:9999!important;background:#000!important;';
              }
              var video = document.querySelector('video');
              if (video) {
                video.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;object-fit:contain!important;z-index:9999!important;background:#000!important;';
                video.setAttribute('playsinline', '');
              }
            }
            fitPlayer();
            setTimeout(fitPlayer, 500);
            setTimeout(fitPlayer, 1500);
          })();
        ''');
      },
    ));
  return ctrl;
}

//bool isYoutubePlayerVisible = false;
class YoutubePlayerState with ChangeNotifier {
  final YoutubeExplode _ytExplode = YoutubeExplode();
  bool _isChangingVideo = false;
  bool get isChangingVideo => _isChangingVideo;

  WebViewController get controller => _controller;

  bool _isYoutubePlayerVisible = false;
  String _videoId = ''; // 追加: 動画のID

  bool get isYoutubePlayerVisible => _isYoutubePlayerVisible;
  String get videoId => _videoId; // 追加: 動画のIDを取得するgetter

  set isYoutubePlayerVisible(bool value) {
    _isYoutubePlayerVisible = value;
    notifyListeners();
  }

  Future<void> setVideoId(String videoId) async {
    _isChangingVideo = true;
    _videoId = videoId;
    isPlayable = true;

    final url = Uri.parse('https://m.youtube.com/watch?v=$videoId');

    if (_overlayEntry == null) {
      showOverlay(openContext);
    } else {
      hideOverlay();
      showOverlay(openContext);
    }
    await _controller.loadRequest(url);
    _isChangingVideo = false;
  }

  OverlayEntry? _overlayEntry;

  void showOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) => OverlayWidget(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<bool> isVideoPlayable(String videoId) async {
    try {
      var video = await _ytExplode.videos.get(videoId);
      // ignore: unnecessary_null_comparison
      return video != null;
    } on VideoUnplayableException catch (e) {
      // Video is unplayable
      print('Video is unplayable: $e');
      return false;
    } catch (e) {
      // Error occurred
      print('Error occurred while checking video: $e');
      return false;
    }
  }
}

class AppLifecycleObserver with WidgetsBindingObserver {
  VoidCallback? onAppResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに移行したときにコールバックを呼び出す
      onAppResumed?.call();
    }
  }
}
