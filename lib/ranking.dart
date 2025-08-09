// Package
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'common.dart';
import 'widgets/cute_loading_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/googleCloudFunctions.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import 'package:provider/provider.dart' as provider;

class ranking extends StatefulWidget {
  @override
  _ranking createState() => _ranking();
}

class _ranking extends State<ranking>
    with AutomaticKeepAliveClientMixin<ranking> {
  @override
  bool get wantKeepAlive => true;
  late SelectedCategorie myCateState;

  List<dynamic> youtubeData = [];
  late Future<List<dynamic>> _youtubeData;
  List<dynamic> videoCountData = [];
  late Future<List<dynamic>> _videoCountData;
  // List<dynamic> twitterData = [];
  // late Future<List<dynamic>> _twitterData;
  List<dynamic> weeklyLiveViewData = [];
  late Future<List<dynamic>> _weeklyLiveViewData;

  bool _isRefreshing = false;

  // ScrollControllerを定義
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    myCateState = Provider.of<SelectedCategorie>(context, listen: false);
    myCateState.addListener(_onDataUpdated);
    _youtubeData = getRankingDatayoutube();
    _videoCountData = getRankingDatavideoCount();
    // _twitterData = getRankingDataTwitter();
    _weeklyLiveViewData = getRankingDataWeeklyLiveView();
  }

  @override
  void dispose() {
    myCateState.removeListener(_onDataUpdated);
    _scrollController.dispose(); // ScrollControllerの解放
    super.dispose();
  }

  void _onDataUpdated() {
    setState(() {
      _youtubeData = getRankingDatayoutube();
      _videoCountData = getRankingDatavideoCount();
      // _twitterData = getRankingDataTwitter();
      _weeklyLiveViewData = getRankingDataWeeklyLiveView();
    });
  }

  // スクロールのためのメソッド
  void _scrollToTop() {
    _scrollController.animateTo(
      0.0, // スクロール位置
      duration: Duration(milliseconds: 300), // スクロールの速度
      curve: Curves.easeInOut, // アニメーションのカーブ
    );
  }

  Future<List<dynamic>> fetchRankingData({
    required Future<List<dynamic>> Function() fetchFunction,
    required String dataType,
    required List<dynamic> Function(List<dynamic>, Set<String>, String)
        filterFunction,
  }) async {
    try {
      final fetchedData = await fetchFunction();
      if (fetchedData.isNotEmpty) {
        final selectedCategories =
            Provider.of<SelectedCategorie>(context, listen: false)
                .selectedCategories;

        // List<int> を Set<String> に変換
        final selectedCategorySet =
            selectedCategories.map((index) => index.toString()).toSet();

        return filterFunction(fetchedData, selectedCategorySet, dataType);
      }
      return [];
    } catch (e) {
      print('Error fetching data for $dataType: $e');
      return [];
    }
  }

  Future<List<dynamic>> getRankingDatayoutube() => fetchRankingData(
        fetchFunction: GoogleCloudFunctions.getRankingDatayoutube,
        dataType: "rankingDatayoutube",
        filterFunction: filterByOfficeIndices,
      );

  Future<List<dynamic>> getRankingDatavideoCount() => fetchRankingData(
        fetchFunction: GoogleCloudFunctions.getRankingDatavideoCount,
        dataType: "rankingDatavideoCount",
        filterFunction: filterByOfficeIndices,
      );

  Future<List<dynamic>> getRankingDataTwitter() => fetchRankingData(
        fetchFunction: GoogleCloudFunctions.getRankingDataTwitter,
        dataType: "rankingDataTwitter",
        filterFunction: filterByOfficeIndices,
      );

  Future<List<dynamic>> getRankingDataWeeklyLiveView() => fetchRankingData(
        fetchFunction: GoogleCloudFunctions.getRankingDataWeeklyLiveView,
        dataType: "rankingDataWeeklyLiveViewRanking",
        filterFunction: filterByOfficeIndices,
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: CustomAppBar(),
        // フローティングボタンを追加
        floatingActionButton: FloatingActionButton(
          onPressed: _scrollToTop,
          backgroundColor: Colors.indigo,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(30), // FloatingActionButtonを丸くする
          ),
          child: const Icon(Icons.arrow_upward, color: Colors.white, size: 38),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.endFloat, // 中央に配置
        body: SafeArea(
          // SafeAreaで全体をラップして画面に余白を確保
          top: true,
          bottom: false, // タブバーと重ならないように設定
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    buildWeeklyLiveViewRankingLayoutWrapper(
                        context,
                        _weeklyLiveViewData.then((data) => data
                            .map((e) => e as Map<String, dynamic>)
                            .toList()),
                        'weeklyLiveView'),
                    _buildFutureBuilder(_youtubeData, buildRankingLayout,
                        'youtubeSubscriberCount'),
                    _buildFutureBuilder(
                        _videoCountData, buildRankingLayout, 'videoCount'),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CupertinoTabBar(
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
              label: 'Vtuber',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.format_list_numbered),
              label: 'Ranking',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWeeklyLiveViewRankingLayoutWrapper(BuildContext context,
      Future<List<Map<String, dynamic>>> future, String key) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 6));
    final dateFormat = DateFormat('MM/dd');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0), // 上下に少し余白
          child: Text(
            '${dateFormat.format(sevenDaysAgo)} 〜 ${dateFormat.format(now)}'
            "の同時視聴者数",
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CuteLoadingWidget(
                  message: 'ランキングを読み込み中…',
                  color: Colors.orange,
                );
              } else if (snapshot.hasError) {
                return const CuteEmptyWidget(
                  message: 'ランキングの取得に失敗しました',
                  icon: Icon(Icons.error_outline,
                      size: 56, color: Color(0xFFF59E42)),
                  color: Color(0xFFF59E42),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const CuteEmptyWidget(
                  message: 'ランキングデータがありません',
                  icon: Icon(Icons.leaderboard,
                      size: 56, color: Color(0xFFF59E42)),
                  color: Color(0xFFF59E42),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return buildWeeklyLiveViewRankingLayout(
                      context, snapshot.data![index], key);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFutureBuilder(
    Future<List<dynamic>> futureData,
    Widget Function(Map<String, dynamic>, String) builderFunction,
    String dataType,
  ) {
    return FutureBuilder<List<dynamic>>(
      future: futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isRefreshing) {
          return const CuteLoadingWidget(
            message: 'ランキングを読み込み中…',
            color: Color(0xFFF59E42),
          );
        } else if (snapshot.hasError) {
          return const CuteEmptyWidget(
            message: 'ランキングの取得に失敗しました',
            icon: Icon(Icons.error_outline, size: 56, color: Color(0xFFF59E42)),
            color: Color(0xFFF59E42),
          );
        } else {
          List<dynamic> data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const CuteEmptyWidget(
              message: 'ランキングデータがありません',
              icon: Icon(Icons.leaderboard, size: 56, color: Color(0xFFF59E42)),
              color: Color(0xFFF59E42),
            );
          } else {
            return ListView.builder(
              controller: _scrollController, // ScrollControllerをListViewに設定
              itemCount: data.length,
              itemBuilder: (context, index) {
                return builderFunction(
                    data[index] as Map<String, dynamic>, dataType);
              },
            );
          }
        }
      },
    );
  }

