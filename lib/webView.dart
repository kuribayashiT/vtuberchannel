//import 'dart:html';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'dart:ui_web'
    // as ui; // ui_web をインポート// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html; // Webアプリ用のdart:htmlをimport
import 'package:flutter/foundation.dart' show kIsWeb; // kIsWebをimport

/// WebViewアプリの状態を持つStatefulWidget
String webTitle = "";
String nowURL = "";

class WebViewPage extends StatefulWidget {
  final String url; // 追加: WebViewPageに渡すURL
  final String title; // 追加: title
  // コンストラクタでURLを受け取る
  const WebViewPage({Key? key, required this.url, required this.title})
      : super(key: key);

  /// 状態オブジェクトを作成
  @override
  State<WebViewPage> createState() => _WebViewAppState();
}

/// WebViewAppの状態を管理するStateクラス
class _WebViewAppState extends State<WebViewPage> {
  /// WebViewControllerオブジェクト
  late final WebViewController controller;
  bool _showMiniPlayerButton = false;
  String nowVidepID = "";
  // late html.IFrameElement _iframeElement =
  //     html.IFrameElement(); // Webアプリ用のIFrameElement
  // late IFrameElement _iframeElement;

  /// 初期状態を設定
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      controller = WebViewController()
        ..loadRequest(
          Uri.parse(widget.url),
        );
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setNavigationDelegate(
        NavigationDelegate(//この中で色々設定する
            onPageStarted: (String url) async {
          setState(() {
            _showMiniPlayerButton =
                url.startsWith('https://m.youtube.com/watch?v=');
            //_showMiniPlayerButton = change.url!.startsWith('https://www.youtube.com/watch?v=');
            if (_showMiniPlayerButton) {
              nowVidepID = extractVideoId(url);
            }
          });
        }, onUrlChange: (UrlChange change) async {
          setState(() {
            _showMiniPlayerButton =
                change.url!.startsWith('https://m.youtube.com/watch?v=');
            //_showMiniPlayerButton = change.url!.startsWith('https://www.youtube.com/watch?v=');
            if (_showMiniPlayerButton) {
              nowVidepID = extractVideoId(change.url!);
            }
          });
        }, onPageFinished: (String url) async {
          setState(() {
            _showMiniPlayerButton =
                url.startsWith('https://m.youtube.com/watch?v=');
            //_showMiniPlayerButton = change.url!.startsWith('https://www.youtube.com/watch?v=');
            if (_showMiniPlayerButton) {
              nowVidepID = extractVideoId(url);
            }
          });
        }),
      );
    } else {
      // // registerElement();
      // _iframeElement = IFrameElement()
      //   ..style.border = 'none';
      // ui.platformViewRegistry.registerViewFactory(
      //   'iframeElement',
      //   (int viewId) => _iframeElement);
      // _updateIframeUrl(widget.url);
    }

    webTitle = widget.title;
  }

  // Widget の build メソッド内で呼び出してください
  // void registerElement() {
  //   html.IFrameElement iframeElement = html.IFrameElement();
  //   iframeElement.src = widget.url;
  //   iframeElement.style.border = 'none';
  //   iframeElement.id = "page";



  //   // 既存の iframe 要素が存在する場合は削除
  //   var existingIframe = html.document.getElementById('page');
  //   if (existingIframe != null) {
  //     existingIframe.remove();
  //   }else{

  //   }


  //   // WebView を表示
  //   // setState(() {
  //     // Widget 内に WebView を表示する方法
  //     // html.Element? existingElement = html.document.getElementById('page');
  //     // if (existingElement != null) {
  //     //   existingElement.remove();
  //     // }
  //     // iframeElement = html.IFrameElement()
  //     //   ..src = widget.url
  //     //   ..style.border = 'none';
  //   // html.document.body!.children.clear();
  //   //     // WebView を登録
  //   ui.platformViewRegistry.registerViewFactory(
  //     'iframeElement',
  //     (int viewId) => IFrameElement()
  //     ..src = widget.url
  //     ..style.border = 'none');
  //   // html.document.body!.append(iframeElement);
  //   // });
  // }
  @override
  void didUpdateWidget(covariant WebViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _updateIframeUrl(widget.url);
    }
  }

  void _updateIframeUrl(String url) {
    // _iframeElement.remove();
    // setState(() {
    //   _iframeElement.src = url;
    // });
  }

  @override
  void dispose() {
    super.dispose();
    // アプリが破棄されたときにIFrameElementを削除する
    // _iframeElement.remove();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IFrameElementをWebViewとしてレンダリングする
    // html.document.body!.append(_iframeElement);
  }

  /// アプリのUIを構築
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(webTitle),
          actions: <Widget>[
            if (_showMiniPlayerButton)
              TextButton(
                onPressed: () {
                  Provider.of<YoutubePlayerState>(context, listen: false)
                      .setVideoId(nowVidepID);
                },
                child: const Text(
                  'miniPlayerで再生',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: WebViewWidget(
          controller: controller,
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            IconButton(
              onPressed: () {
                // 何かアクションを実行
              },
              icon: Icon(Icons.info),
            ),
          ],
        ),
        body: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: HtmlElementView(
              viewType: 'iframeElement',
              key: UniqueKey(),
            ),
          ),
        ),
      );
    }
  }

  String extractVideoId(String youtubeUrl) {
    // YouTubeのURLからクエリパラメーターを取得
    Uri uri = Uri.parse(youtubeUrl);
    String query = uri.query;

    // クエリパラメーターから'v'キーの値を取得
    Map<String, String> queryParams = Uri.splitQueryString(query);
    String? videoId = queryParams['v'];

    // 取得したビデオIDを返す
    return videoId ?? '';
  }
}

void changeWebViewUrl(String url) {
  // WebViewのURLを変更するJavaScript関数を呼び出す
  // html.window.postMessage({'command': 'changeUrl', 'url': url}, '*');
}

class MyWebView extends StatelessWidget {
  final String initialUrl;

  const MyWebView({Key? key, required this.initialUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: 'webview',
      key: UniqueKey(), // キーを変更して再描画をトリガーする
    );
  }
}
