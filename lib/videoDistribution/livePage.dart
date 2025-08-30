// ignore: file_names
import 'package:flutter/material.dart';
import 'package:vtuberchannel/sideMenu.dart';
import '../widgets/cute_loading_widget.dart';
import '../googleCloudFunctions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  _LivePage createState() => _LivePage();
}

class _LivePage extends State<LivePage> {
  Set<String> selectedCategories = {};
  List<dynamic> liveList = [];
  bool isFavorite = false;
  late SelectedCategorie myCateState;
  late FavoriteVideoData myFavorteState;
  bool _isMounted = false;
  late Future<List<dynamic>> _liveData;

  @override
  void initState() {
    super.initState();
    myCateState = Provider.of<SelectedCategorie>(context, listen: false);
    myCateState.addListener(_onDataUpdated); // リスナーを登録
    myFavorteState = Provider.of<FavoriteVideoData>(context, listen: false);
    myFavorteState.addListener(_onDataUpdated); // リスナーを登録
    _isMounted = true;
    _liveData = getLiveData();
  }

  @override
  void dispose() {
    _isMounted = false;
    myCateState.removeListener(_onDataUpdated); // リスナーを解除
    myFavorteState.removeListener(_onDataUpdated); // リスナーを解除
    super.dispose();
  }

  void _onDataUpdated() {
    _isMounted = false;
    _refreshData();
  }

  // ★ここを修正★
  Future<List<dynamic>> getLiveData() async {
    try {
      // Providerから選択中のchannelId一覧を取得
      final selectedChannelIds =
          Provider.of<SelectedCategorie>(context, listen: false)
              .allSelectedchannelIds;

      // 2つのAPIを並列取得
      final results = await Future.wait([
        GoogleCloudFunctions.getLiveData(),
        GoogleCloudFunctions.getAllVideoData(),
      ]);
      final List<dynamic> fetchedCLives = results[0];
      final List<dynamic> allVideos = results[1];

      // 選択されたchannelIdのみでフィルタ
      List<Map<String, dynamic>> liveList = fetchedCLives
          .where((e) => selectedChannelIds.contains(e['channelId']))
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      final now = DateTime.now();
      final fiveMinBefore = now.subtract(const Duration(minutes: 5));
      final fiveMinAfter = now.add(const Duration(minutes: 5));

      // allVideosも同様にchannelIdでフィルタ
      final List<Map<String, dynamic>> extraLives = allVideos
          .where((data) => selectedChannelIds.contains(data['channelId']))
          .where((data) {
            final comparisonDayJST =
                DateTime.parse(data['comparisonDay']).toLocal();
            // 前後5分以内
            return comparisonDayJST.isAfter(fiveMinBefore) &&
                comparisonDayJST.isBefore(fiveMinAfter);
          })
          .map<Map<String, dynamic>>((data) => {
                ...Map<String, dynamic>.from(data),
                'concurrent_viewers': '接続数取得中…'
              })
          .where((data) =>
              !liveList.any((d) => d['videoID'] == data['videoID'])) // 重複除外
          .toList();

      liveList.addAll(extraLives);

      return liveList;
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  Future<void> _refreshData() async {
    if (_isMounted) {
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _liveData = getLiveData(); // データを再取得
      });
    } else {
      setState(() {
        _liveData = getLiveData(); // データを再取得
      });
    }
    _isMounted = true;
  }

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

