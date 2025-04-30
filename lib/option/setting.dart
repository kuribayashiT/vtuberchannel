// Package
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/main.dart';
import 'package:share/share.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo packageInfo = PackageInfo(
  appName: 'Unknown',
  packageName: 'Unknown',
  version: 'Unknown',
  buildNumber: 'Unknown',
  buildSignature: 'Unknown',
  installerStore: 'Unknown',
);

class setting extends StatefulWidget {
  @override
  _setting createState() => _setting();
}

class _setting extends State<setting> {
  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = info;
    });
  }

  void handleOshiraseUpdated(bool value) {
    setState(() {
      isOshiraseUpdated = value;
    });

  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
      appBar: AppBar(
        title: const Text('Option'),
      ),
      body: SafeArea(
      top: true,
      bottom: true,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.transparent,
              margin: const EdgeInsets.only(top: 0),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  if (!kIsWeb) _buildSection('設定'),
                  if (!kIsWeb) _buildListTile('Push通知', Icons.notifications, 2, context),
                  _buildSection('お知らせ'),
                  _buildListTile('お知らせ', Icons.info, 2, context),
                  _buildSection('このアプリについて'),
                  _buildListTile('共有する', Icons.share, 0, context),
                  _buildListTile('アプリ情報', Icons.info, 3, context),
                  _buildListTile('利用規約', Icons.assignment, 3, context),
                  _buildListTile('お問い合わせ', Icons.mail, 3, context),
                  _buildListTile('おすすめVtuber', Icons.star, 1, context),
                ],
              ),
            ),
          ),
        ],
      ),
    )
  );
}

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 4.0),
      child: Text(title),
    );
  }

  Widget _buildListTile(
      String title, IconData icon, int radiusPtn, BuildContext context) {
    BorderRadius borderRadius;
    switch (radiusPtn) {
      case 0:
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
          bottomLeft: Radius.circular(0.0),
          bottomRight: Radius.circular(0.0),
        );
        break;
      case 1:
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(0.0),
          topRight: Radius.circular(0.0),
          bottomLeft: Radius.circular(12.0),
          bottomRight: Radius.circular(12.0),
        );
        break;
      case 2:
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
          bottomLeft: Radius.circular(12.0),
          bottomRight: Radius.circular(12.0),
        );
        break;
      default:
        borderRadius = const BorderRadius.only(
          bottomLeft: Radius.circular(0.0),
          bottomRight: Radius.circular(0.0),
          topLeft: Radius.circular(0.0),
          topRight: Radius.circular(0.0),
        );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: CupertinoTheme.of(context).primaryColor),
        ),
        trailing: (isOshiraseUpdated && title == 'お知らせ') ? _buildBadge() : null,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () {
          // 各項目のタップ時の処理を記述
          switch (title) {
            case 'Push通知':
              pushToPushSettingDetail();
              break;
            case 'お知らせ':
              // お知らせ画面に遷移する処理を記述
              isOshiraseUpdated = false;
              pushToOshirase();
              handleOshiraseUpdated(isOshiraseUpdated);
              break;
            case '共有する':
              if (Platform.isAndroid) {
                Share.share('https://itunes.apple.com/jp/app/apple-store/id1611900581');
              } else if (Platform.isIOS) {
                Share.share('https://itunes.apple.com/jp/app/apple-store/id1611900581');
              }
              break;
            case 'アプリ情報':
              pushToAppInfo();
              break;
            case '利用規約':
              pushToTermsOfService();
              break;
            case 'お問い合わせ':
              launchMailApp(
                  "お問い合わせ", "\n\n\n\n\n\n\n\n\n\n\n\n\n${packageInfo.version}");
              break;
            case 'おすすめVtuber':
              launchMailApp(
                  "おすすめVtuber", "★お名前、Youubeチャンネルなど、できるだけ具体的にご教示ください！");
              break;
            default:
          }
        },
      ),
    );
  }

  Widget _buildBadge() {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: const Text(
          'New',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void launchMailApp(
    String subject,
    String body,
  ) async {
    final Uri _emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'vchannel.app.infomation@gmail.com',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunch(_emailLaunchUri.toString())) {
        await launch(_emailLaunchUri.toString());
      } else {
        throw 'Could not launch email';
      }
    } catch (e) {
      print('Error launching email: $e');
    }
  }
}
