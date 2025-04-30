import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import '../common.dart';

class FavoriteVideosList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchData;

  FavoriteVideosList({required this.fetchData});

  @override
  _FavoriteVideosListState createState() => _FavoriteVideosListState();
}

class _FavoriteVideosListState extends State<FavoriteVideosList> {
  late Future<List<Map<String, dynamic>>> _favoriteVideosFuture;
  List<Map<String, dynamic>> _favoriteVideos = [];
  @override
  void initState() {
    super.initState();
    _favoriteVideosFuture = widget.fetchData();
    fetchFavoriteVideos();
  }

  Future<void> fetchFavoriteVideos() async {
    _favoriteVideos = await _favoriteVideosFuture;
  }

  // お気に入りコンテンツを削除する関数
  void _removeFavoriteVideo(String videoId) {
    Provider.of<FavoriteVideoData>(context, listen: false)
        .removeFavoriteVideo(videoId);
    setState(() {
      // favoriteVideos リストから指定された videoId を持つ要素を削除する
      _favoriteVideos.removeWhere((video) => video["videoId"] == videoId);
    });
  }

// お気に入りコンテンツを削除する関数
  void _removeFavoriteAllVideo() {
    Provider.of<FavoriteVideoData>(context, listen: false)
        .removeFavoriteAllVideo();
    setState(() {
      // favoriteVideos リストから指定された videoId を持つ要素を削除する
    _favoriteVideosFuture = widget.fetchData();
      _favoriteVideos = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入り'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, size: 28.0),
            onPressed: () async {
              // ダイアログを表示し、ユーザーの選択を待機する
              bool deleteFavorite = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("お気に入りを全て削除しますか？"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          // 「はい」が選択された場合、true を返す
                          Navigator.of(context).pop(true);
                        },
                        child: const Text("はい"),
                      ),
                      TextButton(
                        onPressed: () {
                          // 「いいえ」が選択された場合、false を返す
                          Navigator.of(context).pop(false);
                        },
                        child: const Text("いいえ"),
                      ),
                    ],
                  );
                },
              );
              // ダイアログの結果に応じて処理を行う
              if (deleteFavorite == true) {
                setState(() {
                  _removeFavoriteAllVideo();
                  fetchFavoriteVideos();
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favoriteVideosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            List<Map<String, dynamic>> favoriteVideos = snapshot.data!;
            if (favoriteVideos.isEmpty) {
              return const Center(child: Text('お気に入りの動画はありません。'));
            } else {
              return ListView.builder(
                itemCount: favoriteVideos.length,
                itemBuilder: (context, index) {
                  //Map<String, dynamic> video = favoriteVideos[index];
                  return SizedBox(
                    child: buildFavoriteList(favoriteVideos[index], index, () {
                      // お気に入りコンテンツを削除する関数をコールバックとして渡す
                      _removeFavoriteVideo(favoriteVideos[index]["videoID"]);
                    }),
                  );
                },
              );
            }
          } else {
            return const Center(child: Text('データなし'));
          }
        },
      ),
    );
  }

  Widget buildFavoriteList(
      Map<String, dynamic> data, int index, VoidCallback onRemove) {
    return GestureDetector(
      onTap: () {
        Provider.of<YoutubePlayerState>(context, listen: false)
            .setVideoId(data['videoID']);
      },
      child: Container(
        width: double.infinity,
        height: 90.0,
        margin: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 160.0,
              height: 90.0,
              margin: const EdgeInsets.only(right: 4.0),
              child: data['thumbnail'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16.0), // 角丸の半径を設定
                      child: CachedNetworkImage(
                        imageUrl: data['thumbnail'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    )
                  : Container(),
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.0, fontWeight: FontWeight.bold),
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 12.0, color: Colors.grey),
                              textAlign: TextAlign.left, // 左寄せ
                            ),
                            Text(
                              convertToJapanDayTime(data["comparisonDay"]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.0, color: Colors.grey),
                              textAlign: TextAlign.left, // 左寄せ
                            ),
                          ])),
                      IconButton(
                        icon: const Icon(Icons.favorite),
                        color: Colors.red,
                        onPressed: () async {
                          // ダイアログを表示し、ユーザーの選択を待機する
                          bool deleteFavorite = await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("お気に入りから削除しますか？"),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      // 「はい」が選択された場合、true を返す
                                      Navigator.of(context).pop(true);
                                    },
                                    child: const Text("はい"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // 「いいえ」が選択された場合、false を返す
                                      Navigator.of(context).pop(false);
                                    },
                                    child: const Text("いいえ"),
                                  ),
                                ],
                              );
                            },
                          );
                          // ダイアログの結果に応じて処理を行う
                          if (deleteFavorite == true) {
                            setState(() {
                              onRemove();
                              _favoriteVideos.removeAt(index);
                            });
                          }
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
