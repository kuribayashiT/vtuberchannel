import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class termsOfService extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('termsOfService Screen'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 別の画面からPushSettingDetail画面に戻る
            Navigator.pop(context);
          },
          child: Text('Go Back'),
        ),
      ),
    );
  }
}