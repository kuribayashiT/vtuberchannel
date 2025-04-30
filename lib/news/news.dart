import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vtuberchannel/main.dart';
import '../common.dart';
import '../googleCloudFunctions.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NewsPage extends StatefulWidget {
  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage>
    with AutomaticKeepAliveClientMixin<NewsPage> {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> newsData = [];
  late Future<List<dynamic>> _newsData;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _newsData = getNewsData();
  }

  Future<void> _refreshData() async {
    await Future.delayed(Duration(seconds: 2)); // 仮のディレイ、実際にはデータを再取得する処理を追加
    try {
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getNewsData();
      if (mounted) {
        setState(() {
          newsData = fetchedCLives;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      // リフレッシュ終了
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<List<dynamic>> getNewsData() async {
    try {
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getNewsData();
      if (mounted) {
        setState(() {
          newsData = fetchedCLives;
        });
      }
      return fetchedCLives;
    } catch (e) {
      print('Error fetching data: $e');
      // エラーが発生した場合はエラーメッセージを返す
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    double screenWidth = MediaQuery.of(context).size.width;
    return SafeArea(
      top: true,
      bottom: true,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            // リフレッシュ開始
            setState(() {
              _isRefreshing = true;
            });
            await _refreshData();
          },
          child: FutureBuilder<List<dynamic>>(
            future: _newsData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _isRefreshing) {
                return const Center(child: Text('読み込み中'));
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                List<dynamic> data = snapshot.data!;
                if (data.isEmpty) {
                  return const Center(child: Text('閲覧可能なNewsはありません'));
                } else {
                  return ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return Column(children: [
                          SizedBox(
                              child: buildNewsLayout(
                                  data[index] as Map<String, dynamic>)),
                          if (kIsWeb)
                            if (index % YoutubeNativeADInterval == 0)
                              if (adHelper.bannerAds.isNotEmpty)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: screenWidth,
                                    height: 120,
                                    child: adHelper.buildBannerAdWidgetNextAd(),
                                  ),
                                ),
                        ]);
                      }
                      );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Widget buildNewsLayout(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        pushToWebView(data['url'], data['title']);
      },
      child: Container(
        width: double.infinity,
        height: 120.0,
        margin: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            if (data['urlToImage'] != "")
              Container(
                width: 160.0,
                height: 120.0,
                margin: const EdgeInsets.only(right: 8.0),
                child: data['urlToImage'] != null
                    ? CachedNetworkImage(
                        imageUrl: data['urlToImage'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            Image.asset('images/noImage1200300.png'))
                    : Container(),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight, // テキストを右寄せにする
                    child: Text(
                      data['channel'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 70.0, // 3行分の高さを指定
                    ),
                    child: Text(
                      data['title'],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Align(
                    alignment: Alignment.centerRight, // テキストを右寄せにする
                    child: 
                      Text(
                        convertToJapanDayTime(data['publishedAt']),
                        style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
