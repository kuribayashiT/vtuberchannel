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
      selectedCategories
          .addAll(_prefs.getStringList('selectedCategories') ?? []);
      // contextはBuilder内で使う
    });
  }

  // SharedPreferencesに選択されたカテゴリを保存するメソッド
  Future<void> _saveSelectedCategories(BuildContext ctx) async {
    await _prefs.setStringList(
        'selectedCategories',
        Provider.of<SelectedCategorie>(ctx, listen: false)
            .selectedCategories
            .toList());
  }

  Future<void> getOfficeData() async {
    try {
      final Map<String, dynamic> fetchedCategoriesMap =
          await GoogleCloudFunctions.getOfficeData();

      print(
          '【LOG】fetchedCategoriesMap.keys: ${fetchedCategoriesMap.keys.toList()}');
      List<String> fetchedCategories = fetchedCategoriesMap.keys.toList();
      if (fetchedCategories.isNotEmpty &&
          fetchedCategoriesMap[fetchedCategories.first] is List &&
          (fetchedCategoriesMap[fetchedCategories.first] as List).isNotEmpty &&
          (fetchedCategoriesMap[fetchedCategories.first][0]
                  as Map<String, dynamic>)
              .containsKey('order')) {
        fetchedCategories.sort((a, b) {
          final aOrder = (fetchedCategoriesMap[a][0]['order'] ?? 9999) as int;
          final bOrder = (fetchedCategoriesMap[b][0]['order'] ?? 9999) as int;
          return aOrder.compareTo(bOrder);
        });
        print('【LOG】orderプロパティでソート後: $fetchedCategories');
      } else {
        print('【LOG】orderプロパティなし、そのまま: $fetchedCategories');
      }

      fetchedCategoriesMap.forEach((officeName, vtuberList) {
        final vtuberWithIcon = vtuberList.firstWhere(
          (vtuber) => vtuber['officeFlg'] == true,
          orElse: () => null,
        );
        if (vtuberWithIcon != null &&
            vtuberWithIcon['channelThumbnail'] != null) {
          icons[officeName] = vtuberWithIcon['channelThumbnail'];
        } else {
          icons[officeName] = "";
        }
      });
      print('【LOG】icons: $icons');
      // Provider経由でofficeIconsをセット
      // contextはBuilder内で使う
      if (_isMounted) {
        setState(() {
          categories = fetchedCategories;
        });
        print('【LOG】setState後 categories: $categories');
      }
      _loadSelectedCategories();
    } catch (e) {
      print('Error fetching data: $e');
      if (_isMounted) {
        setState(() {
          // エラーの処理
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Builder(
        builder: (drawerContext) {
          // ProviderやNavigatorはこのdrawerContextで参照
          // Providerのセットや更新もdrawerContextで
          Provider.of<SelectedCategorie>(drawerContext, listen: false)
              .setOfficeIcons(icons);
          Provider.of<SelectedCategorie>(drawerContext, listen: false)
              .setCategoriesOrder(categories);
          Provider.of<SelectedCategorie>(drawerContext, listen: false)
              .updateSelectedCategoriesNonNoti(selectedCategories);

          return Column(
            children: <Widget>[
              SizedBox(
                height: 150,
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
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(drawerContext).pop();
                          // Navigator.pop(drawerContext);
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
                      if (categories.isEmpty)
                        const Padding(
                            padding: EdgeInsets.only(top: 60.0),
                            child: Center(child: CircularProgressIndicator()))
                      else
                        for (String category in categories)
                          GestureDetector(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (selectedCategories.contains(category)) {
                                    selectedCategories.remove(category);
                                  } else {
                                    selectedCategories.add(category);
                                  }
                                  Provider.of<SelectedCategorie>(drawerContext,
                                          listen: false)
                                      .updateSelectedCategories(
                                          selectedCategories);
                                  _saveSelectedCategories(drawerContext);
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
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10))),
                                    checkColor: Colors.black,
                                    value:
                                        selectedCategories.contains(category),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value ?? false) {
                                          selectedCategories.add(category);
                                        } else {
                                          selectedCategories.remove(category);
                                        }
                                        Provider.of<SelectedCategorie>(
                                                drawerContext,
                                                listen: false)
                                            .updateSelectedCategories(
                                                selectedCategories);
                                        _saveSelectedCategories(drawerContext);
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
                                          backgroundImage: NetworkImage(
                                              icons[category] ?? ''),
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
                                    child: Text(
                                      category,
                                      overflow: TextOverflow.ellipsis,
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
          );
        },
      ),
    );
  }
}

// アプリケーション全体の状態を管理するためのProvider
class SelectedCategorie with ChangeNotifier {
  Set<String> _selectedCategories = {};
  List<String> _categoriesOrder = [];
  Map<String, String> _officeIcons = {};

  Set<String> get selectedCategories => _selectedCategories;
  List<String> get categoriesOrder => _categoriesOrder;
  Map<String, String> get officeIcons => _officeIcons;
  void setCategoriesOrder(List<String> order) {
    _categoriesOrder = order;
    // notifyListeners();
  }

  void setOfficeIcons(Map<String, String> icons) {
    _officeIcons = icons;
    // notifyListeners();
  }

  void updateSelectedCategories(Set<String> newselectedCategories) {
    _selectedCategories = newselectedCategories;
    if (_selectedCategories.isEmpty) {
      CustomToast.showToast(openContext, "選択項目がありません。フィルターを解除します。");
    } else {
      String categoriesText = _selectedCategories.join(' / ');
      CustomToast.showToast(openContext, "フィルターを設定しました。$categoriesText");
    }
    notifyListeners();
  }

  void updateSelectedCategoriesNonNoti(Set<String> newselectedCategories) {
    _selectedCategories = newselectedCategories;
  }
}
