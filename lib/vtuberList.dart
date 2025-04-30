import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/sideMenu.dart';
import 'googleCloudFunctions.dart';
import 'package:collection/collection.dart';

class vtuberList extends StatefulWidget {
  @override
  _vtuberList createState() => _vtuberList();
}

class _vtuberList extends State<vtuberList> with TickerProviderStateMixin {
  ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 1.0;
  late Future<List<String>> vtuberList;
  late FavoriteVideoData myFavorteState;
  int currentIndex = 0;
  late SelectedCategorie myState;
  List<String> officeData = [];
  Map<String, dynamic> tabData = {};
  Map<String, dynamic> vtuberDataList = {};
  bool _isMounted = false;
  List<Map<String, dynamic>>? tabs;

  // ignore: unused_field
  late TabController _tabController;
  late Future<void> officeDataFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    getOfficeData();
    myState = Provider.of<SelectedCategorie>(context, listen: false);
    myState.addListener(_onDataUpdated);
    officeDataFuture = getOfficeData();

    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated); // リスナーを登録
    _isMounted = true;
  }

  @override
  void dispose() {
    _isMounted = false;
    _scrollController.dispose();
    myState.removeListener(_onDataUpdated); // リスナーを解除
    myFavorteState.removeListener(_onDataUpdated); // リスナーを解除
    super.dispose();
  }

  void _onDataUpdated() {
    officeDataFuture = getOfficeData();
  }

  Future<void> getOfficeData() async {
    try {
      final Map<String, dynamic> fetchedCategoriesMap =
          await GoogleCloudFunctions.getOfficeData();
      final List<String> fetchedCategories = fetchedCategoriesMap.keys.toList();
      final Map<String, dynamic> _vtuberDataList = fetchedCategoriesMap;

      if (_isMounted) {
        setState(() {
          officeData = fetchedCategories;
          tabData = fetchedCategoriesMap;
          vtuberDataList = _vtuberDataList;
          List<dynamic>? rawList = filterByOfficeVtuber(
              vtuberDataList,
              Provider.of<SelectedCategorie>(context, listen: false)
                  .selectedCategories,
              officeData,
              fetchedCategories);

          // rawListがnullでないことを確認し、List<Map<String, dynamic>>?に変換する
          List<Map<String, dynamic>>? convertedList;
          // 各要素がMap<String, dynamic>であることを確認し、キャストする
          if (rawList.every((element) => element is Map<String, dynamic>)) {
            convertedList = rawList.cast<Map<String, dynamic>>();
          } else {
            // リスト内の要素の型がMap<String, dynamic>でない場合はエラー処理を行うなどします
          }
          tabs = convertedList;
          _tabController = TabController(length: tabs!.length, vsync: this);
          _tabController.addListener(_handleTabChange);
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      // エラーが発生した場合も `_isMounted` を確認してから `setState` を呼ぶ
      if (_isMounted) {
        setState(() {
          // エラーの処理を行う（例: エラーメッセージを表示する）
        });
      }
    }
  }

  void _handleTabChange() {
    // Tabが切り替わったときの処理
    currentIndex = _tabController.index;
    String currentThumbnail = tabs![currentIndex]["channelThumbnail"] ?? "";
    setState(() {
      print('Tab changed: $currentThumbnail');
    });
  }

  void _scrollListener() {
    setState(() {
      // スクロール量に基づいて透明度を設定
      _appBarOpacity = (_scrollController.offset / 200).clamp(0.0, 1.0);
      // print(_appBarOpacity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: officeDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // ローディング中の表示
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            // エラーが発生した場合の表示
            return Text('Error: ${snapshot.error}');
          } else {
            // データが揃った場合の表示
            if (tabs != null && tabs!.isNotEmpty) {
              return Stack(children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                      child: CachedNetworkImage(
                          imageUrl: tabs![_tabController.index]
                                  ["channelThumbnail"] ??
                              "",
                          height:
                              MediaQuery.of(context).size.height, // 縦幅いっぱいに配置
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              Image.asset('images/noImage200200.png')),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black.withOpacity(0.2), // 黒色の半透明
                    width: double.infinity, // 画面全体の幅
                    height: double.infinity, // 画面全体の高さ
                    // 中央に配置するためのアライメント
                    alignment: Alignment.center,
                  ),
                ),
                SafeArea(
                  top: true,
                  bottom: true,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: DefaultTabController(
                      length: tabs!.length, // This is the number of tabs.
                      child: Scaffold(
                        backgroundColor: Colors.transparent,
                        body: NestedScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          headerSliverBuilder:
                              (BuildContext context, bool innerBoxIsScrolled) {
                            // These are the slivers that show up in the "outer" scroll view.
                            return <Widget>[
                              SliverOverlapAbsorber(
                                handle: NestedScrollView
                                    .sliverOverlapAbsorberHandleFor(context),
                                sliver: SliverAppBar(
                                  backgroundColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                  pinned: false,
                                  flexibleSpace: FlexibleSpaceBar(
                                      centerTitle: true,
                                      expandedTitleScale: 1.2,
                                      titlePadding: const EdgeInsets.only(
                                          bottom: 100.0,
                                          right: 16.0,
                                          left: 16.0),
                                      stretchModes: const <StretchMode>[
                                        StretchMode.blurBackground
                                      ],
                                      title: Text(
                                          tabs![_tabController.index]["name"],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.start,
                                          style: const TextStyle(
                                              fontSize: 24.0,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold))),
                                  bottom: PreferredSize(
                                    preferredSize: const Size.fromHeight(0.0),
                                    child: TabBar(
                                      isScrollable: true,
                                      //indicator: const BoxDecoration(),
                                      indicatorColor: Colors.transparent,
                                      dividerColor: Colors.transparent,
                                      controller: _tabController,
                                      tabs:
                                          tabs!.map<Widget>((dynamic dataMap) {
                                        // _tabController.index は現在選択されているタブのインデックスを示します
                                        // index が _tabController.index と一致する場合、選択中の Tab としてデザインを変更します
                                        bool isSelected =
                                            tabs!.indexOf(dataMap) ==
                                                _tabController.index;
                                        return SizedBox(
                                          width: isSelected ? 80.0 : 50.0,
                                          height: isSelected
                                              ? 80.0
                                              : 50.0, // isSelectedの場合、80から120に変更
                                          child: _buildTab(
                                              dataMap: dataMap,
                                              isSelected: isSelected),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  stretch: true,
                                  toolbarHeight: 10,
                                  collapsedHeight: 150,
                                  expandedHeight: 200.0,
                                  forceElevated: true,
                                ),
                              ),
                            ];
                          },
                          body: TabBarView(
                            controller: _tabController,
                            physics: kIsWeb ? const NeverScrollableScrollPhysics() : null, // Webの時だけスクロール禁止
                            children: tabs!
                                .map<Widget>((Map<String, dynamic> dataMap) {
                              String channelThumbnail =
                                  dataMap["channelThumbnail"] ??
                                      ""; // dataMapからサムネイル画像のURLを取得
                              if (MediaQuery.of(context).size.width > 600) {
                                return Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: Builder(
                                    builder: (BuildContext context) {
                                      return CustomScrollView(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        // physics: const NeverScrollableScrollPhysics(),
                                        key: PageStorageKey<String>(
                                            channelThumbnail),
                                        slivers: [
                                          SliverOverlapInjector(
                                            handle: NestedScrollView
                                                .sliverOverlapAbsorberHandleFor(
                                                    context),
                                          ),
                                          SliverPadding(
                                            padding: const EdgeInsets.only(
                                                top: 32.0),
                                            sliver: SliverFixedExtentList(
                                              itemExtent:
                                                  350,
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                (BuildContext context,
                                                    int index) {
                                                  if (index == 1) {
                                                    // ListView.builderのビュー
                                                    return ListView.builder(
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemCount: 1,
                                                      itemBuilder:
                                                          (context, index) {
                                                        return cardVideoPageView(
                                                            dataMap["videos"]);
                                                      },
                                                    );
                                                  } else if (index == 0) {
                                                    // cardVideoPageViewのビューとcarChartPageViewのビューを半分ずつ表示
                                                    return SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                              .size
                                                              .width,
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child:
                                                                _buildTableRow(
                                                              findKeyFromName(
                                                                  dataMap[
                                                                      'office']),
                                                              dataMap['name'] ??
                                                                  '',
                                                              dataMap['birthday'] ??
                                                                  '-',
                                                              dataMap['videoCount'] ??
                                                                  '',
                                                              dataMap['youtubeSubscriberCountTransition']
                                                                      .values
                                                                      .last ??
                                                                  '',
                                                              convertToJapanDayDate(
                                                                  dataMap['createdAt'] ??
                                                                      ''),
                                                              dataMap['channeID'] ??
                                                                  '',
                                                              dataMap['twitterName'] ??
                                                                  '',
                                                              dataMap['name'] ??
                                                                  '',
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: carChartPageView(
                                                                dataMap[
                                                                    "youtubeSubscriberCountTransition"]),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  } else {
                                                    return SizedBox(); // その他の場合は空のビューを返す
                                                  }
                                                },
                                                childCount: 3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              } else {
                                return Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: Builder(
                                    builder: (BuildContext context) {
                                      return CustomScrollView(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        // physics: const NeverScrollableScrollPhysics(),
                                        key: PageStorageKey<String>(
                                            channelThumbnail),
                                        slivers: [
                                          SliverOverlapInjector(
                                            handle: NestedScrollView
                                                .sliverOverlapAbsorberHandleFor(
                                                    context),
                                          ),
                                          SliverPadding(
                                            padding: const EdgeInsets.only(
                                                top: 32.0),
                                            sliver: SliverFixedExtentList(
                                              itemExtent:
                                                  (MediaQuery.of(context)
                                                                  .size
                                                                  .width -
                                                              40) *
                                                          9 /
                                                          16 +
                                                      130,
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                (BuildContext context,
                                                    int index) {
                                                  // indexに基づいて異なるビューを返す
                                                  if (index == 0) {
                                                    // cardVtuberDataView
                                                    return ListView.builder(
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemCount: 1,
                                                      itemBuilder:
                                                          (context, index) {
                                                        return _buildTableRow(
                                                            findKeyFromName(
                                                                dataMap[
                                                                    'office']),
                                                            // dataMap['office'] ??
                                                            //     '',
                                                            dataMap['name'] ??
                                                                '',
                                                            dataMap['birthday'] ??
                                                                '-',
                                                            dataMap['videoCount'] ??
                                                                '',
                                                            dataMap['youtubeSubscriberCountTransition']
                                                                    .values
                                                                    .last ??
                                                                '',
                                                            convertToJapanDayDate(
                                                                dataMap['createdAt'] ??
                                                                    ''),
                                                            dataMap['channeID'] ??
                                                                '',
                                                            dataMap['twitterName'] ??
                                                                '',
                                                            dataMap['name'] ??
                                                                '');
                                                      },
                                                    );
                                                  } else if (index == 2) {
                                                    // インデックス0の場合、cardVideoPageViewを返す
                                                    return cardVideoPageView(
                                                        dataMap["videos"]);
                                                  } else {
                                                    // インデックス1の場合、別のビューを返す
                                                    return carChartPageView(dataMap[
                                                        "youtubeSubscriberCountTransition"]);
                                                  }
                                                },
                                                childCount: 3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              }
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]);
            } else {
              // vtuberDataListが初期値の場合の処理
              return const Center(
                child: Text("No data available"), // データがない場合のメッセージなど
              );
            }
          }
        });
  }

  // ===============================
  // 文字データ表示用
  // ===============================
  Widget _buildTableRow(
      String office,
      String name,
      String birthday,
      String videoCount,
      String registNum,
      String createDate,
      String channelID,
      String twitterName,
      String vtuberName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = kIsWeb;
        final containerHeight = isWeb ? constraints.maxHeight : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: Row(
                children: [
                  Icon(Icons.text_snippet, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Data',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
              child: Card(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 10,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildTableCell('事務所名', office),
                  _buildTableCell('名前', name),
                  _buildTableCell('誕生日', birthday),
                  _buildTableCell('登録者数', registNum),
                  _buildTableCell('YouTube開設日', createDate),
                  _buildTableCell('動画数', videoCount),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Center(
                          child: _buildTableYoutubeLinkCell('YouTubeへ', channelID, vtuberName)),
                      Center(
                          child: _buildTableTwitterLinkCell('へ', twitterName, vtuberName)),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildTableCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8), // 左右の文字列の間に８pxのマージンを追加
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis, // オーバーフロー時の挙動を設定
              textAlign: TextAlign.right, // 右寄せに設定
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableYoutubeLinkCell(
      String label, String channelID, String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          pushToWebView("https://www.youtube.com/channel/$channelID", name);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0), // 角丸のボタン風
            color: Colors.redAccent.withOpacity(0.8), // 背景色を青に設定
          ),
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 8.0), // 上下に8pxのパディングを追加
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // アイコンと文字列を中央寄せに設定
            children: [
              const Icon(Icons.play_arrow,
                  color: Colors.white, size: 20), // アイコンを追加
              const SizedBox(width: 0), // アイコンとラベルの間に8pxの間隔を空ける
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white, // 文字色を白に設定
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableTwitterLinkCell(
      String label, String twitterlID, String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          pushToWebView("https://twitter.com/$twitterlID", name);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0), // 角丸のボタン風
            color: Colors.blueAccent.withOpacity(0.8), // 背景色を青に設定
          ),
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 8.0), // 上下に8pxのパディングを追加
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // アイコンと文字列を中央寄せに設定
            children: [
              Image.asset(
                'images/twitterLogo.png', // 画像のパス
                color: Colors.white, // アイコンの色
                width: 20, // アイコンの幅
                height: 20, // アイコンの高さ
              ),
              const SizedBox(width: 0), // アイコンとラベルの間に8pxの間隔を空ける
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white, // 文字色を白に設定
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================
  // Video表示用
  // ===============================
  Widget cardVideoPageView(Map<String, dynamic> videos) {
    List<MapEntry<String, dynamic>> videosList = videos.entries.toList();

    // "publishedAt" の値を日付として解釈し、日付順に並べ替える比較関数を定義
    int comparePublishedAt(
        MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) {
      // 日付文字列を DateTime オブジェクトに変換して比較
      DateTime dateTimeB = DateTime.parse(a.value["publishedAt"]);
      DateTime dateTimeA = DateTime.parse(b.value["publishedAt"]);
      return dateTimeA.compareTo(dateTimeB);
    }

    bool condition = true;
    row = 1;
    if (MediaQuery.of(context).size.width > 600) {
      row = 2;
      condition = false;
    }

    // videosList を日付順に並べ替える
    videosList.sort(comparePublishedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 32), // 左側のマージンを40pxに設定
          child: Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                'Videos',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12), // 上部のマージンを追加
        SizedBox(
          height:
              280, //(MediaQuery.of(context).size.width/row - 40) * 9 / 16 + 60,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: condition
                ? PageView(
                    controller: PageController(viewportFraction: 0.8),
                    children: <Widget>[
                      for (var entry in videosList)
                        Container(
                          margin: const EdgeInsets.only(right: 5, bottom: 20),
                          child: CustomVideoCard(entry),
                        )
                    ],
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: videosList.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 5, bottom: 20),
                        child: CustomVideoCard(videosList[index]),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget carChartPageView(Map<String, dynamic> dataMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = kIsWeb;
        final containerHeight = isWeb ? constraints.maxHeight : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isWeb) const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Youtube Chart',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
            Container(
              height: isWeb ? 290 : 246,//containerHeight ?? 246, // Webの場合に高さを自動調整
              margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 22.0),
              child: CustomCartCard(dataMap),
            ),
          ],
        );
      },
    );
  }

  Tab _buildTab(
      {required Map<String, dynamic> dataMap, required bool isSelected}) {
    String imageUrl = dataMap["channelThumbnail"] ?? ""; // dataMapから画像URLを取得
    if (isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ChangeTopTitle>(context, listen: false).updateTopTitle(
          Opacity(
            opacity: _appBarOpacity,
            child: ClipOval(
              child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: 32,
                  height: 32,
                  errorWidget: (context, url, error) =>
                      Image.asset('images/noImage200200.png')),
            ),
          ),
        );
        Provider.of<ChangeTopTitle>(context, listen: false).updateSaveTopTitle(
          Opacity(
            opacity: _appBarOpacity,
            child: ClipOval(
              child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: 32,
                  height: 32,
                  errorWidget: (context, url, error) =>
                      Image.asset('images/noImage200200.png')),
            ),
          ),
        );
      });
    }
    return Tab(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        // isSelected に基づいて選択中の Tab のデザインを変更
        width: isSelected ? 80.0 : 50.0,
        height: isSelected ? 80.0 : 50.0,
        child: ClipOval(
          child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  Image.asset('images/noImage200200.png')),
        ),
      ),
    );
  }

  Widget buildContent(String channelThumbnail) {
    return Stack(
      children: [
        // Place your UI elements here, using the provided channelThumbnail
        CachedNetworkImage(
            imageUrl: channelThumbnail,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Image.asset('images/noImage200200.png')),
      ],
    );
  }

  String findKeyFromName(String office) {
    for (var entry in vtuberDataList.entries) {
      for (var item in entry.value) {
        if (item['office'] == office) {
          return entry.key;
        }
      }
    }
    return ""; // 見つからない場合はnullを返す
  }
}

class CustomVideoCard extends StatefulWidget {
  final MapEntry<String, dynamic> video; // dataMapフィールドを追加

  const CustomVideoCard(this.video, {super.key});

  @override
  State<StatefulWidget> createState() {
    return CustomVideoCardState(video);
  }
}

class CustomVideoCardState extends State<CustomVideoCard> {
  final MapEntry<String, dynamic> video; // dataMapフィールドを追加
  void showMessage(BuildContext context, String msg) {
    CustomToast.showToast(context, msg);
  }

  Future<bool> _checkFavoriteStatus(String videoID) async {
    List<Map<String, dynamic>> favorites =
        await Provider.of<FavoriteVideoData>(context, listen: false)
            .getFavoriteVideos();
    for (Map<String, dynamic> favorite in favorites) {
      if (favorite['videoID'] == videoID) {
        return true;
      }
    }
    return false;
  }

  bool isFavorite = false;
  CustomVideoCardState(this.video);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 10,
      child: InkWell(
        onTap: () {
          Provider.of<YoutubePlayerState>(context, listen: false)
              .setVideoId(video.key);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                  imageUrl: video.value["thumbnail"],
                  fit: BoxFit.fitWidth,
                  errorWidget: (context, url, error) =>
                      Image.asset('images/noImage1200300.png')),
            ),
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.value["title"], // ここに適切なタイトルのデータを入れる
                              style: const TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              convertToJapanDayTime(
                                  video.value["publishedAt"] ?? ""),
                              style: const TextStyle(fontSize: 10.0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                    ),
                    const Padding(padding: EdgeInsets.only(right: 0.0)),
                    GestureDetector(
                      child: FutureBuilder<bool>(
                        future: _checkFavoriteStatus(video.key),
                        builder: (context, snapshot) {
                          final bool isFavorite = snapshot.data ?? false;
                          return IconButton(
                            icon: AnimatedContainer(
                              width: 32,
                              height: 32,
                              duration: const Duration(seconds: 2),
                              transform: Matrix4.diagonal3Values(1, 1, 1),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite ? Colors.red : null,
                              ),
                            ),
                            onPressed: () async {
                              // 200ミリ秒後にフラグを元に戻す
                              Future.delayed(const Duration(milliseconds: 200),
                                  () {
                                setState(() {
                                  // アニメーションが完了した後にフラグを元に戻す
                                });
                              });

                              if (isFavorite) {
                                await Provider.of<FavoriteVideoData>(context,
                                        listen: false)
                                    .removeFavoriteVideo(video.key);
                                showMessage(openContext, "お気に入り動画から削除しました。");
                              } else {
                                GoogleCloudFunctions functions =
                                    GoogleCloudFunctions();
                                Map<String, dynamic> _video =
                                    await functions.getVideoDataById(video.key);
                                // ignore: use_build_context_synchronously
                                await Provider.of<FavoriteVideoData>(context,
                                        listen: false)
                                    .saveFavoriteVideo(_video);
                                showMessage(openContext, "お気に入り動画に登録しました。");
                              }
                              // ボタンの表示を更新するためにsetStateを呼び出す
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const Padding(padding: EdgeInsets.only(right: 0.0)),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

class CustomCartCard extends StatefulWidget {
  final Map<String, dynamic> dataMap; // dataMapフィールドを追加

  CustomCartCard(this.dataMap); // コンストラクタでdataMapを初期化

  @override
  State<StatefulWidget> createState() {
    // ignore: no_logic_in_create_state
    return CustomCartCardState(dataMap);
  }
}

int chartNum = 0;

class CustomCartCardState extends State<CustomCartCard> {
  final Map<String, dynamic> dataMap; // dataMapフィールドを追加

  CustomCartCardState(this.dataMap); // コンストラクタでdataMapを初期化

  @override
  Widget build(BuildContext context) {
    List<FlSpot> points =
        convertToPricePoints(dataMap); // dataMapをList<PricePoint>に変換
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.only(
            top: 16, left: 8, right: 16), // 上部と左右のマージンを8に設定
        child: Align(
          alignment: Alignment.topCenter,
          child: LineChartWidget(points), // List<PricePoint>を渡す
        ),
      ),
    );
  }

  // Map<String, dynamic>形式のdataMapをList<PricePoint>形式に変換する関数
  List<FlSpot> convertToPricePoints(Map<String, dynamic> dataMap) {
    List<FlSpot> points = [];
    int count = 0;
    chartNum = dataMap.length;
    dataMap.forEach((date, value) {
      if (count >= dataMap.length - 30) {
        // String lastFourDigits = date.substring(date.length - 4);
        // double x = double.parse(lastFourDigits); // 日付（String）をdouble型に変換
        double x = double.parse((count).toString());
        double y = double.parse(
            value.toString()); // 値（dynamic）をStringに変換してからdouble型に変換
        points.add(FlSpot(x, y)); // FlSpotオブジェクトをリストに追加
      }
      count++;
    });
    return points;
  }
}

class LineChartWidget extends StatelessWidget {
  const LineChartWidget(this.points, {Key? key}) : super(key: key);
  final List<FlSpot> points;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: LineChart(LineChartData(
        titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(
              showTitles: false,
            )),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(
              showTitles: false,
            )),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, // サイドタイトルの表示・非表示
                interval: 10000.0, // サイドタイトルの表示間隔
                reservedSize: 42.0, // サイドタイトルの表示エリアの幅
                getTitlesWidget: leftTitleWidgets,
              ),
            ),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: bottomTitleWidgets,
              interval: 7,
            ))),
        lineBarsData: [
          LineChartBarData(
            isCurved: false,
            spots: points,
            color: Colors.redAccent,
            barWidth: 2,
            isStrokeCapRound: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      )),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    var style = TextStyle(
      color: Colors.black.withOpacity(0.8),
      fontWeight: FontWeight.bold,
      fontSize: 12.0,
    );

    DateTime now = DateTime.now();
    int ago = chartNum - value.toInt();
    String formattedDate =
        DateFormat('M/dd').format(now.subtract(Duration(days: ago)));

    Widget text;
    text = Text(formattedDate.toString(),
        style: style, textAlign: TextAlign.right);
    return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Transform.rotate(
          angle: 315 * 3.141592653589793 / 180,
          child: Container(
            // Widgetの内容
            child: text,
          ),
        ));
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  var style = TextStyle(
    color: Colors.black.withOpacity(0.8),
    fontWeight: FontWeight.bold,
    fontSize: 8.0,
  );
  String text = value.toInt().toString();

  return Text(text, style: style, textAlign: TextAlign.left);
}

class PricePoint {
  final double x;
  final double y;

  PricePoint({required this.x, required this.y});
}

List<PricePoint> get pricePoints {
  final data = <double>[11, 20, 10, 6, 5, 3, 5, 5, 30, 5];
  return data
      .mapIndexed(
          ((index, element) => PricePoint(x: index.toDouble(), y: element)))
      .toList();
}
