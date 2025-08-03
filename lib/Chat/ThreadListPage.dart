import '../../widgets/cute_loading_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/sideMenu.dart'; // SelectedCategorie のプロバイダをインポート

class ThreadListPage extends StatefulWidget {
  @override
  _ThreadListPageState createState() => _ThreadListPageState();
}

class _ThreadListPageState extends State<ThreadListPage>
    with TickerProviderStateMixin {
  // UI制御
  TabController? _tabController;
  final TextEditingController postController = TextEditingController();
  final FocusNode _postFocusNode = FocusNode();
  String? selectedThreadId;
  List<String> filteredOfficeList = [];
  // クラスメンバに追加
  Set<String> initializedOffices = {};
  // データ管理
  List<String> officeList = [];
  Map<String, String> officeIcons = {};
  final Map<String, List<String>> officeThreadsMap = {};
  // Map<String, List<Map<String, dynamic>>> threadPosts = {};
  List<Map<String, dynamic>> posts = [];

  // その他
  late SelectedCategorie serectedOffice;

  void _onDataUpdated() => setState(() {});

  Future<void> _fetchOfficeData() async {
    final ref = FirebaseDatabase.instance.ref('officeMapping');
    final snapshot = await ref.get();
    List<String> offices = [];
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      offices = data.values.map((v) => v.toString()).toList();
    }
    setState(() => officeList = offices);
    await _fetchThreads();
  }

  Future<Map<String, String>> fetchOfficeMapping() async {
    final ref = FirebaseDatabase.instance.ref('officeMapping');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.map((k, v) => MapEntry(k, v.toString()));
    }
    return {};
  }

  Future<void> _fetchThreads() async {
    final officeMapping = await fetchOfficeMapping();
    final threadsSnapshot =
        await FirebaseFirestore.instance.collection('threads').get();
    final selectedCategorieProvider =
        Provider.of<SelectedCategorie>(context, listen: false);
    final List<String> categoriesOrder =
        selectedCategorieProvider.categoriesOrder;
    // officeThreadsMapをcategoriesOrder順で初期化
    for (var office in categoriesOrder) {
      officeThreadsMap[office] = [];
      // 初期化前に削除
      initializedOffices.remove(office);
    }

    for (var doc in threadsSnapshot.docs) {
      final threadId = doc.id;
      final threadData = doc.data();
      final firestoreOfficeName = threadData['office'];
      final officeName =
          officeMapping[firestoreOfficeName] ?? firestoreOfficeName;
      if (officeThreadsMap.containsKey(officeName)) {
        officeThreadsMap[officeName]!.add(threadId);
      }
      await _fetchPostsForThread(threadId);
    }
    final selectedOfficeData =
        selectedCategorieProvider.selectedCategories.toList();
    for (var office in categoriesOrder) {
      initializedOffices.add(office);
    }
    setState(() {
      if (selectedOfficeData.isNotEmpty) {
        _tabController = TabController(
          length: selectedOfficeData.length,
          vsync: this,
        )..addListener(() {
            _updateSelectedThreads(_tabController!.index);
          });
        _updateSelectedThreads(0);
      }
    });
    print('officeThreadsMap: $officeThreadsMap');
    print('filteredOfficeList: $filteredOfficeList');
    print('TabController length: ${_tabController?.length}');
  }

  void _updateSelectedThreads(int tabIndex) {
    final selectedCategorieProvider =
        Provider.of<SelectedCategorie>(context, listen: false);
    final List<String> categoriesOrder =
        selectedCategorieProvider.categoriesOrder;
    final office = categoriesOrder[tabIndex];
    setState(() {
      selectedThreadId = officeThreadsMap[office]?.isNotEmpty == true
          ? officeThreadsMap[office]!.first
          : null;
    });
  }

  @override
  void initState() {
    super.initState();
    serectedOffice = Provider.of<SelectedCategorie>(context, listen: false);
    serectedOffice.addListener(_onDataUpdated);
    _fetchOfficeData();
  }

  @override
  Widget build(BuildContext context) {
    // 選択中のオフィスを取得
    final selectedCategorieProvider =
        Provider.of<SelectedCategorie>(context, listen: true);
    final List<String> selectedOfficeData =
        selectedCategorieProvider.selectedCategories.toList();
    final List<String> categoriesOrder =
        selectedCategorieProvider.categoriesOrder;
    final Map<String, String> officeIcons =
        selectedCategorieProvider.officeIcons;

    if (selectedOfficeData.isEmpty) {
      filteredOfficeList =
          categoriesOrder.isNotEmpty ? categoriesOrder : officeList;
    } else {
      // 選択されたカテゴリをcategoriesOrder順で並び替え
      filteredOfficeList = categoriesOrder
          .where((cat) => selectedOfficeData.contains(cat))
          .toList();
    }
    print(
        'build: filteredOfficeList=$filteredOfficeList, officeThreadsMap=$officeThreadsMap');
    //
    if (categoriesOrder.isEmpty) {
      return const Scaffold(
        body: CuteLoadingWidget(
          message: 'スレッドを読み込み中…',
          color: Color(0xFFF472B6),
        ),
      );
    }

    // "掲示板ルール" タブを含めた新しいリストを作成
    final List<String> tabList = ["📢 掲示板ルール", ...filteredOfficeList];

    // TabControllerが未初期化なら初期化
    if (_tabController == null || _tabController!.length != tabList.length) {
      _tabController?.dispose();
      _tabController = TabController(
        length: tabList.length,
        vsync: this,
      );
      _tabController!.addListener(() {
        _updateSelectedThreads(_tabController!.index);
      });
      // ここで一度選択状態を更新
      _updateSelectedThreads(_tabController!.index);
      // TabController初期化直後はリビルドが必要
      return const Scaffold(
        body: CuteLoadingWidget(
          message: 'スレッドを読み込み中…',
          color: Color(0xFFF472B6),
        ),
      );
    }

    return DefaultTabController(
      length: tabList.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: false,
                  floating: true,
                  snap: true,
                  elevation: 0,
                  toolbarHeight: 80,
                  backgroundColor: Colors.white,
                  title: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: tabList.map((office) {
                      if (office == "📢 掲示板ルール") {
                        return const Tab(
                          icon: Icon(Icons.info, color: Colors.blue),
                          text: "ルール",
                        );
                      }
                      final iconUrl = officeIcons[office] ?? "";
                      return Tab(
                        icon: iconUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(iconUrl,
                                    width: 24, height: 24))
                            : const Icon(Icons.person),
                        text: office,
                      );
                    }).toList(),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesPage(),
                ...filteredOfficeList.map((office) {
                  final threadIdList = officeThreadsMap[office] ?? [];
                  final threadId =
                      threadIdList.isNotEmpty ? threadIdList.first : null;
                  final isOfficeThreadsReady =
                      initializedOffices.contains(office);

                  if (!isOfficeThreadsReady) {
                    return const CuteLoadingWidget(
                      message: 'スレッドを読み込み中…',
                      color: Color(0xFFF472B6),
                    );
                  }
                  return threadId != null
                      ? _buildPostList(threadId)
                      : Column(
                          children: [
                            Expanded(child: Center(child: Text('スレッドがありません'))),
                            Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom +
                                        8,
                                left: 8,
                                right: 8,
                              ),
                              child: _buildPostForm(null,
                                  isNewThread: true, officeName: office),
                            ),
                          ],
                        );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> getPostStream(String threadId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('threadId', isEqualTo: threadId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'postNo': doc['postNo'],
                  'content': doc['content'],
                  'author': doc['author'],
                  'createdAt': doc['createdAt'],
                  'parentNo': doc['parentNo'],
                })
            .toList());
  }

