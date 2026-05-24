import 'package:provider/provider.dart';
import 'googleCloudFunctions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  _SideMenu createState() => _SideMenu();
}

class _SideMenu extends State<SideMenu> {
  Set<String> expandedOffices = {};

  @override
  void initState() {
    super.initState();
    _fetchAndSetOfficeData();
  }

  Future<void> _fetchAndSetOfficeData() async {
    final fetchedMap = await GoogleCloudFunctions.getOfficeData();
    List<String> fetchedOffices = fetchedMap.keys.toList();
    if (fetchedOffices.isNotEmpty &&
        fetchedMap[fetchedOffices.first] is List &&
        (fetchedMap[fetchedOffices.first] as List).isNotEmpty &&
        (fetchedMap[fetchedOffices.first][0] as Map<String, dynamic>)
            .containsKey('order')) {
      fetchedOffices.sort((a, b) {
        final aOrder = (fetchedMap[a][0]['order'] ?? 9999) as int;
        final bOrder = (fetchedMap[b][0]['order'] ?? 9999) as int;
        return aOrder.compareTo(bOrder);
      });
    }

    Map<String, String> icons = {};
    Map<String, List<String>> channelIdsByOffice = {};
    Map<String, List<Map<String, dynamic>>> vtuberListByOffice = {};

    fetchedMap.forEach((officeName, vtuberList) {
      final vtuberWithIcon = vtuberList.firstWhere(
        (vtuber) => vtuber is Map && vtuber['officeFlg'] == true,
        orElse: () => null,
      );
      if (vtuberWithIcon != null &&
          vtuberWithIcon['channelThumbnail'] != null) {
        icons[officeName] = vtuberWithIcon['channelThumbnail'];
      } else {
        icons[officeName] = "";
      }
      vtuberListByOffice[officeName] = vtuberList
          .where((v) => v is Map<String, dynamic>)
          .map<Map<String, dynamic>>((v) => v as Map<String, dynamic>)
          .toList();
      channelIdsByOffice[officeName] = (vtuberListByOffice[officeName] ?? [])
          .where((v) =>
              v['channeID'] != null && v['channeID'].toString().isNotEmpty)
          .map<String>((v) => v['channeID'].toString())
          .toList();
    });

    // Providerにセット
    if (mounted) {
      Provider.of<SelectedCategorie>(context, listen: false).setOfficeDataFull(
        officeOrder: fetchedOffices,
        officeIcons: icons,
        channelIdsByOffice: channelIdsByOffice,
        vtuberListByOffice: vtuberListByOffice,
      );
    }
  }

