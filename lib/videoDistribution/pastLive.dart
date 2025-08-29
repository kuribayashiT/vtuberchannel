import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../googleCloudFunctions.dart';
import 'videoDistribution.dart';
import '../common.dart';
import '../widgets/cute_loading_widget.dart';

class PastLive extends StatefulWidget {
  @override
  _PastLive createState() => _PastLive();
}

class _PastLive extends State<PastLive>
    with AutomaticKeepAliveClientMixin, RouteAware {
  Set<String> selectedCategories = {};
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  bool _isMounted = false;
  late Future<List<dynamic>> _videoList;

  // ネイティブ広告ウィジェットキャッシュは廃止

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("WidgetsBinding");
    });
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated);
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated);
    _isMounted = true;

    if (!kIsWeb) {
      adHelper.loadBannerAds();
    }
    _videoList = _loadData();
  }

  // _initNativeAds, getNextNativeAd は不要になったので削除

  @override
  void dispose() {
    _isMounted = false;
    myState.removeListener(_onDataUpdated);
    myFavorteState.removeListener(_onDataUpdated);
    adHelper.disposeNativeAds();
    super.dispose();
  }

  void _onDataUpdated() {
    setState(() {
      _videoList = _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint("didChangeDependencies");
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
        List<dynamic> dataPast = _videoList.where((data) {
          DateTime comparisonDayUTC = DateTime.parse(data['comparisonDay']);
          DateTime comparisonDayJST = comparisonDayUTC.toLocal();
          DateTime now = DateTime.now();
          return comparisonDayJST
              .isBefore(DateTime(now.year, now.month, now.day));
        }).toList();
        videoList = dataPast;
      }
      return videoList;
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _videoList = _loadData();
    });
  }

  @override
  void didUpdateWidget(oldWidget) {
    print("call didUpdateWidget");
    super.didUpdateWidget(oldWidget);
    _refreshData();
  }

  @override
  void deactivate() {
    print("call deactivate");
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    DateTime now = DateTime.now();

    double screenWidth = MediaQuery.of(context).size.width;
    int row = 1;
    if (screenWidth > 1000) {
      row = 3;
    } else if (screenWidth > 600) {
      row = 2;
    }
    double height = calculateItemHeight(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<dynamic>>(
          future: _videoList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CuteLoadingWidget(
                  message: 'アーカイブを読み込み中…', color: Colors.blueAccent);
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ���${snapshot.error}'));
            } else {
              List<dynamic> data = snapshot.data!;
              if (data.isEmpty) {
                return const Center(
                  child: CuteEmptyWidget(
                    message: '配信済みの動画はありません',
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
                              child: SizedBox(
                                width: screenWidth,
                                height: height,
                                child: adHelper.buildNextNativeAdWidget(),
                              ),
                            )
                        ]);
                      },
                    );
                  }
                } catch (e, stackTrace) {
                  return const Center(
                    child: CuteEmptyWidget(
                      message: '配信済みの動画はありません',
                      icon: Icon(Icons.video_library,
                          size: 56, color: Colors.blueAccent),
                      color: Colors.blueAccent,
                    ),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }
}