//==============================================
// Youtube登録者/Youtubeビデオ数/Twitterフォロワー数
//==============================================
  Widget buildRankingLayout(Map<String, dynamic> data, String key) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        width: double.infinity,
        height: 82.0,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 80.0,
              height: 80.0,
              margin: const EdgeInsets.only(left: 16.0),
              child: ClipOval(
                child: (data['channelThumbnail'] != null &&
                        (data['channelThumbnail'] as String).trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: data['channelThumbnail'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Image.asset(
                            'images/noImage200200.png',
                            fit: BoxFit.cover),
                      )
                    : Image.asset('images/noImage200200.png',
                        fit: BoxFit.cover),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 2.0),
                  Text(
                    data['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.0, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data[key]?.toString() ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 26.0, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data['office'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                  const SizedBox(height: 2.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//==============================================
// WeeklyLiveViewRanking
//==============================================
Widget buildWeeklyLiveViewRankingLayout(
    BuildContext context, Map<String, dynamic> data, String key) {
  return GestureDetector(
    onTap: () async {
      if (!kIsWeb) {
        provider.Provider.of<YoutubePlayerState>(context, listen: false)
            .setVideoId(data["videoID"]);
      } else {
        if (await canLaunch(
            "https://www.youtube.com/channel/" + data['channelId'])) {
          await launch("https://www.youtube.com/channel/" + data['channelId']);
        } else {}
      }
    },
    child: Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // カードの角丸設定
      ),
      margin: const EdgeInsets.all(4.0), // 外側の余白
      child: Container(
        width: double.infinity,
        height: 138.0,
        margin: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // 上寄せ
          children: [
            Column(
              children: [
                Container(
                  width: 160.0,
                  height: 90.0,
                  margin: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0), // 角丸の設定
                    child: data['thumbnail'] != null
                        ? CachedNetworkImage(
                            imageUrl: data['thumbnail'],
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          )
                        : Container(
                            color: Colors.grey.shade300, // サムネイルがない場合の背景色
                          ),
                  ),
                ),
                const SizedBox(height: 8.0), // ClipRRect と Text の間隔
                Column(
                  children: [
                    Text(
                      data['comparisonDay'] != null
                          ? (() {
                              try {
                                DateTime dateTime =
                                    DateTime.parse(data['comparisonDay']);
                                var japanTime = dateTime.toLocal();
                                return DateFormat('yyyy/MM/dd')
                                    .format(japanTime); // 日付部分
                              } catch (e) {
                                return '無効な日付';
                              }
                            })()
                          : '情報がありません',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      data['comparisonDay'] != null
                          ? (() {
                              try {
                                DateTime dateTime =
                                    DateTime.parse(data['comparisonDay']);
                                var japanTime = dateTime.toLocal();
                                return DateFormat('HH:mm')
                                    .format(japanTime); // 時刻部分
                              } catch (e) {
                                return '無効な時間';
                              }
                            })()
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(width: 8.0), // Column と Expanded の間隔
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    data['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.0, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data["concurrent_viewers"].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 26.0, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data['office'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                  Text(
                    data['channelTitle'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      bottom: const TabBar(
        isScrollable: true,
        tabs: [
          Tab(text: '週間の同時視聴者数'),
          Tab(text: 'YouTube登録者数'),
          Tab(text: 'YouTube動画数'),
          // Tab(text: 'Twitterフォロワー数'),
        ],
      ),
    );
  }

  // PreferredSizeWidget のプロパティを実装
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