  @override
  Widget build(BuildContext context) {
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
          future: _liveData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CuteLoadingWidget(
                message: '配信中の動画を読み込み中…',
                color: Colors.blueAccent, // Playタブ青系
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              List<dynamic> data = snapshot.data!;
              if (data.isEmpty) {
                // 空のリストでもPullToRefreshが動作するようにする
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height:
                          MediaQuery.of(context).size.height * 0.7, // 画面の7割くらい
                      child: const Center(
                        child: CuteEmptyWidget(
                          message: '配信中の動画はありません',
                          icon: Icon(Icons.live_tv,
                              size: 56, color: Colors.blueAccent),
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                if (row > 1) {
                  return GridView.builder(
                    physics: const FasterScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: row, // 列数を設定
                      crossAxisSpacing: 8.0, // 列間のスペース
                      mainAxisSpacing: 8.0, // 行間のスペース
                    ),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      // Web用のレイアウトを構築する
                      return buildSquareBigLayout(
                          data[index] as Map<String, dynamic>, height);
                    },
                  );
                } else {
                  return ListView.builder(
                    physics: const FasterScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        child: buildSquareLayout(
                            data[index] as Map<String, dynamic>, height),
                      );
                    },
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }

  Widget buildSquareLayout(Map<String, dynamic> data, double height) {
    return InkWell(
      onTap: () {
        Provider.of<YoutubePlayerState>(context, listen: false)
            .isYoutubePlayerVisible = true;
        Provider.of<YoutubePlayerState>(context, listen: false)
            .setVideoId(data["videoID"]);
      },
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 4.0), //(8.0),
        decoration: const BoxDecoration(),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            // ContainerでAspectRatioをラップ
            width: MediaQuery.of(context).size.width, // 画面幅に合わせて設定
            height:
                MediaQuery.of(context).size.width * 9 / 16, // 16:9のアスペクト比を保つ
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: data["thumbnail"],
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(left: 8.0)),
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: data["channelThumbnail"],
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 70,
                      child: Text(
                        data["title"],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data["channelTitle"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14.0),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.online_prediction),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    "同時接続数:" + data["concurrent_viewers"],
                                    style: const TextStyle(fontSize: 14.0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Padding(padding: EdgeInsets.only(right: 8.0)),
                        GestureDetector(
                          child: FutureBuilder<bool>(
                            future: _checkFavoriteStatus(data['videoID']),
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
                                  if (isFavorite) {
                                    await Provider.of<FavoriteVideoData>(
                                            context,
                                            listen: false)
                                        .removeFavoriteVideo(data['videoID']);
                                    showMessage(
                                        openContext, "お気に入り動画から削除しました。");
                                  } else {
                                    await Provider.of<FavoriteVideoData>(
                                            context,
                                            listen: false)
                                        .saveFavoriteVideo(data);
                                    showMessage(openContext, "お気に入り動画に登録しました。");
                                  }
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        const Padding(padding: EdgeInsets.only(right: 8.0)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget buildSquareBigLayout(Map<String, dynamic> data, double height) {
    return InkWell(
      onTap: () {
        Provider.of<YoutubePlayerState>(context, listen: false)
            .isYoutubePlayerVisible = true;
        Provider.of<YoutubePlayerState>(context, listen: false)
            .setVideoId(data["videoID"]);
      },
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 4.0), //(8.0),
        decoration: const BoxDecoration(),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: (MediaQuery.of(context).size.width - 16) / row,
            height: ((MediaQuery.of(context).size.width - 16) / row) * 9 / 16,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: data["thumbnail"],
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(left: 8.0)),
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: data["channelThumbnail"],
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 70,
                      child: Text(
                        data["title"],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data["channelTitle"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14.0),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.online_prediction),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    "同時接続数:" + data["concurrent_viewers"],
                                    style: const TextStyle(fontSize: 14.0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Padding(padding: EdgeInsets.only(right: 8.0)),
                        GestureDetector(
                          child: FutureBuilder<bool>(
                            future: _checkFavoriteStatus(data['videoID']),
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
                                  if (isFavorite) {
                                    await Provider.of<FavoriteVideoData>(
                                            context,
                                            listen: false)
                                        .removeFavoriteVideo(data['videoID']);
                                    showMessage(
                                        openContext, "お気に入り動画から削除しました。");
                                  } else {
                                    await Provider.of<FavoriteVideoData>(
                                            context,
                                            listen: false)
                                        .saveFavoriteVideo(data);
                                    showMessage(openContext, "お気に入り動画に登録しました。");
                                  }
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        const Padding(padding: EdgeInsets.only(right: 8.0)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
