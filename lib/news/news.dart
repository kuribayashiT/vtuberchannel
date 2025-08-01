import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vtuberchannel/main.dart';
import '../common.dart';
import '../googleCloudFunctions.dart';
import '../widgets/cute_loading_widget.dart';
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
                return const CuteLoadingWidget(
                  message: 'ニュースを読み込み中…',
                  color: Color(0xFFEF4444),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                List<dynamic> data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return CuteEmptyWidget(
                    message: 'ニュースデータの取得に失敗しました（空データ）',
                    icon: const Icon(Icons.error_outline,
                        size: 56, color: Color(0xFFEF4444)),
                    color: const Color(0xFFEF4444),
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
    return GestureDetector(
      onTap: () {
        pushToWebView(data['url'], data['title']);
      },
      child: Container(
        width: double.infinity,
        margin:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 13), // マージン拡大
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 0), // 左右余白追加
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFFEE2E2), Color(0xFFFDF2F8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFEF4444).withOpacity(0.13),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // サムネイル画像
            if (data['urlToImage'] != null && data['urlToImage'] != "")
              Padding(
                padding: const EdgeInsets.only(
                    left: 8.0,
                    right: 14.0,
                    top: 14.0,
                    bottom: 14.0), // 画像の左右余白を調整
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: data['urlToImage'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Image.asset(
                        'images/noImage1200300.png',
                        width: 80,
                        height: 80),
                  ),
                ),
              ),
            // テキスト部
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    right: 10.0, top: 10.0, bottom: 10.0), // 右・上下余白を調整
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3), // channel領域をさらに内側・小さく
                      margin:
                          const EdgeInsets.only(bottom: 7, left: 2), // 左に寄せる
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10), // 角丸12→10
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFEF4444).withOpacity(0.13),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        (data['channel'] == null ||
                                (data['channel'] is String &&
                                    data['channel'].trim().isEmpty))
                            ? 'ブログ記事'
                            : data['channel'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.0, // 小さめ
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Text(
                      data['title'],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.0, // 小さめ
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.22,
                        letterSpacing: 0.05,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 15, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          _formatLocalTime(data['publishedAt']),
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 端末ローカルタイムゾーンで日付を表示
  String _formatLocalTime(dynamic publishedAt) {
    if (publishedAt == null) return "";
    DateTime dt;
    if (publishedAt is String) {
      // タイムゾーン情報がなければUTCとしてパース
      final str = publishedAt;
      if (str.contains('T')) {
        // ISO8601形式
        dt = DateTime.parse(str).toLocal();
      } else {
        // タイムゾーン情報なし→UTCとしてパース
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
