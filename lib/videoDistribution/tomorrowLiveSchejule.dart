import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../googleCloudFunctions.dart';
import 'videoDistribution.dart';
import '../common.dart';
import '../widgets/cute_loading_widget.dart';

bool showTomorrowFirstView = true;

class TomorrowLiveScheduleTab extends StatefulWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  _TomorrowLiveScheduleTabState createState() =>
      _TomorrowLiveScheduleTabState();
}

class _TomorrowLiveScheduleTabState extends State<TomorrowLiveScheduleTab> {
  late Future<List<dynamic>> dataForTomorrow;
  late Future<List<List<dynamic>>> dataForSeparateTomorrow;
  bool _isMounted = false;
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  late PushRegisterState myPushState;
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
    dataForTomorrow = getAllVideoData();
    dataForSeparateTomorrow = getAllVideoSeparateData();
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated);
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated);
    myPushState = Provider.of<PushRegisterState>(context, listen: false);
    myPushState.addListener(_onDataUpdated);

    if (!kIsWeb) {
      adHelper.buildNextNativeAdWidget();
      adHelper.loadBannerAds();
    }
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
    setState(() {
      dataForTomorrow = getAllVideoData();
      dataForSeparateTomorrow = getAllVideoSeparateData();
    });
  }

  Future<void> _refreshData() async {
    // if (showTomorrowFirstView) {
    //   showProgressDialog(context);
    // }
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      dataForTomorrow = getAllVideoData();
      dataForSeparateTomorrow = getAllVideoSeparateData();
    });
  }

  Future<List<dynamic>> getAllVideoData() async {
    try {
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getAllVideoData();
      List<dynamic> dataForTomorrow = [];
      if (_isMounted) {
        final selectedCategories =
            Provider.of<SelectedCategorie>(context, listen: false)
                .selectedCategories;
        final videoList =
            filterByOfficeIndices(fetchedCLives, selectedCategories, "video");
        final now = DateTime.now();
        dataForTomorrow = videoList.where((data) {
          final comparisonDayJST =
              DateTime.parse(data['comparisonDay']).toLocal();
          // 明日の日付と比較
          final tomorrow = now.add(const Duration(days: 1));
          return comparisonDayJST.year == tomorrow.year &&
              comparisonDayJST.month == tomorrow.month &&
              comparisonDayJST.day == tomorrow.day;
        }).toList();
      }
      return dataForTomorrow;
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  Future<List<List<dynamic>>> getAllVideoSeparateData() async {
    try {
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getAllVideoData();
      List<List<dynamic>> dataForHour = List.generate(24, (_) => []);
      if (_isMounted) {
        final selectedCategories =
            Provider.of<SelectedCategorie>(context, listen: false)
                .selectedCategories;
        final videoList =
            filterByOfficeIndices(fetchedCLives, selectedCategories, "video");
        final now = DateTime.now();
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowList = videoList.where((data) {
          final comparisonDayJST =
              DateTime.parse(data['comparisonDay']).toLocal();
          return comparisonDayJST.year == tomorrow.year &&
              comparisonDayJST.month == tomorrow.month &&
              comparisonDayJST.day == tomorrow.day;
        }).toList();
        for (var data in tomorrowList) {
          final hour = DateTime.parse(data['comparisonDay']).toLocal().hour;
          dataForHour[hour].add(data);
        }
      }
      return dataForHour;
    } catch (e) {
      print('Error fetching data: $e');
      return List.generate(24, (_) => []);
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int row = 1;
    if (MediaQuery.of(context).size.width > 1000) {
      row = 3;
    } else if (MediaQuery.of(context).size.width > 600) {
      row = 2;
    }
    double height = calculateItemHeight(context);
    double screenWidth = MediaQuery.of(context).size.width;

    if (!showTomorrowFirstView) {
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
                    showTomorrowFirstView = !showTomorrowFirstView;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.indigo,
                child: Icon(
                  showTomorrowFirstView ? Icons.table_rows : Icons.schedule,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (showTomorrowFirstView)
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _refreshData();
                    });
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
            child: FutureBuilder<List<dynamic>>(
              future: dataForTomorrow,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CuteLoadingWidget(
                      message: '配信予定を読み込み中…', color: Colors.blueAccent);
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  List dataForTomorrow = snapshot.data!;
                  if (dataForTomorrow.isEmpty) {
                    return const Center(
                      child: CuteEmptyWidget(
                        message: '配信予定の動画はありません',
                        icon: Icon(Icons.video_library,
                            size: 56, color: Colors.blueAccent),
                        color: Colors.blueAccent,
                      ),
                    );
                  } else {
                    if (row > 1) {
                      return GridView.builder(
                        physics: const FasterScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: row,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                        ),
                        itemCount: dataForTomorrow.length,
                        itemBuilder: (context, index) {
                          return SizedBox(
                              child: videoWidget(
                                  dataForTomorrow[index], now, height));
                        },
                      );
                    } else {
                      return ListView.builder(
                        itemCount: dataForTomorrow.length,
                        physics: const FasterScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Column(children: [
                            SizedBox(
                                child: videoWidget(
                                    dataForTomorrow[index], now, height)),
                            if (!kIsWeb)
                              if (index % YoutubeNativeADInterval == 0)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: screenWidth,
                                    height: height,
                                    child: adHelper.buildNextNativeAdWidget(),
                                  ),
                                ),
                          ]);
                        },
                      );
                    }
                  }
                }
              },
            ),
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
                  child: FutureBuilder<List<List<dynamic>>>(
                    future: dataForSeparateTomorrow,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CuteLoadingWidget(
                            message: '配信予定を読み込み中…', color: Colors.blueAccent);
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else {
                        List<List<dynamic>> dataForHours = snapshot.data!;
                        if (dataForHours.isEmpty) {
                          dataForHours = List.generate(24, (_) => []);
                        }
                        return TabBarView(
                          physics: kIsWeb
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          children: List.generate(24, (hourIndex) {
                            List<dynamic> dataForHour = dataForHours[hourIndex];
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
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: screenWidth,
                                      height: height,
                                      child: adHelper.buildNextNativeAdWidget(),
                                    ),
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
                                      if (index % YoutubeNativeADInterval == 0)
                                        Align(
                                          alignment: Alignment.topCenter,
                                          child: SizedBox(
                                            width: 320,
                                            height: 320,
                                            child: adHelper
                                                .buildNextNativeAdWidget(),
                                          ),
                                        ),
                                      if (!kIsWeb)
                                        if (index == dataForHour.length - 1)
                                          if (adHelper.bannerAds.isNotEmpty)
                                            Align(
                                              alignment: Alignment.topCenter,
                                              child: SizedBox(
                                                width: adHelper
                                                    .bannerAds[0]!.size.width
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
              ],
            ),
            floatingActionButton: Row(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      showTomorrowFirstView = !showTomorrowFirstView;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.indigo,
                  child: Icon(
                    showTomorrowFirstView ? Icons.table_rows : Icons.schedule,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (showTomorrowFirstView)
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _refreshData();
                      });
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
