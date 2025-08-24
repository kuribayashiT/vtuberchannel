import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vtuberchannel/main.dart';
import '../googleCloudFunctions.dart';
import '../widgets/cute_loading_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../webView.dart'; // ← WebViewPageをimport
import 'package:provider/provider.dart';
import '../common.dart'; // YoutubePlayerStateが定義されているファイル

class NewsPage extends StatefulWidget {
  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage>
    with AutomaticKeepAliveClientMixin<NewsPage> {
  @override
  bool get wantKeepAlive => true;

  late Future<List<dynamic>> _newsData;

  @override
  void initState() {
    super.initState();
    _newsData = getNewsData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _newsData = getNewsData();
    });
  }

  Future<List<dynamic>> getNewsData() async {
    try {
      final List<dynamic> fetchedCLives =
          await GoogleCloudFunctions.getNewsData();
      return fetchedCLives;
    } catch (e) {
      print('Error fetching data: $e');
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
          onRefresh: _refreshData,
          child: FutureBuilder<List<dynamic>>(
            future: _newsData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CuteLoadingWidget(
                  message: 'ニュースを読み込み中…',
                  color: Colors.red,
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              } else {
                List<dynamic> data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return const CuteEmptyWidget(
                    message: 'ニュースデータの取得に失敗しました（空データ）',
                    icon:
                        Icon(Icons.error_outline, size: 56, color: Colors.red),
                    color: Colors.red,
                  );
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
                      });
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Widget buildNewsLayout(Map<String, dynamic> data) {
    final hasVideo =
        data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty;
    final videoId = hasVideo ? extractYoutubeVideoId(data['videoUrl']) : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Card全体タップ時はWebView遷移
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WebViewPage(
                url: data['url'],
                title: data['title'],
              ),
            ),
          );
        },
        child: Row(
          children: [
            // テキスト部
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: hasVideo ? 20 : 12, // 動画ボタンがある場合は縦パディング拡張
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['channel'] == null ||
                              (data['channel'] is String &&
                                  data['channel'].trim().isEmpty))
                          ? 'ブログ記事'
                          : data['channel'],
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (hasVideo) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          // 「動画でニュースを視聴する」タップ時のみ動画再生
                          if (videoId != null) {
                            Provider.of<YoutubePlayerState>(context,
                                    listen: false)
                                .setVideoId(videoId);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill,
                                  color: Colors.red, size: 18),
                              SizedBox(width: 4),
                              Text('動画でニュースを視聴する',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      data['title'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          _formatLocalTime(data['publishedAt']),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // サムネイル画像（右側）＋動画再生ボタンレイヤー
            if (data['urlToImage'] != null && data['urlToImage'] != "")
              Padding(
                padding: const EdgeInsets.only(
                    right: 12, left: 4, top: 12, bottom: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: data['urlToImage'],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Image.asset(
                          'images/noImage1200300.png',
                          width: 90,
                          height: 90,
                        ),
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

  /// YouTube動画IDを抽出（https://youtu.be/xxxxxx, https://www.youtube.com/watch?v=xxxxxx どちらも対応）
  String? extractYoutubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // youtu.be/xxxxxx
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }
    // youtube.com/watch?v=xxxxxx
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    return null;
  }

  /// 端末ローカルタイムゾーンで日付を表示
  String _formatLocalTime(dynamic publishedAt) {
    if (publishedAt == null) return "";
    DateTime dt;
    if (publishedAt is String) {
      final str = publishedAt;
      if (str.contains('T')) {
        dt = DateTime.parse(str).toLocal();
      } else {
        dt = DateTime.parse(str + 'Z').toLocal();
      }
    } else if (publishedAt is DateTime) {
      dt = publishedAt.toLocal();
    } else {
      return publishedAt.toString();
    }
    return "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
