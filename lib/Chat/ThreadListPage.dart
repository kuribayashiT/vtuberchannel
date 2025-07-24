import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vtuberchannel/googleCloudFunctions.dart';
import 'package:vtuberchannel/sideMenu.dart'; // SelectedCategorie のプロバイダをインポート

class ThreadListPage extends StatefulWidget {
  @override
  _ThreadListPageState createState() => _ThreadListPageState();
}

class _ThreadListPageState extends State<ThreadListPage>
    with TickerProviderStateMixin {
  final TextEditingController postController = TextEditingController();
  final FocusNode _postFocusNode = FocusNode();
  TabController? _tabController; // Nullable に変更
  List<String> officeList = [];
  late SelectedCategorie serectedOffice;
  Map<String, String> officeIcons = {};
  Map<String, List<String>> officeThreads = {};
  Map<String, List<Map<String, dynamic>>> threadPosts = {};
  List<String> selectedThreads = [];
  final Map<String, List<String>> officeThreadsMap = {};
  List<Map<String, dynamic>> organizedPosts = [];
  final Map<int, GlobalKey> postKeys = {};
  List<String> filteredOfficeList = [];
  List<Map<String, dynamic>> posts = [];

  @override
  void initState() {
    super.initState();
    serectedOffice = Provider.of<SelectedCategorie>(context, listen: false);
    serectedOffice.addListener(_onDataUpdated);
    _fetchOfficeData();
    //タブが変更されたら現在のthreadIdを更新

    // 選択中のオフィスを取得
    final List<String> selectedOfficeData =
        Provider.of<SelectedCategorie>(context, listen: false)
            .selectedCategories
            .toList();
    _tabController?.addListener(() {
      if (_tabController!.indexIsChanging) {
        final office = selectedOfficeData[_tabController!.index];
        setState(() {
          selectedThreads = officeThreads[office] ?? [];
        });
      }
    });

    _postFocusNode.addListener(() {
      setState(() {}); // フォーカス状態に応じてUIを更新
    });
  }

  Future<void> _onDataUpdated() async {
    serectedOffice = Provider.of<SelectedCategorie>(context, listen: false);
    await _fetchOfficeData();
  }

  @override
  void dispose() {
    // serectedOffice.removeListener(_onDataUpdated); // リスナーを解除
    serectedOffice.removeListener(_onDataUpdated); // リスナーを解除
    super.dispose();
  }

  Future<void> _fetchOfficeData() async {
    try {
      final Map<String, dynamic> fetchedData =
          await GoogleCloudFunctions.getOfficeData();

      final List<String> offices = [];
      final Map<String, String> icons = {};

      fetchedData.forEach((officeName, vtuberList) {
        offices.add(officeName);
        final vtuberWithIcon = vtuberList.firstWhere(
          (vtuber) => vtuber['officeFlg'] == true,
          orElse: () => null,
        );
        icons[officeName] = vtuberWithIcon?['channelThumbnail'] ?? "";
      });

      setState(() {
        officeList = offices;
        officeIcons = icons;
      });

      await _fetchThreads();
    } catch (e) {
      print('Error fetching office data: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getThreadPosts(String threadId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('threadId', isEqualTo: threadId)
        .orderBy('createdAt', descending: false) // 昇順で取得
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> _fetchThreads() async {
    try {
      final threadsSnapshot =
          await FirebaseFirestore.instance.collection('threads').get();

      for (var office in officeList) {
        officeThreadsMap[office] = [];
      }

      for (var doc in threadsSnapshot.docs) {
        final threadId = doc.id;
        final threadData = doc.data();
        final officeName = threadData['office'];

        if (officeThreadsMap.containsKey(officeName)) {
          officeThreadsMap[officeName]!.add(threadId);
        }

        await _fetchPostsForThread(threadId);
      }

      // 選択中のオフィスを取得
      final List<String> selectedOfficeData =
          Provider.of<SelectedCategorie>(context, listen: false)
              .selectedCategories
              .toList();
      setState(() {
        officeThreads = officeThreadsMap;

        // 初回のみタブコントローラーを初期化
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
    } catch (e) {
      print('Error fetching threads: $e');
    }
  }

  void _updateSelectedThreads(int tabIndex) {
    final office = officeList[tabIndex];
    setState(() {
      selectedThreads = officeThreads[office] ?? [];
      //organizedPosts = selectedThreads.expand((threadId) => threadPosts[threadId] ?? []).toList();
    });

    print("Updated selectedThreads: $selectedThreads");
    print("Updated organizedPosts: $organizedPosts");
  }

  void _updateTabController(List<String> filteredList) {
    // すでに存在している場合は破棄
    _tabController?.dispose();

    // 新しいTabControllerを作成
    _tabController = TabController(
      length: filteredList.length,
      vsync: this,
    )..addListener(() {
        if (_tabController!.indexIsChanging) {
          _updateSelectedThreads(_tabController!.index);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    // 選択中のオフィスを取得
    final List<String> selectedOfficeData =
        Provider.of<SelectedCategorie>(context, listen: true)
            .selectedCategories
            .toList();

    if (selectedOfficeData.isEmpty) {
      filteredOfficeList = officeList;
    } else {
      filteredOfficeList = officeList
          .where((office) => selectedOfficeData.contains(office))
          .toList();
    }

    // "掲示板ルール" タブを含めた新しいリストを作成
    final List<String> tabList = ["📢 掲示板ルール", ...filteredOfficeList];

    if (_tabController == null || _tabController!.length != tabList.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _updateTabController(tabList);
        });
      });
    }

    if (filteredOfficeList.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
         //Center(child: Text('選択中のオフィスがありません。')),
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
                      final iconUrl = officeIcons[office];
                      return Tab(
                        icon: iconUrl!.isNotEmpty
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
            body: Column(
              children: [
                // スクロール可能なエリア
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRulesPage(), // 📢 掲示板ルールのページ
                      ...filteredOfficeList.map((office) {
                        return _buildThreadList(office);
                      }).toList(),
                    ],
                  ),
                ),
                // 投稿フォーム（ルールページでは表示しない）
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    left: 8,
                    right: 8,
                  ),
                  child: _tabController!.index != 0
                      ? _buildPostForm()
                      : SizedBox(),
                ),
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

  Widget _buildThreadList(String tabOfficeName) {
    // オフィスに紐づくスレッドIDリストを取得
    final threadIdList = officeThreadsMap[tabOfficeName] ?? [];

    if (threadIdList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getPostStream(threadIdList[0]), // スレッドの投稿をリアルタイム取得
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        posts = snapshot.data!;

        if (posts.isEmpty) {
          return const Center(child: Text("まだ投稿がありません"));
        }

        final groupedPosts = _groupPostsByParent(posts);

        print("groupedPosts :");
        print(groupedPosts);
        final parentPosts = groupedPosts.entries
            .map((entry) => entry.value.first) // グループの先頭が親投稿
            .toList();

        parentPosts.sort((a, b) {
          final aReplies = groupedPosts[a['postNo']] ?? [];
          final bReplies = groupedPosts[b['postNo']] ?? [];

          // 親投稿とその返信の中で一番新しい投稿時間を取得
          final aLatestDate = _getLatestDate(a, aReplies);
          final bLatestDate = _getLatestDate(b, bReplies);

          return bLatestDate.compareTo(aLatestDate); // 降順ソート
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: parentPosts.length,
          itemBuilder: (context, index) {
            final parentPost = parentPosts[index];
            final postNo = parentPost['postNo'];
            var replies = [];
            if (parentPost['postNo'] != groupedPosts[postNo])
              replies = (groupedPosts[parentPost['postNo']] ?? [])
                  .skip(1)
                  .toList(); //groupedPosts[postNo] ?? []; // 親投稿に対する返信

            // すでに `postNo` に対応する GlobalKey がなければ追加
            postKeys.putIfAbsent(postNo, () => GlobalKey());

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.purple[50],
              child: Container(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 親投稿を表示
                    _buildPostItem(parentPost),

                    // 返信がある場合のみ表示
                    if (replies.isNotEmpty) ...[
                      const Divider(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: replies
                            .map((reply) => Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: _buildReplyItem(reply),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _getLatestDate(
      Map<String, dynamic> parent, List<Map<String, dynamic>> replies) {
    final allPosts = [parent, ...replies];

    return allPosts.map((post) {
      final createdAt = post['createdAt'];
      if (createdAt is Timestamp) {
        return createdAt.toDate();
      }
      return DateTime(0); // 不正データは最小値にする
    }).reduce((a, b) => a.isAfter(b) ? a : b); // 最新の日時を選ぶ
  }

  /// 返信表示用ウィジェット
  Widget _buildReplyItem(Map<String, dynamic> reply) {
    final replyNo = reply['postNo'];
    final timestamp = reply['createdAt'] as Timestamp?;
    final formattedTime =
        timestamp != null ? _formatTimestamp(timestamp) : "N/A";
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        // border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右に分ける
            children: [
              Text(
                "$replyNo",
              ),
              Text(
                formattedTime,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          RichText(
            text: TextSpan(
              children: _parseContentWithAnchors(reply['content']),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Map<int, List<Map<String, dynamic>>> _groupPostsByParent(
      List<Map<String, dynamic>> posts) {
    final Map<int, List<Map<String, dynamic>>> groupedPosts = {};

    for (var post in posts) {
      final postNo = post['postNo'] ?? 0;
      final parentNo = post['parentNo']; // ← これを replyTo と同義にする

      // 親投稿なら自分自身を自分のグループに追加
      if (parentNo == null || parentNo == 0) {
        groupedPosts.putIfAbsent(postNo, () => []).add(post);
      } else {
        // 子投稿なら親グループに追加
        groupedPosts.putIfAbsent(parentNo, () => []).add(post);
      }
    }

    // 並び替え
    groupedPosts.forEach((key, value) {
      value.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate != null && bDate != null) {
          return aDate.toDate().compareTo(bDate.toDate());
        }
        return 0;
      });
    });

    final sortedEntries = groupedPosts.entries.toList()
      ..sort((a, b) {
        final aLatestDate = _getLatestDate(a.value.first, a.value);
        final bLatestDate = _getLatestDate(b.value.first, b.value);
        return bLatestDate.compareTo(aLatestDate);
      });

    print("sortedEntries :");
    print(sortedEntries);

    return {for (var entry in sortedEntries) entry.key: entry.value};
  }

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

  /// 投稿表示用ウィジェット
  Widget _buildPostItem(Map<String, dynamic> post) {
    final postNo = post['postNo'];
    final timestamp = post['createdAt'] as Timestamp?;
    final formattedTime =
        timestamp != null ? _formatTimestamp(timestamp) : "N/A";
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右に分ける
        children: [
          Text(
            "$postNo",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            formattedTime,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: _parseContentWithAnchors(post['content']),
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
                  postController.text = ">>$postNo ";
                  FocusScope.of(context).requestFocus(FocusNode());
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostForm() {
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
                // onPressed: () async {
                //   final content = postController.text.trim();
                //   final userName = "";
                //   if (content.isNotEmpty) {
                //     await addPost(
                //         officeThreadsMap[
                //                 filteredOfficeList[_tabController!.index - 1]]!
                //             .first,
                //         content,
                //         userName);
                //     postController.clear();
                //   } else {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(content: Text('投稿内容を入力してください')),
                //     );
                //   }
                // },
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

  /// 各スレッドの投稿を取得
  Future<void> _fetchPostsForThread(String threadId) async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('threadId', isEqualTo: threadId)
          .orderBy('createdAt', descending: false)
          .get();

      posts = postsSnapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        organizedPosts.addAll(posts);
        threadPosts[threadId] = posts;
      });
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

  const PostSendButton({
    super.key,
    required this.postController,
    required this.officeThreadsMap,
    required this.filteredOfficeList,
    required this.tabController,
    required this.addPost,
    required this.icon,
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
      onPressed: isSending
          ? null
          : () async {
              final content = widget.postController.text.trim();
              const userName = "";
              if (content.isNotEmpty) {
                setState(() {
                  isSending = true;
                });
                await widget.addPost(
                  widget
                      .officeThreadsMap[widget
                          .filteredOfficeList[widget.tabController.index - 1]]!
                      .first,
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