// 新規: 投稿一覧（選択中スレッド）
  Widget _buildPostList(String threadId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
        stream: getPostStream(threadId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.active) {
            // データが完全に揃うまではローディングのみ
            return const CuteLoadingWidget(
              message: '投稿を読み込み中…',
              color: Color(0xFFF472B6),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            // データがまだ来ていない場合もローディング
            return const CuteLoadingWidget(
              message: '投稿を読み込み中…',
              color: Color(0xFFF472B6),
            );
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            // データ取得後に投稿が0件なら「スレッドがありません」View
            return Column(
              children: [
                Expanded(child: Center(child: Text('スレッドがありません'))),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    left: 8,
                    right: 8,
                  ),
                  child: _buildPostForm(null, isNewThread: true),
                ),
              ],
            );
          }
          Map<int, List<Map<String, dynamic>>> childrenMap = {};
          List<Map<String, dynamic>> parentPosts = [];
          for (var post in posts) {
            int parentNo = post['parentNo'] ?? 0;
            if (parentNo == 0) {
              parentPosts.add(post);
            } else {
              childrenMap.putIfAbsent(parentNo, () => []).add(post);
            }
          }

          // 2. 親ごとに「自分＋子孫の中で一番新しいcreatedAt」を計算
          DateTime getLatestDate(Map<String, dynamic> parent) {
            DateTime latest = _getCreatedAt(parent);
            void dfs(Map<String, dynamic> node) {
              int postNo = node['postNo'] as int;
              if (childrenMap[postNo] != null) {
                for (var child in childrenMap[postNo]!) {
                  DateTime childDate = _getCreatedAt(child);
                  if (childDate.isAfter(latest)) latest = childDate;
                  dfs(child);
                }
              }
            }

            dfs(parent);
            return latest;
          }

          // 3. 親ポストを最新投稿日時順（降順）でソート
          parentPosts
              .sort((a, b) => getLatestDate(b).compareTo(getLatestDate(a)));

          // 4. ツリーを再帰的にWidget化
          List<Widget> postWidgets = [];
          for (var parent in parentPosts) {
            postWidgets.addAll(_buildPostTreeGrouped(parent, childrenMap, 0));
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: postWidgets,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                  left: 8,
                  right: 8,
                ),
                child: _buildPostForm(threadId),
              ),
            ],
          );
        });
  }

  List<Widget> _buildPostTreeGrouped(
    Map<String, dynamic> post,
    Map<int, List<Map<String, dynamic>>> childrenMap,
    int indentLevel,
  ) {
    // 再帰的に親＋子孫をリスト化
    List<Widget> _buildChildren(Map<String, dynamic> node, int level) {
      final nodeNo = node['postNo'];
      final nodeTimestamp = node['createdAt'] as Timestamp?;
      final nodeFormattedTime =
          nodeTimestamp != null ? _formatTimestamp(nodeTimestamp) : "N/A";
      List<Widget> widgets = [
        Padding(
          padding: EdgeInsets.only(left: 16.0 * level, top: 4, bottom: 4),
          child: ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$nodeNo",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(nodeFormattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: _parseContentWithAnchors(node['content']),
                    style: DefaultTextStyle.of(context).style,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text("返信"),
                    onPressed: () {
                      setState(() {
                        postController.text = ">>$nodeNo ";
                        FocusScope.of(context).requestFocus(FocusNode());
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
      final children = childrenMap[nodeNo] ?? [];
      children.sort((a, b) => _getCreatedAt(a).compareTo(_getCreatedAt(b)));
      for (var child in children) {
        widgets.addAll(_buildChildren(child, level + 1));
      }
      return widgets;
    }

    return [
      Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.shade400,
            width: 1.2,
          ),
        ),
        shadowColor: Colors.grey.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildChildren(post, 0),
          ),
        ),
      ),
    ];
  }

  // 投稿のcreatedAtをDateTimeで取得
  DateTime _getCreatedAt(Map<String, dynamic> post) {
    final createdAt = post['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    return DateTime(0);
  }

  /// 返信表示用ウィジェット

  Map<String, dynamic>? findTopParentBeforeZero(
      List<Map<String, dynamic>> posts, int parentNo) {
    List<Map<String, dynamic>> filteredPosts =
        posts.where((post) => post['postNo'] == parentNo).toList();

    if (filteredPosts.isEmpty) {
      return null; // 投稿が見つからない場合
    }

    Map<String, dynamic> currentPost = filteredPosts.first;

    // 次の親投稿が0なら、この投稿が直前の親投稿
    if (currentPost['parentNo'] == 0) {
      return null; // parentNo == 0 の場合は直前なし
    }

    // ここで次の親投稿を取得
    List<Map<String, dynamic>> nextParentPosts = posts
        .where((post) => post['postNo'] == currentPost['parentNo'])
        .toList();

    if (nextParentPosts.isEmpty) {
      return currentPost; // もし次の親投稿が存在しなければ直前の親投稿として返す
    }

    Map<String, dynamic> nextParentPost = nextParentPosts.first;

    if (nextParentPost['parentNo'] == 0) {
      return currentPost; // 次の親投稿が 0 なら現在の投稿が直前の親投稿
    }

    // さらに親投稿を再帰的に探す
    return findTopParentBeforeZero(posts, currentPost['parentNo']);
  }

  Widget _buildPostForm(String? threadId,
      {bool isNewThread = false, String? officeName}) {
    if (_tabController == null) return SizedBox();

    final TextEditingController titleController = TextEditingController();

    if (isNewThread) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('新規スレッドを作成', style: TextStyle(fontWeight: FontWeight.bold)),
            // const SizedBox(height: 8),
            // TextField(
            //   controller: titleController,
            //   maxLength: 40,
            //   decoration: InputDecoration(labelText: 'スレッドタイトル'),
            // ),
            const SizedBox(height: 8),
            TextField(
              focusNode: _postFocusNode,
              controller: postController,
              minLines: 2,
              maxLines: null,
              maxLength: 80,
              decoration: const InputDecoration(labelText: "本文"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('スレッド作成'),
              onPressed: () async {
                final title = titleController.text.trim();
                final content = postController.text.trim();
                if (title.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('タイトルと本文を入力してください')),
                  );
                  return;
                }
                await _createNewThread(officeName ?? '', title, content);
                titleController.clear();
                postController.clear();
              },
            ),
          ],
        ),
      );
    }

    // 既存スレッド用フォーム（元の内容）
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _postFocusNode,
                  controller: postController,
                  minLines: 2,
                  maxLines: null,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: "投稿を追加"),
                ),
              ),
              PostSendButton(
                postController: postController,
                officeThreadsMap: officeThreadsMap,
                filteredOfficeList: filteredOfficeList,
                tabController: _tabController!,
                addPost: addPost,
                icon: const Icon(Icons.send),
                threadId: threadId,
              ),
              if (!_postFocusNode.hasFocus) const SizedBox(width: 48),
              Visibility(
                visible: _postFocusNode.hasFocus,
                child: IconButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(Icons.keyboard_hide),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createNewThread(
      String office, String title, String content) async {
    try {
      final threadsCollection =
          FirebaseFirestore.instance.collection('threads');
      final postsCollection = FirebaseFirestore.instance.collection('posts');
      final newThreadRef = threadsCollection.doc();
      await newThreadRef.set({
        'office': office,
        'title': title,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      await postsCollection.add({
        'threadId': newThreadRef.id,
        'content': content,
        'author': '',
        'postNo': 1,
        'parentNo': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スレッドを作成しました')),
      );
      await _fetchThreads();
    } catch (e) {
      print('Error creating thread: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スレッド作成に失敗しました')),
      );
    }
  }

  /// 各スレッドの投稿を取得
  Future<void> _fetchPostsForThread(String threadId) async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('threadId', isEqualTo: threadId)
          .orderBy('createdAt', descending: false)
          .get();

      posts = postsSnapshot.docs.map((doc) => doc.data()).toList();

      // setState(() {
      //   threadPosts[threadId] = posts;
      // });
    } catch (e) {
      print('Error fetching posts for thread $threadId: $e');
    }
  }

  //==============================
  // post整理のためのメソッド
  //==============================
  Future<void> addPost(
      String threadId, String content, String authorName) async {
    FocusScope.of(context).unfocus();
    try {
      // ここで最新のpostsリストを取得
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('threadId', isEqualTo: threadId)
          .orderBy('createdAt', descending: false)
          .get();
      posts = postsSnapshot.docs.map((doc) => doc.data()).toList();
      final postCollection = FirebaseFirestore.instance.collection('posts');
      final newPostRef = postCollection.doc();
      final postCountSnapshot =
          await postCollection.where('threadId', isEqualTo: threadId).get();

      // 最上位の親を再帰的に探す
      int findRootParent(int postNo) {
        final parent = posts.firstWhere(
          (post) => post['postNo'] == postNo,
          orElse: () => <String, dynamic>{}, // 型付き空Map
        );

        if (parent.isEmpty) {
          return postNo; // 投稿が見つからない場合は自分自身を返す
        }

        final anchorMatches = RegExp(r'>>(\d+)').allMatches(parent["content"]);
        if (anchorMatches.isEmpty) {
          return postNo; // もう親がない → 最上位の親
        }
        final match = anchorMatches.first;

        // 再帰的に親をたどる
        return findRootParent(int.tryParse(match.group(1)!)!);
      }

      int parentNo = 0;
      final anchorMatches = RegExp(r'>>(\d+)').allMatches(content);
      List<int> anchorNumbers = [];

      // 🔍 全アンカーを抽出
      for (final match in anchorMatches) {
        final anchorNo = int.tryParse(match.group(1)!);
        if (anchorNo != null) {
          final anchorPost = posts.firstWhere(
            (post) => post['postNo'] == anchorNo,
            orElse: () => <String, dynamic>{},
          );

          if (anchorPost.isNotEmpty) {
            // 🔥 ここで最上位の親をたどってからリストに追加
            final rootParent = findRootParent(anchorNo);
            anchorNumbers.add(rootParent);
          }
        }
      }

      if (anchorNumbers.isNotEmpty) {
        // 最小番号の親を採用
        parentNo = anchorNumbers.reduce((a, b) => a < b ? a : b);
      }

      // Firestoreに登録
      await newPostRef.set({
        'threadId': threadId,
        'content': content,
        'author': authorName,
        'postNo': postCountSnapshot.docs.length + 1,
        'parentNo': parentNo,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // スレッドの最終更新日時を更新
      await FirebaseFirestore.instance
          .collection('threads')
          .doc(threadId)
          .update({
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print("Post added successfully");
    } catch (e) {
      print('Error adding post: $e');
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final formattedDate =
        "${dateTime.year}/${_twoDigits(dateTime.month)}/${_twoDigits(dateTime.day)}";
    final formattedTime =
        "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}";
    return "$formattedDate $formattedTime";
  }

  List<TextSpan> _parseContentWithAnchors(String content) {
    final anchorRegex = RegExp(r'>>(\d+)');
    final matches = anchorRegex.allMatches(content);

    if (matches.isEmpty) {
      return [TextSpan(text: content)];
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      final anchorText = match.group(0)!;

      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: content.substring(lastMatchEnd, match.start)));
      }

      spans.add(
        TextSpan(
          text: anchorText,
          style: const TextStyle(
              color: Colors.blue, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // if (postNo != null) {
              //   _scrollToPost(postNo);
              // }
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastMatchEnd)));
    }

    return spans;
  }

  /// 📢 掲示板ルールページのウィジェット
  Widget _buildRulesPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📢 掲示板ご利用にあたっての注意事項",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "本掲示板は、ユーザーの皆さまが自由に交流し、情報を共有できる場として提供されています。\n"
              "健全で快適なコミュニティを維持するため、以下の注意事項を必ずご確認のうえ、ご利用ください。",
            ),
            const Divider(height: 20),
            _buildRuleItem(
                "❌ 誹謗中傷・嫌がらせ", "特定の個人・団体に対する悪意のある発言、侮辱、差別的な表現は禁止します。"),
            _buildRuleItem("❌ プライバシーの侵害", "他人の個人情報を許可なく公開する行為は禁止します。"),
            _buildRuleItem("❌ 虚偽の情報の拡散", "根拠のない噂や誤解を招く情報を意図的に投稿することは禁止します。"),
            _buildRuleItem("❌ 違法行為・犯罪行為の助長", "法律に違反する行為、またはそれを助長する投稿は禁止します。"),
            _buildRuleItem("❌ 著作権・知的財産権の侵害", "他人の著作物や画像を無断で掲載・引用する行為は禁止します。"),
            _buildRuleItem("❌ 過度な暴力表現・性的表現", "公序良俗に反する投稿は禁止します。"),
            _buildRuleItem("❌ スパム・広告行為", "無関係な宣伝・広告・勧誘を目的とした投稿は禁止します。"),
            _buildRuleItem("❌ 荒らし行為", "意味のない投稿を繰り返す、他人の会話を妨害する行為は禁止します。"),
            const Divider(height: 20),
            const Text(
              "📌 みんなが気持ちよく利用できるために",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "掲示板は、ユーザーの皆さま一人ひとりの善意によって成り立っています。\n"
              "互いに尊重し、建設的な議論を心がけましょう！",
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 📌 ルール項目のウィジェット
  Widget _buildRuleItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description),
        ],
      ),
    );
  }
}

class PostSendButton extends StatefulWidget {
  final TextEditingController postController;
  final Map<String, List<String>> officeThreadsMap;
  final List<String> filteredOfficeList;
  final TabController tabController;
  final Future<void> Function(String, String, String) addPost;
  final dynamic icon;
  final String? threadId;

  const PostSendButton({
    super.key,
    required this.postController,
    required this.officeThreadsMap,
    required this.filteredOfficeList,
    required this.tabController,
    required this.addPost,
    required this.icon,
    required this.threadId,
  });

  @override
  State<PostSendButton> createState() => _PostSendButtonState();
}

class _PostSendButtonState extends State<PostSendButton> {
  bool isSending = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isSending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send),
      onPressed: isSending || widget.threadId == null
          ? null
          : () async {
              final content = widget.postController.text.trim();
              const userName = "";
              if (content.isNotEmpty) {
                setState(() {
                  isSending = true;
                });
                await widget.addPost(
                  widget.threadId!,
                  content,
                  userName,
                );
                widget.postController.clear();
                setState(() {
                  isSending = false;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('投稿内容を入力してください')),
                );
              }
            },
    );
  }
}
