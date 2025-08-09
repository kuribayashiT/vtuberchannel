import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/main.dart';
import 'package:vtuberchannel/widgets/cute_loading_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

String webTitle = "";
String nowURL = "";

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  const WebViewPage({Key? key, required this.url, required this.title})
      : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewPage> {
  late final WebViewController controller;
  bool _showMiniPlayerButton = false;
  String nowVidepID = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      controller = WebViewController()..loadRequest(Uri.parse(widget.url));
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) async {
            setState(() {
              _isLoading = true;
              _showMiniPlayerButton =
                  url.startsWith('https://m.youtube.com/watch?v=');
              if (_showMiniPlayerButton) {
                nowVidepID = extractVideoId(url);
              }
            });
          },
          onUrlChange: (UrlChange change) async {
            setState(() {
              _showMiniPlayerButton =
                  change.url!.startsWith('https://m.youtube.com/watch?v=');
              if (_showMiniPlayerButton) {
                nowVidepID = extractVideoId(change.url!);
              }
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _showMiniPlayerButton =
                  url.startsWith('https://m.youtube.com/watch?v=');
              if (_showMiniPlayerButton) {
                nowVidepID = extractVideoId(url);
              }
            });
          },
        ),
      );
    }
    webTitle = widget.title;
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(webTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (_isLoading)
              Positioned(
                top: 12,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            IconButton(
              onPressed: () {},
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
    Uri uri = Uri.parse(youtubeUrl);
    String query = uri.query;
    Map<String, String> queryParams = Uri.splitQueryString(query);
    String? videoId = queryParams['v'];
    return videoId ?? '';
  }
}
