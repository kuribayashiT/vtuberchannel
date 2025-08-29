import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vtuberchannel/main.dart';
import '../googleCloudFunctions.dart';
import '../widgets/cute_loading_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../webView.dart';
import 'package:provider/provider.dart';
import '../common.dart';

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
    adHelper.loadNativeAds();
  }

  Future<void> _refreshData() async {
    setState(() {
      _newsData = getNewsData();
      adHelper.loadNativeAds();
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
    final double adHorizontalPadding = 16.0;
    final double adWidth = MediaQuery.of(context).size.width - 32;
    final double adHeight = adWidth * 0.9; // 0.8倍や1.0倍など大きめに

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
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        alignment: Alignment.center,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CuteEmptyWidget(
                                message: 'ニュースデータの取得に失敗しました（空データ）',
                                icon: Icon(Icons.error_outline,
                                    size: 56, color: Colors.red),
                                color: Colors.red,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('再読み込み'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                onPressed: () {
                                  _refreshData();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // 5つに1つ広告を挿入（NativeAd版）
                  final int adInterval = 5;
                  final int adCount = (data.length / adInterval).floor();
                  final int itemCount = data.length + adCount;
                  return ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index > 0 && index % (adInterval + 1) == adInterval) {
                        final nativeAdWidget =
                            adHelper.buildNextNativeAdWidget();
                        if (nativeAdWidget is SizedBox) {
                          return const SizedBox(height: 24);
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Container(
                            width: adWidth,
                            height: adHeight,
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: nativeAdWidget,
                            ),
                          ),
                        );
                      }
                      final int dataIndex =
                          index - (index / (adInterval + 1)).floor();
                      return SizedBox(
                        child: buildNewsLayout(
                            data[dataIndex] as Map<String, dynamic>),
                      );
                    },
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: hasVideo ? 20 : 12,
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

  String? extractYoutubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    return null;
  }

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
