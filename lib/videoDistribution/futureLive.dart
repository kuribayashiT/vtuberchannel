import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../googleCloudFunctions.dart';
import 'videoDistribution.dart';
import '../widgets/cute_loading_widget.dart';

class FutureLive extends StatefulWidget {
  @override
  _FutureLive createState() => _FutureLive();
}

class _FutureLive extends State<FutureLive> with AutomaticKeepAliveClientMixin {
  Set<String> selectedCategories = {};
  List<dynamic> videoList = [];
  bool _isMounted = false;
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  late PushRegisterState myPushState;
  late Future<List<dynamic>> _videoList;

  // ネイティブ広告ウィジェットキャッシュ
  final List<Widget> _nativeAdWidgets = [];
  int _nativeAdIndex = 0;

  Widget videoWidget(Map<String, dynamic> data, DateTime now, double height) {
    return VideoWidget(
      data: data,
      now: now,
      height: height,
      videoUrl: '',
    );
  }

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
      _initNativeAds();
    }
    _videoList = _loadData();
  }

  void _initNativeAds() {
    _nativeAdWidgets.clear();
    for (int i = 0; i < 3; i++) {
      _nativeAdWidgets.add(adHelper.buildNextNativeAdWidget());
    }
    _nativeAdIndex = 0;
    adHelper.loadBannerAds();
  }

  Widget getNextNativeAd({double? width, double? height}) {
    if (_nativeAdWidgets.isEmpty) return const SizedBox.shrink();
    final ad = _nativeAdWidgets[_nativeAdIndex % _nativeAdWidgets.length];
    _nativeAdIndex++;
    if (width != null && height != null) {
      return SizedBox(width: width, height: height, child: ad);
    }
    return ad;
  }

  @override
  void dispose() {
    _isMounted = false;
    myState.removeListener(_onDataUpdated);
    myFavorteState.removeListener(_onDataUpdated);
    myPushState.removeListener(_onDataUpdated);
    adHelper.disposeNativeAds();
    _nativeAdWidgets.clear();
    super.dispose();
  }

  void _onDataUpdated() {
    setState(() {
      _videoList = _loadData();
    });
  }

  Future<List<dynamic>> _loadData() async {
    try {
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getAllVideoData();
      await Future.delayed(const Duration(seconds: 2));
      List<dynamic> videoList = [];
      if (_isMounted) {
        List<dynamic> _videoList = filterByOfficeIndices(
            fetchedCLives,
            Provider.of<SelectedCategorie>(context, listen: false)
                .selectedCategories,
            "video");
        DateTime now = DateTime.now();
        DateTime twoDaysLater = DateTime(now.year, now.month, now.day + 2);
        DateTime twoWeeksLater = DateTime(now.year, now.month, now.day + 14);
        List<dynamic> dataFuture = _videoList.where((data) {
          DateTime comparisonDayUTC = DateTime.parse(data['comparisonDay']);
          DateTime comparisonDayJST = comparisonDayUTC.toLocal();
          return comparisonDayJST.isAfter(twoDaysLater) &&
              comparisonDayJST.isBefore(twoWeeksLater);
        }).toList();
        videoList = dataFuture;
      }
      return videoList;
    } catch (e) {
      return [];
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _videoList = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = calculateItemHeight(context);
    double screenWidth = MediaQuery.of(context).size.width;
    super.build(context);
    DateTime now = DateTime.now();

    int row = 1;
    if (screenWidth > 1000) {
      row = 3;
    } else if (screenWidth > 600) {
      row = 2;
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<dynamic>>(
          future: _videoList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CuteLoadingWidget(
                  message: '配信予定を読み込み中…', color: Colors.blueAccent);
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              List<dynamic> data = snapshot.data!;
              if (data.isEmpty) {
                return const Center(
                  child: CuteEmptyWidget(
                    message: '配信予定の動画はありません',
                    icon: Icon(Icons.video_library,
                        size: 56, color: Colors.blueAccent),
                    color: Colors.blueAccent,
                  ),
                );
              } else {
                try {
                  if (row > 1) {
                    return GridView.builder(
                      physics: const FasterScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: row,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                            child: videoWidget(data[index], now, height));
                      },
                    );
                  } else {
                    return ListView.builder(
                      physics: const FasterScrollPhysics(),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return Column(children: [
                          SizedBox(
                              child: videoWidget(data[index], now, height)),
                          if (!kIsWeb && index % YoutubeNativeADInterval == 0)
                            Align(
                              alignment: Alignment.topCenter,
                              child: getNextNativeAd(
                                  width: screenWidth, height: height),
                            ),
                        ]);
                      },
                    );
                  }
                } catch (e, stackTrace) {
                  print('Error fetching data: $e');
                  print('Stack trace: $stackTrace');
                  return const Center(child: Text('動画の読み込みに失敗しました。'));
                }
              }
            }
          },
        ),
      ),
    );
  }
}