  void _toggleOffice(String office) {
    setState(() {
      if (expandedOffices.contains(office)) {
        expandedOffices.remove(office);
      } else {
        expandedOffices.add(office);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategorie = Provider.of<SelectedCategorie>(context);
    final officeList = selectedCategorie.officeOrder;
    final officeIcons = selectedCategorie.officeIcons;
    final vtuberListByOffice = selectedCategorie.vtuberListByOffice;
    final selectedVtubersByOffice = selectedCategorie.selectedVtubersByOffice;

    return Drawer(
      child: Builder(builder: (drawerContext) {
        return Column(
          children: <Widget>[
            SizedBox(
              height: 150,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'フィルター',
                        style: TextStyle(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        Navigator.of(drawerContext).pop();
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
                    if (officeList.isEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 60.0),
                          child: Center(child: CircularProgressIndicator()))
                    else
                      for (String office in officeList)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              onTap: () => _toggleOffice(office),
                              leading: Transform.scale(
                                scale: 1.1,
                                child: Checkbox(
                                  side: const BorderSide(
                                      width: 0, color: Colors.white),
                                  checkColor: Colors.black,
                                  fillColor: MaterialStateProperty.resolveWith(
                                      (states) => Colors.white),
                                  value: selectedCategorie
                                      .isOfficeAllSelected(office),
                                  tristate: false,
                                  onChanged: (checked) =>
                                      selectedCategorie.toggleOfficeAll(
                                          office, checked ?? false),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              title: Row(
                                children: [
                                  (office == '個人' || office == 'person')
                                      ? CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.grey.shade200,
                                          child: const Icon(Icons.person,
                                              size: 16, color: Colors.grey),
                                        )
                                      : CircleAvatar(
                                          radius: 12,
                                          backgroundImage: NetworkImage(
                                              officeIcons[office] ?? ''),
                                          backgroundColor: Colors.grey.shade200,
                                          onBackgroundImageError: (_, __) =>
                                              const Icon(
                                            Icons.image_not_supported,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      office,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  Icon(
                                    expandedOffices.contains(office)
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                            if (expandedOffices.contains(office))
                              Padding(
                                padding: const EdgeInsets.only(left: 32.0),
                                child: Column(
                                  children: [
                                    for (var vtuber
                                        in vtuberListByOffice[office] ?? [])
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6.0),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: () {
                                            if (vtuber['channeID'] != null) {
                                              final isChecked =
                                                  selectedVtubersByOffice[
                                                              office]
                                                          ?.contains(vtuber[
                                                              'channeID']) ??
                                                      false;
                                              selectedCategorie.toggleVtuber(
                                                office,
                                                vtuber['channeID'],
                                                !isChecked,
                                              );
                                            }
                                          },
                                          child: Row(
                                            children: [
                                              Transform.scale(
                                                scale: 1.1,
                                                child: Checkbox(
                                                  shape: const CircleBorder(),
                                                  side: const BorderSide(
                                                      width: 0,
                                                      color: Colors.white),
                                                  checkColor: Colors.black,
                                                  fillColor:
                                                      MaterialStateProperty
                                                          .resolveWith(
                                                              (states) =>
                                                                  Colors.white),
                                                  value: vtuber['channeID'] !=
                                                          null
                                                      ? selectedVtubersByOffice[
                                                                  office]
                                                              ?.contains(vtuber[
                                                                  'channeID']) ??
                                                          false
                                                      : false,
                                                  onChanged: (checked) {
                                                    if (vtuber['channeID'] !=
                                                        null) {
                                                      selectedCategorie
                                                          .toggleVtuber(
                                                        office,
                                                        vtuber['channeID'],
                                                        checked ?? false,
                                                      );
                                                    }
                                                  },
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ),
                                              CircleAvatar(
                                                radius: 10,
                                                backgroundImage: NetworkImage(
                                                    vtuber['channelThumbnail'] ??
                                                        ''),
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                onBackgroundImageError:
                                                    (_, __) => const Icon(
                                                  Icons.image_not_supported,
                                                  size: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Expanded(
                                                child: Text(
                                                  vtuber['name'] ??
                                                      vtuber['channeID'] ??
                                                      '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class SelectedCategorie with ChangeNotifier {
  Map<String, Set<String>> _selectedVtubersByOffice = {};
  List<String> _officeOrder = [];
  Map<String, String> _officeIcons = {};
  Map<String, List<String>> _channelIdsByOffice = {};
  Map<String, List<Map<String, dynamic>>> _vtuberListByOffice = {};

  Map<String, Set<String>> get selectedVtubersByOffice =>
      _selectedVtubersByOffice;
  List<String> get officeOrder => _officeOrder;
  Map<String, String> get officeIcons => _officeIcons;
  Map<String, List<String>> get channelIdsByOffice => _channelIdsByOffice;
  Map<String, List<Map<String, dynamic>>> get vtuberListByOffice =>
      _vtuberListByOffice;

  // 選択中のオフィスリスト（1人でも選択されていれば含める）
  List<String> get selectedOfficeList => _officeOrder
      .where(
          (office) => (_selectedVtubersByOffice[office]?.isNotEmpty ?? false))
      .toList();

  Future<void> _saveSelectedChannelIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'selectedChannelIds', allSelectedchannelIds.toList());
  }

  // 初期化（詳細情報もセット）
  // setOfficeDataFullの最後で呼ぶ
  void setOfficeDataFull({
    required List<String> officeOrder,
    required Map<String, String> officeIcons,
    required Map<String, List<String>> channelIdsByOffice,
    required Map<String, List<Map<String, dynamic>>> vtuberListByOffice,
  }) {
    _officeOrder = officeOrder;
    _officeIcons = officeIcons;
    _channelIdsByOffice = channelIdsByOffice;
    _vtuberListByOffice = vtuberListByOffice;
    for (final office in officeOrder) {
      _selectedVtubersByOffice.putIfAbsent(office, () => <String>{});
    }
    notifyListeners();
    restoreSelectedChannelIds(); // ←追加
  }

  Future<void> restoreSelectedChannelIds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('selectedChannelIds');
    if (saved == null || saved.isEmpty) {
      // 初回起動時は全選択
      for (final office in _officeOrder) {
        final ids = _channelIdsByOffice[office] ?? [];
        _selectedVtubersByOffice[office] = ids.toSet();
      }
    } else {
      // 2回目以降は保存値で復元
      for (final office in _officeOrder) {
        final ids = _channelIdsByOffice[office] ?? [];
        _selectedVtubersByOffice[office] =
            ids.where((id) => saved.contains(id)).toSet();
      }
    }
    notifyListeners();
  }

  // Office単位で全Vtuber選択/解除
  void toggleOfficeAll(String office, bool checked) {
    if (checked) {
      _selectedVtubersByOffice[office] =
          Set<String>.from(_channelIdsByOffice[office] ?? []);
    } else {
      _selectedVtubersByOffice[office] = {};
    }
    notifyListeners();
    _saveSelectedChannelIds();
  }

  // Vtuber単位の選択/解除
  void toggleVtuber(String office, String channelId, bool checked) {
    final vtuberSet = _selectedVtubersByOffice[office] ?? <String>{};
    if (checked) {
      vtuberSet.add(channelId);
    } else {
      vtuberSet.remove(channelId);
    }
    _selectedVtubersByOffice[office] = vtuberSet;
    notifyListeners();
    _saveSelectedChannelIds();
  }

  // すべての選択channelId（Play/Ranking/Vtuberタブのフィルタ用）
  Set<String> get allSelectedchannelIds =>
      _selectedVtubersByOffice.values.expand((set) => set).toSet();

  // 新: 1つでも選択されていればtrue
  bool isOfficeAllSelected(String office) {
    final selected = _selectedVtubersByOffice[office] ?? {};
    return selected.isNotEmpty;
  }

  // Officeごとの一部選択状態
  bool isOfficePartiallySelected(String office) {
    final channels = _channelIdsByOffice[office] ?? [];
    final selected = _selectedVtubersByOffice[office] ?? {};
    return selected.isNotEmpty && selected.length < channels.length;
  }
}
