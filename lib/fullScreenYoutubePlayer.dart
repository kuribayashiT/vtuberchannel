import 'package:flutter/material.dart';

class FullScreenPlayer extends StatelessWidget {
  final Widget Function(BuildContext) buildVideoPlayer;

  const FullScreenPlayer({Key? key, required this.buildVideoPlayer})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Full Screen Player'),
      ),
      body: Center(
        child: buildVideoPlayer(context),
      ),
    );
  }
}
