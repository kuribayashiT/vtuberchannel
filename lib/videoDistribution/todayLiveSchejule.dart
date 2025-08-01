import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../googleCloudFunctions.dart';
import 'videoDistribution.dart';
import '../common.dart';
import '../widgets/cute_loading_widget.dart';

bool showTodayFirstView = true;

class TodayLiveScheduleTab extends StatefulWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  _TodayLiveScheduleTabState createState() => _TodayLiveScheduleTabState();
}

class _TodayLiveScheduleTabState extends State<TodayLiveScheduleTab> {
  late Future<List<dynamic>> dataForToday;
  late Future<List<dynamic>> dataForSeparateToday;
  bool _isMounted = false;
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  late PushRegisterState myPushState;
  // Banner広告
  // BannerAd? _bannerAd;
  // NativeAd? _nativeAd;
  ConstrainedBox adContainer =
      ConstrainedBox(constraints: const BoxConstraints());
  Widget videoWidget(Map<String, dynamic> data, DateTime now, double height) {
    return VideoWidget(
      data: data,
      now: now,
      height: height,
      videoUrl: '',
    );
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    dataForToday = getAllVideoData();
    dataForSeparateToday = getAllVideoSeparateData();
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated); // リスナーを登録
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated); // リスナーを登録
    myPushState = Provider.of<PushRegisterState>(context, listen: false);
    myPushState.addListener(_onDataUpdated); // リスナーを登録
    // TODO: Load a banner ad

    if (kIsWeb) {
    } else {
      // Admob
      adHelper.buildNextNativeAdWidget();
      adHelper.loadBannerAds();
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    myState.removeListener(_onDataUpdated); // リスナーを解除
    myFavorteState.removeListener(_onDataUpdated); // リスナーを解除
    myPushState.removeListener(_onDataUpdated); // リスナーを解除
    adHelper.disposeNativeAds();
    super.dispose();
  }

  void _onDataUpdated() {
    _loadData();
    // if (_nativeAd != null) {
    //   _nativeAd?.load();
    // }
  }

  Future<void> _refreshData() async {
    if (showTodayFirstView) {
      showProgressDialog(context);
    }
    await Future.delayed(
        const Duration(seconds: 2)); // 仮のディレイ、実際にはデータを再取得する処理を追加
    await _loadData(); // データを再取得
  }

  Future<void> _loadData() async {
    try {
      if (_isMounted) {
        setState(() {
          if (showTodayFirstView) {
            dataForSeparateToday = getAllVideoSeparateData();
            dataForToday = getAllVideoData();
          } else {
            dataForToday = getAllVideoData();
            dataForSeparateToday = getAllVideoSeparateData();
          }
          if (showTodayFirstView) {
            Navigator.pop(openContext);
          }
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<List<dynamic>> getAllVideoData() async {
    try {
      // ここでデータを取得する処理を実行
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getAllVideoData();
      List<dynamic> dataForToday = [];
      if (_isMounted) {
        List<dynamic> videoList = filterByOfficeIndices(
            fetchedCLives,
            Provider.of<SelectedCategorie>(context, listen: false)
                .selectedCategories,
            "video");
        List.generate(1, (hourIndex) {
          dataForToday = videoList.where((data) {
            DateTime comparisonDayUTC = DateTime.parse(data['comparisonDay']);
            DateTime comparisonDayJST = comparisonDayUTC.toLocal();
            DateTime now = DateTime.now();
            // 今日の日付と比較
            return comparisonDayJST.year == now.year &&
                comparisonDayJST.month == now.month &&
                comparisonDayJST.day == now.day;
          }).toList();
        });
      }
      return dataForToday;
    } catch (e) {
      print('Error fetching data: $e');
      // エラーが発生した場合はエラーメッセージを返す
      return [];
    }
  }

  Future<List<dynamic>> getAllVideoSeparateData() async {
    try {
      // ここでデータを取得する処理を実行
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getAllVideoData();
      List<dynamic> dataForHour = [];
      if (_isMounted) {
        List<dynamic> videoList = filterByOfficeIndices(
            fetchedCLives,
            Provider.of<SelectedCategorie>(context, listen: false)
                .selectedCategories,
            "video");
        List.generate(24, (hourIndex) async {
          List<dynamic> dataForToday = videoList.where((data) {
            DateTime comparisonDayUTC = DateTime.parse(data['comparisonDay']);
            DateTime comparisonDayJST = comparisonDayUTC.toLocal();
            DateTime now = DateTime.now();
            // 今日の日付と比較
            return comparisonDayJST.year == now.year &&
                comparisonDayJST.month == now.month &&
                comparisonDayJST.day == now.day;
          }).toList();
          List<dynamic> _dataForHour = dataForToday.where((data) {
            DateTime comparisonDayUTC = DateTime.parse(data['comparisonDay']);
            DateTime comparisonDayJST = comparisonDayUTC.toLocal();
            return comparisonDayJST.hour == hourIndex;
          }).toList();
          dataForHour.add(_dataForHour);
        });
      }
      return dataForHour;
    } catch (e) {
      print('Error fetching data: $e');
      // エラーが発生した場合はエラーメッセージを返す
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    if (MediaQuery.of(context).size.width > 1000) {
      row = 3;
    } else if (MediaQuery.of(context).size.width > 600) {
      row = 2;
    }
    double height = calculateItemHeight(context);
    double screenWidth = MediaQuery.of(context).size.width;
    // hourIndexに対応するデータを抽出

    Widget body;
    if (!showTodayFirstView) {
      body = RefreshIndicator(
          onRefresh: _refreshData,
          child: FutureBuilder<List<dynamic>>(
            // ここでデータをフェッチするための関数を指定
            future: dataForToday,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CuteLoadingWidget(
                    message: '配信予定を読み込み中…', color: Color(0xFF2563EB));
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                List dataForToday = snapshot.data!;
                if (dataForToday.isEmpty) {
                  return CuteEmptyWidget(
                      message: '配信予定の動画はありません',
                      icon: const Icon(Icons.live_tv,
                          size: 56, color: Color(0xFF2563EB)),
                      color: const Color(0xFF2563EB));
                } else {
                  if (row > 1) {
                    return GridView.builder(
                      physics: const FasterScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: row, // 列数を設定
                        crossAxisSpacing: 8.0, // 列間のスペース
                        mainAxisSpacing: 8.0, // 行間のスペース
                        //childAspectRatio: 3 / 4, // 要素のアスペクト比
                      ),
                      itemCount: dataForToday.length,
                      itemBuilder: (context, index) {
                        // Web用のレイアウトを構築する
                        return SizedBox(
                            child:
                                videoWidget(dataForToday[index], now, height));
                      },
                    );
                  } else {
                    return ListView.builder(
                      itemCount: dataForToday.length,
                      physics: const FasterScrollPhysics(),
                      itemBuilder: (context, index) {
                        return Column(children: [
                          SizedBox(
                              child: videoWidget(
                                  dataForToday[index], now, height)),
                          if (!kIsWeb)
                            if (index % YoutubeNativeADInterval == 0)
                              Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: screenWidth,
                                  height: height,
                                  child: adHelper
                                      .buildNextNativeAdWidget(), //AdHelper().buildNativeAdWidget(),
                                ),
                              ),
                        ]);
                      },
                    );
                  }
                }
              }
            },
          ));
    } else {
      body = DefaultTabController(
        length: 24,
        initialIndex: DateTime.now().hour,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: CustomAppBar(),
          ),
          body: FutureBuilder<List<dynamic>>(
            // ここでデータをフェッチするための関数を指定
            future: dataForSeparateToday,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CuteLoadingWidget(
                    message: '配信予定を読み込み中…', color: Color(0xFF2563EB));
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                List dataForHours = snapshot.data!;
                return TabBarView(
                  physics: kIsWeb
                      ? const NeverScrollableScrollPhysics()
                      : null, // Webの時だけスクロール禁止
                  children: List.generate(24, (hourIndex) {
                    List<dynamic> dataForHour = dataForHours[hourIndex];
                    if (dataForHour.isEmpty) {
                      return Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            CuteEmptyWidget(
                                message: 'この時間の配信予定はまだありません',
                                icon: const Icon(Icons.access_time,
                                    size: 56, color: Color(0xFF2563EB)),
                                color: const Color(0xFF2563EB)),
                            // if (adHelper.nativeAds.isNotEmpty)
                            Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: screenWidth,
                                height: height,
                                child: adHelper.buildNextNativeAdWidget(),
                              ),
                            ),
                          ]);
                    } else {
                      if (row > 1) {
                        return GridView.builder(
                          physics: const FasterScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: row, // 列数を設定
                            crossAxisSpacing: 8.0, // 列間のスペース
                            mainAxisSpacing: 8.0, // 行間のスペース
                            //childAspectRatio: 3 / 4, // 要素のアスペクト比
                          ),
                          itemCount: dataForHour.length,
                          itemBuilder: (context, index) {
                            // Web用のレイアウトを構築する
                            return SizedBox(
                                child: videoWidget(
                                    dataForHour[index], now, height));
                          },
                        );
                      } else {
                        return ListView.builder(
                          itemCount: dataForHour.length,
                          physics: const FasterScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Column(children: [
                              SizedBox(
                                  child: videoWidget(
                                      dataForHour[index], now, height)),
                              if (index % YoutubeNativeADInterval == 0)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: 320,
                                    height: 320,
                                    child: adHelper
                                        .buildNextNativeAdWidget(), //AdHelper().buildNativeAdWidget(),
                                  ),
                                ),
                              if (!kIsWeb)
                                if (index == dataForHour.length - 1)
                                  if (adHelper.bannerAds.isNotEmpty)
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: SizedBox(
                                        width: adHelper.bannerAds[0]!.size.width
                                            .toDouble(),
                                        height: adHelper
                                            .bannerAds[0]!.size.height
                                            .toDouble(),
                                        child: adHelper
                                            .buildBannerAdWidgetNextAd(),
                                      ),
                                    ),
                              if (index == dataForHour.length - 1)
                                const SizedBox(height: 70)
                            ]);
                          },
                        );
                      }
                    }
                  }),
                );
              }
            },
          ),
        ),
      );
    }

    return SafeArea(
      top: true,
      bottom: true,
      child: Scaffold(
        floatingActionButton: Row(
          children: [
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  showTodayFirstView =
                      !showTodayFirstView; // ボタンが押されるたびにViewを切り替える
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(30), // FloatingActionButtonを丸くする
              ),
              backgroundColor: Colors.indigo,
              child: Icon(
                showTodayFirstView
                    ? Icons.table_rows
                    : Icons.schedule, // showTodayFirstViewの状態に応じてアイコンを切り替える
                size: 42, // アイコンのサイズを大きくする
                color: Colors.white, // アイコンの色
              ), // ボタンの背景色
            ), // showTod
            const SizedBox(width: 8), // ボタン間のスペースを設定
            if (showTodayFirstView)
              FloatingActionButton(
                // 左端に配置する追加のフローティングボタン
                onPressed: () {
                  setState(() {
                    _refreshData();
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(30), // FloatingActionButtonを丸くする
                ),
                backgroundColor: Colors.indigo,
                child: const Icon(
                  Icons.refresh, // showTodayFirstViewの状態に応じてアイコンを切り替える
                  size: 42, // アイコンのサイズを大きくする
                  color: Colors.white, // アイコンの色
                ),
              ),
          ],
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.startFloat, // 左端にフローティングボタンを配置する
        body: body,
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      bottom: TabBar(
        isScrollable: !kIsWeb || MediaQuery.of(context).size.width < 1000,
        tabs: List.generate(24, (index) {
          String label = '${index.toString().padLeft(2, '0')}:00';
          return Tab(text: label);
        }),
        labelPadding: kIsWeb && MediaQuery.of(context).size.width > 1000
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 8.0),
      ),
    );
  }
}
