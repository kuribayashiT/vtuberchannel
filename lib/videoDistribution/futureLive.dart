import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../googleCloudFunctions.dart';
import 'videoDistribution.dart';

class FutureLive extends StatefulWidget {
  @override
  _FutureLive createState() => _FutureLive();
}

class _FutureLive extends State<FutureLive> with AutomaticKeepAliveClientMixin {
  Set<String> selectedCategories = {}; // 選択されたカテゴリを保持する変数
  List<dynamic> videoList = [];
  bool _isMounted = false;
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  late PushRegisterState myPushState;
  late Future<List<dynamic>> _videoList;
  Widget videoWidget(Map<String, dynamic> data, DateTime now, double height) {
    return VideoWidget(
      data: data,
      now: now,
      height: height,
      videoUrl: '',
    );
  }

  // KeepAlive関連のコードを追加
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated); // リスナーを登録
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated); // リスナーを登録
    myPushState = Provider.of<PushRegisterState>(context, listen: false);
    myPushState.addListener(_onDataUpdated); // リスナーを登録

    if (kIsWeb) {
    } else {
      // Admob
      adHelper.loadNativeAds();
    }
    _videoList = _loadData();
  }

  @override
  void dispose() {
    _isMounted = false;
    myState.removeListener(_onDataUpdated); // リスナーを解除
    myFavorteState.removeListener(_onDataUpdated); // リスナーを解除
    myPushState.removeListener(_onDataUpdated); // リスナーを解除
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
        // 今日の日付
        DateTime now = DateTime.now();
        // 二日後の日付
        DateTime twoDaysLater = DateTime(now.year, now.month, now.day + 2);
        // 2週間後の日付
        DateTime twoWeeksLater = DateTime(now.year, now.month, now.day + 14);
        List<dynamic> dataFuture = _videoList.where((data) {
          DateTime comparisonDayUTC = DateTime.parse(data['comparisonDay']);
          DateTime comparisonDayJST = comparisonDayUTC.toLocal();

          // 二日後以降＆2週間以内のデータを取得
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
    // // 今日の日付
    DateTime now = DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<dynamic>>(
          future: _videoList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              List<dynamic> data = snapshot.data!;
              if (data.isEmpty) {
                return const Center(child: Text('配信予定の動画はありません'));
              } else {
                try {
                  if (row > 1) {
                    return GridView.builder(
                      physics: const FasterScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: row, // 列数を設定
                        crossAxisSpacing: 8.0, // 列間のスペース
                        mainAxisSpacing: 8.0, // 行間のスペース
                        //childAspectRatio: 3 / 4, // 要素のアスペクト比
                      ),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        // Web用のレイアウトを構築する
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
                          SizedBox(child: videoWidget(data[index], now, height)),
                          if (!kIsWeb)
                            if (index % YoutubeNativeADInterval == 0)
                              Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: screenWidth,
                                  height: height,
                                  child: adHelper
                                      .buildNativeAdWidgetNextAd(), //AdHelper().buildNativeAdWidget(),
                                ),
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
