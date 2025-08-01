import 'package:provider/provider.dart';
import 'package:vtuberchannel/common.dart';
import 'package:vtuberchannel/main.dart';

import 'googleCloudFunctions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SideMenu createState() => _SideMenu();
}

class _SideMenu extends State<SideMenu> {
  Set<String> selectedCategories = {};
  List<String> categories = [];
  Map<String, String> icons = {};
  late SharedPreferences _prefs;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    getOfficeData();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  // SharedPreferencesから選択されたカテゴリを読み込むメソッド
  Future<void> _loadSelectedCategories() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      // SharedPreferencesから保存されている選択されたカテゴリを読み込む
      selectedCategories
          .addAll(_prefs.getStringList('selectedCategories') ?? []);
      Provider.of<SelectedCategorie>(context, listen: false)
          .updateSelectedCategoriesNonNoti(selectedCategories);
    });
  }

  // SharedPreferencesに選択されたカテゴリを保存するメソッド
  Future<void> _saveSelectedCategories() async {
    await _prefs.setStringList(
        'selectedCategories',
        Provider.of<SelectedCategorie>(context, listen: false)
            .selectedCategories
            .toList());
  }

  Future<void> getOfficeData() async {
    try {
      final Map<String, dynamic> fetchedCategoriesMap =
          await GoogleCloudFunctions.getOfficeData();
      final List<String> fetchedCategories = fetchedCategoriesMap.keys.toList();

      fetchedCategoriesMap.forEach((officeName, vtuberList) {
        final vtuberWithIcon = vtuberList.firstWhere(
          (vtuber) => vtuber['officeFlg'] == true,
          orElse: () => null,
        );
        if (vtuberWithIcon != null &&
            vtuberWithIcon['channelThumbnail'] != null) {
          icons[officeName] = vtuberWithIcon['channelThumbnail'];
        } else {
          icons[officeName] = ""; // アイコンがない場合のデフォルト
        }
      });
      if (_isMounted) {
        setState(() {
          categories = fetchedCategories;
        });
      }
      _loadSelectedCategories();
    } catch (e) {
      print('Error fetching data: $e');
      // エラーが発生した場合も `_isMounted` を確認してから `setState` を呼ぶ
      if (_isMounted) {
        setState(() {
          // エラーの処理を行う（例: エラーメッセージを表示する）
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 150, // ドロワーヘッダーの高さを調整
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '表示する事務所選択',
                    style: TextStyle(
                      fontSize: 18, // フォントサイズを調整
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context); // ドロワーを閉じる
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: <Widget>[
                  // 選択項目のリスト表示
                  if (categories.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(top: 60.0),
                        child: Center(child: CircularProgressIndicator()))
                  else
                    for (String category in categories)
                      GestureDetector(
                        child: InkWell(
                          onTap: () {
                            // タップ時にチェックボックスの状態を切り替え
                            setState(() {
                              if (selectedCategories.contains(category)) {
                                selectedCategories.remove(category);
                              } else {
                                selectedCategories.add(category);
                              }
                              Provider.of<SelectedCategorie>(context,
                                      listen: false)
                                  .updateSelectedCategories(selectedCategories);
                              _saveSelectedCategories(); // 選択されたカテゴリを保存
                            });
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                side: const BorderSide(width: 1),
                                activeColor: Colors.white,
                                fillColor: WidgetStateProperty.resolveWith(
                                    (states) => Colors.white),
                                shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10))),
                                checkColor: Colors.black,
                                value: selectedCategories.contains(category),
                                onChanged: (value) {
                                  // チェックボックスが変更されたときに選択されたカテゴリを更新
                                  setState(() {
                                    if (value ?? false) {
                                      selectedCategories.add(category);
                                    } else {
                                      selectedCategories.remove(category);
                                    }
                                    Provider.of<SelectedCategorie>(context,
                                            listen: false)
                                        .updateSelectedCategories(
                                            selectedCategories);
                                    _saveSelectedCategories(); // 選択されたカテゴリを保存
                                  });
                                },
                              ),
                              (category == '個人' || category == 'person')
                                  ? CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.grey.shade200,
                                      child: const Icon(Icons.person,
                                          size: 16, color: Colors.grey),
                                    )
                                  : CircleAvatar(
                                      radius: 12,
                                      backgroundImage:
                                          NetworkImage(icons[category] ?? ''),
                                      backgroundColor: Colors.grey.shade200,
                                      onBackgroundImageError: (_, __) =>
                                          const Icon(
                                        Icons.image_not_supported,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                              const SizedBox(width: 4),
                              Expanded(
                                // テキスト部分を広げて、タップ領域を広く
                                child: Text(
                                  category,
                                  overflow:
                                      TextOverflow.ellipsis, // テキストが長すぎる場合の処理
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// アプリケーション全体の状態を管理するためのProvider
class SelectedCategorie with ChangeNotifier {
  Set<String> _selectedCategories = {}; // 選択されたカテゴリを保持する変数

  Set<String> get selectedCategories => _selectedCategories;

  // メッセージを更新するメソッド
  void updateSelectedCategories(Set<String> newselectedCategories) {
    _selectedCategories = newselectedCategories;
    if (_selectedCategories.isEmpty) {
      CustomToast.showToast(openContext, "選択項目がありません。フィルターを解除します。");
    } else {
      String categoriesText = _selectedCategories.join(' / ');
      CustomToast.showToast(openContext, "フィルターを設定しました。$categoriesText");
    }
    notifyListeners(); // 変更をリスナーに通知
  }

  // メッセージを更新するメソッド
  void updateSelectedCategoriesNonNoti(Set<String> newselectedCategories) {
    _selectedCategories = newselectedCategories;
    // if (_selectedCategories.isEmpty) {
    //   CustomToast.showToast(openContext, "選択項目がありません。フィルターを解除します。");
    // }else{
    //   String categoriesText = _selectedCategories.join(' / ');
    //   CustomToast.showToast(openContext, "フィルターを設定しました。$categoriesText");
    // }
  }
}
