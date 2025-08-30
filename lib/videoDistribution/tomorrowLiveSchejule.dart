import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../googleCloudFunctions.dart';
import 'videoDistribution.dart';
import '../common.dart';
import '../widgets/cute_loading_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class TomorrowLiveScheduleTab extends StatefulWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<TomorrowLiveScheduleTab> createState() =>
      _TomorrowLiveScheduleTabState();
}

class _TomorrowLiveScheduleTabState extends State<TomorrowLiveScheduleTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> tomorrowData = [];
  List<List<dynamic>> tomorrowHourData = List.generate(24, (_) => []);
  bool isLoading = true;
  bool _isMounted = false;
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  late PushRegisterState myPushState;
  bool showFirstView = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated);
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated);
    myPushState = Provider.of<PushRegisterState>(context, listen: false);
    myPushState.addListener(_onDataUpdated);

    if (!kIsWeb) {
      adHelper.loadBannerAds();
    }
    fetchData();
  }

  // 毎回新しいNativeAdを生成して返す
  Widget getNextNativeAdWidget({double? width, double? height}) {
    return NativeAdContainer(
      width: width ?? double.infinity,
      height: height ?? 320,
    );
  }

  @override
  void dispose() {
    _isMounted = false;
    myState.removeListener(_onDataUpdated);
    myFavorteState.removeListener(_onDataUpdated);
    myPushState.removeListener(_onDataUpdated);
    adHelper.disposeNativeAds();
    super.dispose();
  }

  void _onDataUpdated() {
    fetchData();
  }

  // ★ここを修正★
  Future<void> fetchData() async {
    setState(() => isLoading = true);
    final allData = await GoogleCloudFunctions.getAllVideoData();
    if (!_isMounted) return;
    // Providerから選択中のchannelId一覧を取得
    final selectedChannelIds = myState.allSelectedchannelIds;
    // channelIdでフィルタ
    final videoList = allData
        .where((data) => selectedChannelIds.contains(data['channelId']))
        .toList();
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    // 明日のデータ
    tomorrowData = videoList.where((data) {
      final comparisonDayJST = DateTime.parse(data['comparisonDay']).toLocal();
      return comparisonDayJST.year == tomorrow.year &&
          comparisonDayJST.month == tomorrow.month &&
          comparisonDayJST.day == tomorrow.day;
    }).toList();

    // 時間ごと
    tomorrowHourData = List.generate(24, (_) => []);
    for (var data in tomorrowData) {
      final hour = DateTime.parse(data['comparisonDay']).toLocal().hour;
      tomorrowHourData[hour].add(data);
    }
    setState(() => isLoading = false);
  }

  Future<void> _refreshData() async {
    await fetchData();
  }

  Widget videoWidget(Map<String, dynamic> data, DateTime now, double height) {
    return VideoWidget(
      data: data,
      now: now,
      height: height,
      videoUrl: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    DateTime now = DateTime.now();
    int row = 1;
    if (MediaQuery.of(context).size.width > 1000) {
      row = 3;
    } else if (MediaQuery.of(context).size.width > 600) {
      row = 2;
    }
    double height = calculateItemHeight(context);
    double screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return const CuteLoadingWidget(
        message: '配信予定を読み込み中…',
        color: Colors.blueAccent,
      );
    }

    if (!showFirstView) {
      // 通常リスト表示
      return SafeArea(
        top: true,
        bottom: true,
        child: Scaffold(
          floatingActionButton: Row(
            children: [
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    showFirstView = !showFirstView;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.indigo,
                child: Icon(
                  showFirstView ? Icons.table_rows : Icons.schedule,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (showFirstView)
                FloatingActionButton(
                  onPressed: () {
                    _refreshData();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.indigo,
                  child: const Icon(
                    Icons.refresh,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          body: RefreshIndicator(
            onRefresh: _refreshData,
            child: tomorrowData.isEmpty
                ? const Center(
                    child: CuteEmptyWidget(
                      message: '配信予定の動画はありません',
                      icon: Icon(Icons.video_library,
                          size: 56, color: Colors.blueAccent),
                      color: Colors.blueAccent,
                    ),
                  )
                : (row > 1
                    ? GridView.builder(
                        physics: const FasterScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: row,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                        ),
                        itemCount: tomorrowData.length,
                        itemBuilder: (context, index) {
                          return SizedBox(
                              child: videoWidget(
                                  tomorrowData[index], now, height));
                        },
                      )
                    : ListView.builder(
                        itemCount: tomorrowData.length,
                        physics: const FasterScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Column(children: [
                            SizedBox(
                                child: videoWidget(
                                    tomorrowData[index], now, height)),
                            if (!kIsWeb && index % YoutubeNativeADInterval == 0)
                              Align(
                                alignment: Alignment.topCenter,
                                child: getNextNativeAdWidget(
                                    width: screenWidth, height: height),
                              ),
                          ]);
                        },
                      )),
          ),
        ),
      );
    } else {
      // タブ＋時間別表示
      return SafeArea(
        top: true,
        bottom: true,
        child: DefaultTabController(
          length: 24,
          initialIndex: DateTime.now().hour,
          child: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  child: TabBar(
                    isScrollable:
                        !kIsWeb || MediaQuery.of(context).size.width < 1000,
                    tabs: List.generate(24, (index) {
                      String label = '${index.toString().padLeft(2, '0')}:00';
                      return Tab(text: label);
                    }),
                    labelPadding:
                        kIsWeb && MediaQuery.of(context).size.width > 1000
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(horizontal: 8.0),
                    indicatorColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    physics:
                        kIsWeb ? const NeverScrollableScrollPhysics() : null,
                    children: List.generate(24, (hourIndex) {
                      List<dynamic> dataForHour = tomorrowHourData[hourIndex];
                      if (dataForHour.isEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Center(
                              child: CuteEmptyWidget(
                                message: '配信予定の動画はありません',
                                icon: Icon(Icons.video_library,
                                    size: 56, color: Colors.blueAccent),
                                color: Colors.blueAccent,
                              ),
                            ),
                            if (!kIsWeb)
                              Align(
                                alignment: Alignment.topCenter,
                                child: getNextNativeAdWidget(
                                    width: screenWidth, height: height),
                              ),
                          ],
                        );
                      } else {
                        if (row > 1) {
                          return GridView.builder(
                            physics: const FasterScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: row,
                              crossAxisSpacing: 8.0,
                              mainAxisSpacing: 8.0,
                            ),
                            itemCount: dataForHour.length,
                            itemBuilder: (context, index) {
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
                                if (!kIsWeb &&
                                    index % YoutubeNativeADInterval == 0)
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: getNextNativeAdWidget(
                                        width: 320, height: 320),
                                  ),
                                if (!kIsWeb && index == dataForHour.length - 1)
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
                  ),
                ),
              ],
            ),
            floatingActionButton: Row(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      showFirstView = !showFirstView;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.indigo,
                  child: Icon(
                    showFirstView ? Icons.table_rows : Icons.schedule,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (showFirstView)
                  FloatingActionButton(
                    onPressed: () {
                      _refreshData();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.indigo,
                    child: const Icon(
                      Icons.refresh,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.startFloat,
          ),
        ),
      );
    }
  }
}
