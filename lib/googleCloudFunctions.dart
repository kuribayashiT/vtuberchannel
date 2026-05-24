import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

class GoogleCloudFunctions {
  final storage =
      FirebaseStorage.instanceFor(bucket: "gs://vtuber-335811.appspot.com");
  final storageRef = FirebaseStorage.instance.ref();

  // ==============================================
  // オフィス一覧を取得する（キャッシュ有効期間24時間）
  // ==============================================
  static const String cacheKeyCachedCategories = 'cachedCategories';
  static const String lastUpdateKeyCachedCategories =
      'lastUpdate_cachedCategories';
  static Future<Map<String, dynamic>> getOfficeData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String jsonDataCategories =
          prefs.getString(cacheKeyCachedCategories) ?? '{}';
      Map<String, dynamic> data = jsonDecode(jsonDataCategories);
      //final List<String> cachedCategories = data.keys.toList();

      DateTime? lastUpdate =
          prefs.getString(lastUpdateKeyCachedCategories) != null
              ? DateTime.parse(prefs.getString(lastUpdateKeyCachedCategories)!)
              : null;
      if (lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 24) {
        // return cachedCategories;
        return data;
      }
      // if (kIsWeb) {
      //   // Webプラットフォーム向けの処理をここに書く
      //   final response = await http.post(
      //     Uri.parse(
      //         'https://us-central1-vtuber-335811.cloudfunctions.net/getOfficeListData'),
      //     // リクエストのボディやヘッダーなどの必要な情報を追加
      //   );
      //   if (response.statusCode == 200) {
      //     // レスポンスの処理
      //     final jsonData = json.decode(response.body);
      //     final data = jsonData['jsonData'];

      //     String cachecategories = jsonEncode(data);
      //     prefs.setString(cacheKeyCachedCategories, cachecategories);
      //     prefs.setString(
      //         lastUpdateKeyCachedCategories, DateTime.now().toIso8601String());
      //     // "にじさんじ"以下のデータにアクセス
      //     final categoriesDynamic = jsonData['jsonData'];
      //     return categoriesDynamic;
      //   } else {
      //     // エラーハンドリング
      //     return {};
      //   }
      // } else {
      // iOSやAndroid向けの処理をここに書く

      adHelper.interstitialAdShow();
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/officedataList.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        // responseDataがStringの場合、JSONとしてパースする
        final Map<String, dynamic> categoriesDynamic = jsonDecode(responseData);
        //final List<String> categories = categoriesDynamic.keys.toList();
        String cachecategories = jsonEncode(categoriesDynamic);
        prefs.setString(cacheKeyCachedCategories, cachecategories);
        prefs.setString(
            lastUpdateKeyCachedCategories, DateTime.now().toIso8601String());

