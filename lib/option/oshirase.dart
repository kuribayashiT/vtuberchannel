import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class osirase extends StatefulWidget {
  const osirase({super.key});

  @override
  _osirase createState() => _osirase();
}

class _osirase extends State<osirase> {
  String? jsonData;
  Map<String, dynamic>? oshiraseJson;

  // 一度でもお知らせ画面に遷移したらisOshiraseUpdatedをfalseに設定

  @override
  void initState() {
    super.initState();
    _fetchRemoteConfig();
  }

  Future<void> _fetchRemoteConfig() async {
    try {
      await FirebaseRemoteConfig.instance.fetchAndActivate();
      jsonData = FirebaseRemoteConfig.instance.getString("noticeJson");
      Map<String, dynamic> oshirase = json.decode(jsonData!);
      String _oshiraseJson = json.encode(oshirase);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('oldOshiraseJson', _oshiraseJson);
      setState(() {oshiraseJson = json.decode(jsonData!);});
    } catch (e) {
      print('Error fetching remote config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("お知らせ"),
        surfaceTintColor: Colors.transparent,
        // shape: const Border(bottom: BorderSide.none),
        backgroundColor: Colors.grey[200],
      ),
      body: Container(
        color: Colors.grey[200], // ライトグレーの背景色
        child: Center(
          child: oshiraseJson == null
              ? CircularProgressIndicator()
              : ListView.builder(
                  itemCount: oshiraseJson!['notice'].length,
                  itemBuilder: (BuildContext context, int index) {
                    final notice = oshiraseJson!['notice'][index];
                    final type = notice['type'];
                    final typeMessage = notice['typeMessage'];
                    final date = notice['date'];
                    final title = notice['title'];
                    final body = notice['body'];

                    Color labelColor;
                    if (type == '0') {
                      labelColor = Colors.blueAccent;
                    } else if (type == '1') {
                      labelColor = Colors.green.withOpacity(0.8);
                    } else {
                      labelColor = Colors.redAccent;
                    }

                    return Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Card(
                        color: Colors.white,
                        surfaceTintColor:
                            Colors.transparent, // カードViewの背景色を白に設定
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 100,
                                    decoration: BoxDecoration(
                                      color: labelColor,
                                      borderRadius: BorderRadius.circular(5.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 4.0),
                                    child: Text(
                                      typeMessage,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontWeight:
                                              FontWeight.bold), // フォントサイズを指定
                                      textAlign: TextAlign.center, // 中央揃え
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      date,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(body,
                                  style: const TextStyle(fontSize: 12.0)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
