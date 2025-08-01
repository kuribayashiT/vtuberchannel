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
  Set<String> selectedCategories = {}; // 選択されたカテゴリを保持する変数
  late SelectedCategorie myState;
  late FavoriteVideoData myFavorteState;
  bool _isMounted = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ここに画面が構築された後に実行したい処理を記述します
      debugPrint("WidgetsBinding");
    });
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated); // リスナーを登録
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated); // リスナーを登録
    _isMounted = true;

    if (kIsWeb) {
    } else {
      // Admob
      adHelper.buildNextNativeAdWidget();
    }
    _videoList = _loadData();
  }

  @override
  void dispose() {
    _isMounted = false;
    myState.removeListener(_onDataUpdated); // リスナーを解除
    myFavorteState.removeListener(_onDataUpdated); // リスナーを解除
    // Admob
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
    // 遷移時に呼ばれる関数
    // routeObserverに自身を設定
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
          // 昨日以前のデータを取得
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
    _refreshData;
  }

  @override
  void deactivate() {
    print("call deactivate");
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 今日の日付
    DateTime now = DateTime.now();

    // double height = calculateItemHeight(context);
    double screenWidth = MediaQuery.of(context).size.width;
    if (MediaQuery.of(context).size.width > 1000) {
      row = 3;
    } else if (MediaQuery.of(context).size.width > 600) {
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
                  message: 'アーカイブを読み込み中…', color: Color(0xFF2563EB));
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              List<dynamic> data = snapshot.data!;
              if (data.isEmpty) {
                return CuteEmptyWidget(
                    message: '配信済みの動画はありません',
                    icon: const Icon(Icons.video_library,
                        size: 56, color: Color(0xFF2563EB)),
                    color: const Color(0xFF2563EB));
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
                          SizedBox(
                              child: videoWidget(data[index], now, height)),
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
                  // ignore: unused_catch_stack
                } catch (e, stackTrace) {
                  return CuteEmptyWidget(
                      message: '動画の読み込みに失敗しました',
                      icon: const Icon(Icons.error_outline,
                          size: 56, color: Color(0xFF2563EB)),
                      color: const Color(0xFF2563EB));
                }
              }
            }
          },
        ),
      ),
    );
  }
}