        //return categories;
        return categoriesDynamic;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return {};
      }

      // final httpsReference = FirebaseStorage.instance.refFromURL(
      //     "https://storage.googleapis.com/vtuber-335811.appspot.com/officedataList.json");

      // // レスポンスの内容を文字列として取得
      // final String responseData = httpsReference.toString();

      // // responseDataがStringの場合、JSONとしてパースする
      // final Map<String, dynamic> categoriesDynamic = jsonDecode(responseData);
      // //final List<String> categories = categoriesDynamic.keys.toList();
      // String cachecategories = jsonEncode(categoriesDynamic);
      // prefs.setString(cacheKeyCachedCategories, cachecategories);
      // prefs.setString(
      //     lastUpdateKeyCachedCategories, DateTime.now().toIso8601String());
      // return categoriesDynamic;
    } catch (e) {
      print('Error fetching data: $e');
      return {};
    }
  }

  // ==============================================
  // 配信中動画一覧取得する（キャッシュ有効期間1分）
  // ==============================================
  static const String cacheKeyCachedLives = 'cachedLives';
  static const String lastUpdateKeyCachedLives = 'lastUpdate_cachedLives';
  static Future<List<dynamic>> getLiveData() async {
    try {
      // キャッシュを使うか判定
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedLivesStrings =
          prefs.getStringList(cacheKeyCachedLives);
      DateTime? lastUpdate = prefs.getString(lastUpdateKeyCachedLives) != null
          ? DateTime.parse(prefs.getString(lastUpdateKeyCachedLives)!)
          : null;
      print('lastUpdate: $lastUpdate');
      print('DateTime.now(): ${DateTime.now()}');
      // print('Difference in minutes: ${DateTime.now().difference(lastUpdate!).inMinutes}');

      if (cachedLivesStrings != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inMinutes < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedLives =
            cachedLivesStrings.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cachedLivesDynamic = cachedLives;
        return cachedLivesDynamic;
      }
      // if (kIsWeb) {
      //   // Webプラットフォーム向けの処理をここに書く
      //   Response response = await Dio().get(
      //     'https://storage.googleapis.com/vtuber-335811.appspot.com/livevideoList.json',
      //   );
      //   // Response response = await Dio().get(
      //   //   'https://storage.googleapis.com/vtuber-335811.appspot.com/livevideoList.json',
      //   //   options: Options(responseType: ResponseType.plain, headers: {
      //   //     'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
      //   //     // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
      //   //   }),
      //   // );
      //   // final response = await http.post(
      //   //   Uri.parse(
      //   //       'https://us-central1-vtuber-335811.cloudfunctions.net/getLiveVideoData'),
      //   // );
      //   if (response.statusCode == 200) {
      //     // レスポンスの処理
      //     final jsonData = json.decode(response.data);

      //     // "にじさんじ"以下のデータにアクセス
      //     final data = jsonData['jsonData'];
      //     // JSONとしてパース
      //     List<String> stringList = [];
      //     for (var live in data) {
      //       String jsonString = jsonEncode(live);
      //       stringList.add(jsonString);
      //     }

      //     prefs.setStringList(cacheKeyCachedLives, stringList);
      //     prefs.setString(
      //         lastUpdateKeyCachedLives, DateTime.now().toIso8601String());
      //     return data;
      //   } else {
      //     // エラーハンドリング
      //     return [];
      //   }
      // } else {
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/livevideoList.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        // responseDataがStringの場合、JSONとしてパースする
        final List<dynamic> lives = jsonDecode(responseData);

        // JSONとしてパース
        List<String> stringList = [];
        for (var live in lives) {
          String jsonString = jsonEncode(live);
          stringList.add(jsonString);
        }

        prefs.setStringList(cacheKeyCachedLives, stringList);
        prefs.setString(
            lastUpdateKeyCachedLives, DateTime.now().toIso8601String());

        return lives;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
      // }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // Event一覧取得する（キャッシュ有効期間60分）
  // ==============================================
  static const String cacheKeyCachedEvent = 'cachedEvent';
  static const String lastUpdateKeyCachedEvent = 'lastUpdate_cachedEvent';
  static Future<List<dynamic>> getEventData() async {
    try {
      // キャッシュを使うか判定
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedEventStrings =
          prefs.getStringList(cacheKeyCachedEvent);
      DateTime? lastUpdate = prefs.getString(lastUpdateKeyCachedEvent) != null
          ? DateTime.parse(prefs.getString(lastUpdateKeyCachedEvent)!)
          : null;

      if (cachedEventStrings != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inMinutes < 60) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedEvent =
            cachedEventStrings.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cachedEventDynamic = cachedEvent;
        return cachedEventDynamic;
      }
      // if (kIsWeb) {
      //   // Webプラットフォーム向けの処理をここに書く
      //   Response response = await Dio().get(
      //     'https://storage.googleapis.com/vtuber-335811.appspot.com/livevideoList.json',
      //   );
      //   // Response response = await Dio().get(
      //   //   'https://storage.googleapis.com/vtuber-335811.appspot.com/livevideoList.json',
      //   //   options: Options(responseType: ResponseType.plain, headers: {
      //   //     'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
      //   //     // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
      //   //   }),
      //   // );
      //   // final response = await http.post(
      //   //   Uri.parse(
      //   //       'https://us-central1-vtuber-335811.cloudfunctions.net/getLiveVideoData'),
      //   // );
      //   if (response.statusCode == 200) {
      //     // レスポンスの処理
      //     final jsonData = json.decode(response.data);

      //     // "にじさんじ"以下のデータにアクセス
      //     final data = jsonData['jsonData'];
      //     // JSONとしてパース
      //     List<String> stringList = [];
      //     for (var live in data) {
      //       String jsonString = jsonEncode(live);
      //       stringList.add(jsonString);
      //     }

      //     prefs.setStringList(cacheKeyCachedLives, stringList);
      //     prefs.setString(
      //         lastUpdateKeyCachedLives, DateTime.now().toIso8601String());
      //     return data;
      //   } else {
      //     // エラーハンドリング
      //     return [];
      //   }
      // } else {
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/eventList.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        // responseDataがStringの場合、JSONとしてパースする
        final List<dynamic> Event = jsonDecode(responseData);

        // JSONとしてパース
        List<String> stringEvent = [];
        for (var event in Event) {
          String jsonString = jsonEncode(event);
          stringEvent.add(jsonString);
        }

        prefs.setStringList(cacheKeyCachedEvent, stringEvent);
        prefs.setString(
            lastUpdateKeyCachedEvent, DateTime.now().toIso8601String());

        return Event;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
      // }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // NEWSを取得する（キャッシュ有効期間1時間）
  // ==============================================
  static const String cacheKeyCachedNews = 'cachedNews';
  static const String lastUpdateKeyCachedNews = 'lastUpdate_cachedNews';
  static Future<List<dynamic>> getNewsData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedKeyCacheNews =
          prefs.getStringList(cacheKeyCachedNews);
      DateTime? lastUpdate = prefs.getString(lastUpdateKeyCachedNews) != null
          ? DateTime.parse(prefs.getString(lastUpdateKeyCachedNews)!)
          : null;

      if (cachedKeyCacheNews != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedNews =
            cachedKeyCacheNews.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cachedKeyCachedNews = cachedNews;
        print('[NewsCache] loaded: count=${cachedKeyCachedNews.length}');
        return cachedKeyCachedNews;
      }
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/news.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*',
        }),
        queryParameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      print('[NewsAPI] status: ${response.statusCode}');
      print(
          '[NewsAPI] raw: ${response.data?.toString().substring(0, response.data.toString().length > 500 ? 500 : response.data.toString().length)}');

      if (response.statusCode == 200) {
        final String responseData = response.data;
        try {
          final List<dynamic> news = jsonDecode(responseData);
          print('[NewsAPI] parsed count: ${news.length}');
          List<String> stringList = [];
          for (var _news in news) {
            String jsonString = jsonEncode(_news);
            stringList.add(jsonString);
          }
          prefs.setStringList(cacheKeyCachedNews, stringList);
          prefs.setString(
              lastUpdateKeyCachedNews, DateTime.now().toIso8601String());
          return news;
        } catch (e) {
          print('[NewsAPI] JSON parse error: $e');
          return [];
        }
      } else {
        print(
            '[NewsAPI] Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[NewsAPI] Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // All Videoを取得する（キャッシュ有効期間1時間）
  // ==============================================
  static const String cacheKeyCachedAllVideo = 'cachedAllVideo';
  static const String lastUpdateKeyCachedAllVideo = 'lastUpdate_cachedAllVideo';
  static Future<List<dynamic>> getAllVideoData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedKeyCachedAllVideo =
          prefs.getStringList(cacheKeyCachedAllVideo);
      DateTime? lastUpdate =
          prefs.getString(lastUpdateKeyCachedAllVideo) != null
              ? DateTime.parse(prefs.getString(lastUpdateKeyCachedAllVideo)!)
              : null;

      if (cachedKeyCachedAllVideo != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedAllVideo =
            cachedKeyCachedAllVideo.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cacheKeyCachedAllVideo = cachedAllVideo;
        return cacheKeyCachedAllVideo;
      }
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/allvideos.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        final List<dynamic> AllVideo = jsonDecode(responseData);
        List<String> stringList = [];
        // ignore: non_constant_identifier_names
        for (var video in AllVideo) {
          String jsonString = jsonEncode(video);
          stringList.add(jsonString);
        }
        prefs.setStringList(cacheKeyCachedAllVideo, stringList);
        prefs.setString(
            lastUpdateKeyCachedAllVideo, DateTime.now().toIso8601String());

        return AllVideo;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // All Videoをから、特定のVideoを取得する
  // ==============================================
  Future<dynamic> getVideoDataById(String videoId) async {
    List<dynamic> allVideoData = await getAllVideoData();

    // リスト内の各動画オブジェクトをイテレートし、videoIDが一致するものを探す
    for (dynamic videoData in allVideoData) {
      if (videoData['videoID'] == videoId) {
        return videoData; // videoIDが一致する動画オブジェクトを返す
      }
    }
    CustomToast.showToast(openContext, "動画のお気に入り登録に失敗しました。お気に入り登録不可の動画です。");
    return null; // 該当する動画が見つからなかった場合はnullを返す
  }

  // ==============================================
  // RankingData(youtube)を取得する（キャッシュ有効期間1時間）
  // ==============================================
  static const String cacheKeyCachedRankingDataYoutube =
      'cachedRankingDataYoutube';
  static const String lastUpdateKeyCachedDataYoutube =
      'lastUpdate_cachedDataYoutube';
  static Future<List<dynamic>> getRankingDatayoutube() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedKeyCachedRankingDataYoutube =
          prefs.getStringList(cacheKeyCachedRankingDataYoutube);
      DateTime? lastUpdate =
          prefs.getString(lastUpdateKeyCachedDataYoutube) != null
              ? DateTime.parse(prefs.getString(lastUpdateKeyCachedDataYoutube)!)
              : null;

      if (cachedKeyCachedRankingDataYoutube != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedRankingDataYoutube =
            cachedKeyCachedRankingDataYoutube.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cacheKeyCachedRankingDataYoutube =
            cachedRankingDataYoutube;
        return cacheKeyCachedRankingDataYoutube;
      }
      // if (kIsWeb) {
      //   // Webプラットフォーム向けの処理をここに書く
      //   final response = await http.post(
      //     Uri.parse(
      //         'https://us-central1-vtuber-335811.cloudfunctions.net/getYoutubeRegiData'),
      //   );
      //   if (response.statusCode == 200) {
      //     // レスポンスの処理
      //     final jsonData = json.decode(response.body);

      //     // "にじさんじ"以下のデータにアクセス
      //     final YoutubeRegiData = jsonData['jsonData'];
      //     List<String> stringList = [];
      //     // ignore: non_constant_identifier_names
      //     for (var YoutubeRegi in YoutubeRegiData) {
      //       String jsonString = jsonEncode(YoutubeRegi);
      //       stringList.add(jsonString);
      //     }
      //     prefs.setStringList(cacheKeyCachedRankingDataYoutube, stringList);
      //     prefs.setString(
      //         lastUpdateKeyCachedDataYoutube, DateTime.now().toIso8601String());
      //     return YoutubeRegiData;
      //   } else {
      //     // エラーハンドリング
      //     return [];
      //   }
      // } else {
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/rankingYoutubeRegiData.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        final List<dynamic> RankingDataYoutube = jsonDecode(responseData);
        List<String> stringList = [];
        // ignore: non_constant_identifier_names
        for (var video in RankingDataYoutube) {
          String jsonString = jsonEncode(video);
          stringList.add(jsonString);
        }
        prefs.setStringList(cacheKeyCachedRankingDataYoutube, stringList);
        prefs.setString(
            lastUpdateKeyCachedDataYoutube, DateTime.now().toIso8601String());

        return RankingDataYoutube;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
      // }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // RankingData(twitter)を取得する（キャッシュ有効期間1時間）
  // ==============================================
  static const String cacheKeyCachedRankingDataTwitter =
      'cachedRankingDataTwitter';
  static const String lastUpdateKeyCachedDataTwitter =
      'lastUpdate_cachedDataTwitter';
  static Future<List<dynamic>> getRankingDataTwitter() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedKeyCachedRankingDataTwitter =
          prefs.getStringList(cacheKeyCachedRankingDataTwitter);
      DateTime? lastUpdate =
          prefs.getString(lastUpdateKeyCachedDataTwitter) != null
              ? DateTime.parse(prefs.getString(lastUpdateKeyCachedDataTwitter)!)
              : null;

      if (cachedKeyCachedRankingDataTwitter != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedRankingDataTwitter =
            cachedKeyCachedRankingDataTwitter.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cacheKeyCachedRankingDataTwitter =
            cachedRankingDataTwitter;
        return cacheKeyCachedRankingDataTwitter;
      }
      if (kIsWeb) {
        // Webプラットフォーム向けの処理をここに書く
        final response = await http.post(
          Uri.parse(
              'https://us-central1-vtuber-335811.cloudfunctions.net/getTwitterData'),
        );
        if (response.statusCode == 200) {
          // レスポンスの処理
          final jsonData = json.decode(response.body);

          // "にじさんじ"以下のデータにアクセス
          final YoutubeRegiData = jsonData['jsonData'];
          List<String> stringList = [];
          // ignore: non_constant_identifier_names
          for (var YoutubeRegi in YoutubeRegiData) {
            String jsonString = jsonEncode(YoutubeRegi);
            stringList.add(jsonString);
          }
          prefs.setStringList(cacheKeyCachedRankingDataTwitter, stringList);
          prefs.setString(
              lastUpdateKeyCachedDataTwitter, DateTime.now().toIso8601String());
          return YoutubeRegiData;
        } else {
          // エラーハンドリング
          return [];
        }
      } else {
        Response response = await Dio().get(
          'https://storage.googleapis.com/vtuber-335811.appspot.com/rankingTwitterData.json',
          options: Options(responseType: ResponseType.plain, headers: {
            'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
            // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
          }),
          queryParameters: {
            'timestamp':
                DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
          },
        );

        if (response.statusCode == 200) {
          // レスポンスの内容を文字列として取得
          final String responseData = response.data;

          final List<dynamic> RankingDataTwitter = jsonDecode(responseData);
          List<String> stringList = [];
          // ignore: non_constant_identifier_names
          for (var video in RankingDataTwitter) {
            String jsonString = jsonEncode(video);
            stringList.add(jsonString);
          }
          prefs.setStringList(cacheKeyCachedRankingDataTwitter, stringList);
          prefs.setString(
              lastUpdateKeyCachedDataTwitter, DateTime.now().toIso8601String());

          return RankingDataTwitter;
        } else {
          print('Failed to load data. Status code: ${response.statusCode}');
          return [];
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // RankingData(weeklyLiveView)を取得する（キャッシュ有効期間1時間）
  // ==============================================
  static const String cacheKeyCachedRankingDataWeeklyLiveView =
      'cachedRankingDataTwitter';
  static const String lastUpdateKeyCachedDataWeeklyLiveView =
      'lastUpdate_cachedDataTwitter';
  static Future<List<dynamic>> getRankingDataWeeklyLiveView() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedKeyCachedRankingDataWeeklyLiveView =
          prefs.getStringList(cacheKeyCachedRankingDataWeeklyLiveView);
      DateTime? lastUpdate =
          prefs.getString(lastUpdateKeyCachedDataWeeklyLiveView) != null
              ? DateTime.parse(
                  prefs.getString(lastUpdateKeyCachedDataWeeklyLiveView)!)
              : null;

      if (cachedKeyCachedRankingDataWeeklyLiveView != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedRankingDataWeeklyLiveView =
            cachedKeyCachedRankingDataWeeklyLiveView.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cacheKeyCachedRankingDataTwitter =
            cachedRankingDataWeeklyLiveView;
        return cacheKeyCachedRankingDataTwitter;
      }
      // if (kIsWeb) {
      //   // Webプラットフォーム向けの処理をここに書く
      //   final response = await http.post(
      //     Uri.parse(
      //         'https://us-central1-vtuber-335811.cloudfunctions.net/getTwitterData'),
      //   );
      //   if (response.statusCode == 200) {
      //     // レスポンスの処理
      //     final jsonData = json.decode(response.body);

      //     // "にじさんじ"以下のデータにアクセス
      //     final WeeklyLiveViewData = jsonData['jsonData'];
      //     List<String> stringList = [];
      //     // ignore: non_constant_identifier_names
      //     for (var WeeklyLiveView in WeeklyLiveViewData) {
      //       String jsonString = jsonEncode(WeeklyLiveView);
      //       stringList.add(jsonString);
      //     }
      //     prefs.setStringList(
      //         cacheKeyCachedRankingDataWeeklyLiveView, stringList);
      //     prefs.setString(lastUpdateKeyCachedDataWeeklyLiveView,
      //         DateTime.now().toIso8601String());
      //     return WeeklyLiveViewData;
      //   } else {
      //     // エラーハンドリング
      //     return [];
      //   }
      // } else {
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/weeklyLiveViewRanking.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        final List<dynamic> RankingDataWeeklyLiveView =
            jsonDecode(responseData);
        List<String> stringList = [];
        // ignore: non_constant_identifier_names
        for (var video in RankingDataWeeklyLiveView) {
          String jsonString = jsonEncode(video);
          stringList.add(jsonString);
        }
        prefs.setStringList(
            cacheKeyCachedRankingDataWeeklyLiveView, stringList);
        prefs.setString(lastUpdateKeyCachedDataWeeklyLiveView,
            DateTime.now().toIso8601String());

        return RankingDataWeeklyLiveView;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
      // }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  // ==============================================
  // RankingData(動画数)を取得する（キャッシュ有効期間1時間）
  // ==============================================
  static const String cacheKeyCachedRankingDataVNum = 'cachedRankingDataVNum';
  static const String lastUpdateKeyCachedDataVNum = 'lastUpdate_cachedDataVNum';
  static Future<List<dynamic>> getRankingDatavideoCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? cachedKeyCachedRankingDataVNum =
          prefs.getStringList(cacheKeyCachedRankingDataVNum);
      DateTime? lastUpdate =
          prefs.getString(lastUpdateKeyCachedDataVNum) != null
              ? DateTime.parse(prefs.getString(lastUpdateKeyCachedDataVNum)!)
              : null;

      if (cachedKeyCachedRankingDataVNum != null &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inHours < 1) {
        // String型のリストをMap型のリストに変換
        List<Map<String, dynamic>> cachedRankingDataVNum =
            cachedKeyCachedRankingDataVNum.map((jsonString) {
          // jsonDecodeの結果をMap<String, dynamic>型にキャスト
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }).toList();
        List<dynamic> cacheKeyCachedRankingDataVNum = cachedRankingDataVNum;
        return cacheKeyCachedRankingDataVNum;
      }
      // HHHHHHHHHHHHHHHHHHHHHHHH
      // HHHHHHHHHHHHHHHHHHHHHHHH
      // HHHHHHHHHHHHHHHHHHHHHHHH
      // HHHHHHHHHHHHHHHHHHHHHHHH
      // if (kIsWeb) {
      //   // Webプラットフォーム向けの処理をここに書く
      //   final response = await http.post(
      //     Uri.parse(
      //         'https://us-central1-vtuber-335811.cloudfunctions.net/getTwitterData'),
      //   );
      //   if (response.statusCode == 200) {
      //     // レスポンスの処理
      //     final jsonData = json.decode(response.body);

      //     // "にじさんじ"以下のデータにアクセス
      //     final YoutubeRegiData = jsonData['jsonData'];
      //     List<String> stringList = [];
      //     // ignore: non_constant_identifier_names
      //     for (var YoutubeRegi in YoutubeRegiData) {
      //       String jsonString = jsonEncode(YoutubeRegi);
      //       stringList.add(jsonString);
      //     }
      //     prefs.setStringList(cacheKeyCachedRankingDataVNum, stringList);
      //     prefs.setString(
      //         lastUpdateKeyCachedDataVNum, DateTime.now().toIso8601String());
      //     return YoutubeRegiData;
      //   } else {
      //     // エラーハンドリング
      //     return [];
      //   }
      // } else {
      Response response = await Dio().get(
        'https://storage.googleapis.com/vtuber-335811.appspot.com/rankingVideoCountData.json',
        options: Options(responseType: ResponseType.plain, headers: {
          'Access-Control-Allow-Origin': '*', // すべてのオリジンからのリクエストを許可
          // 必要に応じて、他のCORS関連のヘッダーを追加することもできます
        }),
        queryParameters: {
          'timestamp':
              DateTime.now().millisecondsSinceEpoch.toString(), // 一意のパラメータ
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容を文字列として取得
        final String responseData = response.data;

        final List<dynamic> RankingDataVNum = jsonDecode(responseData);

        // 空のオブジェクトをリストから削除
        final List<dynamic> validData = RankingDataVNum.where((item) {
          // 空のオブジェクトの判定（{} のようなものを除外）
          return item.isNotEmpty;
        }).toList();

        List<String> stringList = [];
        for (var video in validData) {
          String jsonString = jsonEncode(video);
          stringList.add(jsonString);
        }

        prefs.setStringList(cacheKeyCachedRankingDataVNum, stringList);
        prefs.setString(
            lastUpdateKeyCachedDataVNum, DateTime.now().toIso8601String());

        return validData;
      } else {
        print('Failed to load data. Status code: ${response.statusCode}');
        return [];
      }
      // }
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }
}
