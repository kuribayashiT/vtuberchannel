import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtuberchannel/main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerView extends StatefulWidget {
  @override
  _YoutubePlayerView createState() => _YoutubePlayerView();
}

double _xOffset = 0;
double _yOffset = 0;
double miniPlayerWidth = 240.0;
double miniPlayerHeght = 135.0;
double fullPlayerWidth = 0;
double fullPlayerHeght = 0;
double _nowPlayerWidth = 0;
double _nowPlayerHeght = 0;

class _YoutubePlayerView extends State<YoutubePlayerView> {
  // 画面のサイズを取得
  Size screenSize = MediaQuery.of(openContext).size;
  bool screenFullFlg = false;
  late YoutubePlayerState _youtubePlayerState;
  @override
  void initState() {
    super.initState();
    // 初期値を画面の中央に設定
    _nowPlayerWidth = miniPlayerWidth;
    _nowPlayerHeght = miniPlayerHeght;
    _youtubePlayerState = YoutubePlayerState();
    fullPlayerWidth = screenSize.width;
    fullPlayerHeght = screenSize.height - 50 - 24;
    _loadPosition();
  }

  @override
  void dispose() {
    super.dispose();
    // _savePosition(_xOffset, _yOffset);
  }

  void _savePosition(double xOffset, double yOffset) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('xOffset', xOffset);
    await prefs.setDouble('yOffset', yOffset);
  }

  void _loadPosition() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double xOffset =
        prefs.getDouble('xOffset') ?? (screenSize.width - miniPlayerWidth) / 2;
    double yOffset =
        prefs.getDouble('yOffset') ?? (screenSize.height - miniPlayerHeght) / 2;
    setState(() {
      _xOffset = xOffset;
      _yOffset = yOffset;
    });
  }

  void _setPosition() async {
    setState(() {
      _xOffset = 0;
      _yOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    IconData iconData = screenFullFlg ? Icons.zoom_in_map : Icons.zoom_out_map;
    return Stack(children: [
      Positioned(
        left: _xOffset,
        top: _yOffset,
        width: _nowPlayerWidth,
        height: _nowPlayerHeght + CupertinoTabBarHight + 16 + 24,
        child: GestureDetector(
          onTap: () {
            // タップ時の処理
            print('Tapped on the draggable view');
          },
          onPanUpdate: (details) {
            if (screenFullFlg) {
              return;
            }
            setState(() {
              _xOffset += details.delta.dx;
              _yOffset += details.delta.dy;
              _savePosition(_xOffset, _yOffset);
            });
          },
          child: ClipRRect(
            // 角丸にするためのClipRRectウィジェットを使用
            borderRadius: BorderRadius.circular(16.0), // 角丸の半径を指定
            child: Container(
              width: _nowPlayerWidth,
              height: _nowPlayerHeght + CupertinoTabBarHight + 16 + 24,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
              ),
              child: Column(
                children: [
                  if (isPlayable)
                    SizedBox(
                      width: _nowPlayerWidth,
                      height: _nowPlayerHeght,
                      child: ChangeNotifierProvider.value(
                        value: _youtubePlayerState,
                        child: Consumer<YoutubePlayerState>(
                          builder: (context, playerState, _) {
                            return YoutubePlayerScaffold(
                              controller: playerState.controller,
                              // showVideoProgressIndicator: true,
                              builder: (context, player) {
                                if (playerState.isChangingVideo) {
                                  // 動画を切り替える際はローディング中のインジケータを表示
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else {
                                  return player;
                                }
                              },
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: _nowPlayerWidth,
                      height: _nowPlayerHeght,
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'この動画は再生できません',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: _nowPlayerWidth,
                    height: CupertinoTabBarHight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: IconButton(
                            iconSize: 32.0,
                            color: Colors.white,
                            icon: Icon(iconData),
                            onPressed: () {
                              _setPosition();
                              setState(() {
                                screenFullFlg = !screenFullFlg; // フラグを反転させる
                                if (screenFullFlg) {
                                  _nowPlayerWidth = fullPlayerWidth;
                                  _nowPlayerHeght = fullPlayerHeght;
                                } else {
                                  _nowPlayerWidth = miniPlayerWidth;
                                  _nowPlayerHeght = miniPlayerHeght;
                                  _loadPosition();
                                }
                              });
                              if (kIsWeb) {
                                // Webプラットフォーム向けの処理をここに書く
                              } else {
                                // iOSやAndroid向けの処理をここに書く
                                adHelper.interstitialAdShow();
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: TextButton(
                            onPressed: () async {
                              var videoId = Provider.of<YoutubePlayerState>(
                                      context,
                                      listen: false)
                                  .videoId;
                              // pushToWebView(
                              //     "https://www.youtube.com/watch?v=$videoId",
                              //     "");
                              setState(() {
                                screenFullFlg = false;
                                // 状態を変更
                                context
                                    .read<YoutubePlayerState>()
                                    .isYoutubePlayerVisible = false;
                                Provider.of<YoutubePlayerState>(context,
                                        listen: false)
                                    .hideOverlay();
                              });
                              final youtubeUrl = Uri.parse(
                                  'https://www.youtube.com/watch?v=$videoId');

                              if (await canLaunchUrl(youtubeUrl)) {
                                await launchUrl(
                                  youtubeUrl,
                                  mode: LaunchMode.inAppBrowserView,
                                );
                              } else {
                                throw 'Could not launch $youtubeUrl';
                              }
                            },
                            child: const Text(
                              'Youtubeで見る',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            iconSize: 32.0,
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                screenFullFlg = false;
                                // 状態を変更
                                context
                                    .read<YoutubePlayerState>()
                                    .isYoutubePlayerVisible = false;
                                Provider.of<YoutubePlayerState>(context,
                                        listen: false)
                                    .hideOverlay();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (screenFullFlg) const SizedBox(height: 24)
                ],
              ),
            ),
          ),
        ),
      )
    ]);
  }
}
