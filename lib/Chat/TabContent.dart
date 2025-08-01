import '../../widgets/cute_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';

class TabContent extends StatefulWidget {
  final String threadId;
  final Stream<QuerySnapshot> postStream;

  const TabContent({
    Key? key,
    required this.threadId,
    required this.postStream,
  }) : super(key: key);

  @override
  _TabContentState createState() => _TabContentState();
}

class _TabContentState extends State<TabContent>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> postKeys = {};
  final TextEditingController postController = TextEditingController();
  // final TextEditingController _usernameController = TextEditingController();
  // final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _postFocusNode = FocusNode();
  List<Map<String, dynamic>> organizedPosts = [];
  // String threadId = "";
  String defaultUsername = "";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState(); // FocusNodeの状態変更を監視
    // _usernameFocusNode.addListener(() {
    //   setState(() {}); // フォーカス状態に応じてUIを更新
    // });
    _postFocusNode.addListener(() {
      setState(() {}); // フォーカス状態に応じてUIを更新
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            key: PageStorageKey<String>(widget.threadId),
            controller: _scrollController,
            slivers: [
              // 1️⃣ ヘッダーを SliverPersistentHeader にする
              // SliverPersistentHeader(
              //   pinned: false, // スクロールで隠れるようにする
              //   floating: false,
              //   delegate: _HeaderDelegate(),
              // ),

              // 2️⃣ 投稿リスト（StreamBuilderで取得したデータ）
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.postStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CuteLoadingWidget(
                        message: '投稿を読み込み中…',
                        color: Color(0xFFF472B6),
                      );
                    }

                    if (snapshot.hasError) {
                      return CuteEmptyWidget(
                        message: '投稿の取得に失敗しました',
                        icon: Icon(Icons.error_outline,
                            size: 56, color: Color(0xFFF472B6)),
                        color: Color(0xFFF472B6),
                      );
                    }

                    final posts = snapshot.data?.docs ?? [];
                    if (posts.isEmpty) {
                      return CuteEmptyWidget(
                        message: 'まだ投稿がありません',
                        icon: Icon(Icons.forum,
                            size: 56, color: Color(0xFFF472B6)),
                        color: Color(0xFFF472B6),
                      );
                    }

                    organizedPosts = _organizePosts(posts);

                    return Column(
                      children: List.generate(organizedPosts.length, (index) {
                        final post = organizedPosts[index];
                        final postNo = post['postNo'];
                        final indentLevel = post['indentLevel'] as int;

                        if (!postKeys.containsKey(postNo)) {
                          postKeys[postNo] = GlobalKey();
                        }

                        return Container(
                          key: postKeys[postNo],
                          margin: EdgeInsets.only(left: 16.0 * indentLevel),
                          child: ListTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$postNo",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${post['author']}",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        post['createdAt'] != null &&
                                                post['createdAt'] is Timestamp
                                            ? _formatTimestamp(
                                                post['createdAt'] as Timestamp)
                                            : '不明',
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: _parseContentWithAnchors(
                                        post['content']),
                                    style: DefaultTextStyle.of(context).style,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.reply, size: 16),
                                    label: const Text("返信"),
                                    onPressed: () {
                                      setState(() {
                                        postController.text = ">>$postNo ";
                                        FocusScope.of(context)
                                            .requestFocus(FocusNode());
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),

          // 3️⃣ 投稿フォーム（画面下部に固定）
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildPostForm(),
              ),
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
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final content = postController.text.trim();
                  final userName = "";
                  if (content.isNotEmpty) {
                    await addPost(widget.threadId, content, userName);
                    postController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('投稿内容を入力してください')),
                    );
                  }
                },
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
      final postNo = int.tryParse(match.group(1)!);

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
              if (postNo != null) {
                _scrollToPost(postNo);
              }
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

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final formattedDate =
        "${dateTime.year}/${_twoDigits(dateTime.month)}/${_twoDigits(dateTime.day)}";
    final formattedTime =
        "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}";
    return "$formattedDate $formattedTime";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // 投稿を整理してインデントレベルを付与
  List<Map<String, dynamic>> _organizePosts(List<QueryDocumentSnapshot> posts) {
    final Map<int, Map<String, dynamic>> postMap = {};
    final List<Map<String, dynamic>> organizedPosts = [];
    final Set<int> processedPosts = {};

    // 投稿をマップに変換
    for (final post in posts) {
      postMap[post['postNo']] = {
        ...post.data() as Map<String, dynamic>,
        'indentLevel': 0, // 初期インデントレベル
      };
    }

    // 投稿を時系列順にソート
    final sortedPosts = posts.toList()
      ..sort((a, b) {
        if (a['createdAt'] != null &&
            a['createdAt'] is Timestamp &&
            b['createdAt'] != null &&
            b['createdAt'] is Timestamp) {
          final createdAtA = (a['createdAt'] as Timestamp).toDate();
          final createdAtB = (b['createdAt'] as Timestamp).toDate();
          return createdAtA.compareTo(createdAtB);
        } else {
          return 0;
        }
      });

    // 再帰的に投稿を整理
    void _addPostToOrganized(int postNo, int indentLevel) {
      if (processedPosts.contains(postNo) || !postMap.containsKey(postNo))
        return;

      final post = postMap[postNo]!;
      post['indentLevel'] = indentLevel;
      organizedPosts.add(post);
      processedPosts.add(postNo);

      // アンカー付き投稿を探す
      for (final anchorPostNo in postMap.keys) {
        final content = postMap[anchorPostNo]!['content'] as String;
        final anchorMatch = RegExp(r'>>(\d+)').firstMatch(content);

        if (anchorMatch != null &&
            int.tryParse(anchorMatch.group(1)!) == postNo) {
          _addPostToOrganized(
              anchorPostNo, indentLevel + 1 > 1 ? 1 : indentLevel + 1);
        }
      }
    }

    // ソート済み投稿をループ
    for (final post in sortedPosts) {
      final postNo = post['postNo'];
      if (!processedPosts.contains(postNo)) {
        _addPostToOrganized(postNo, 0);
      }
    }

    return organizedPosts;
  }

  /// 新規投稿を追加する処理
  Future<void> addPost(
      String threadId, String content, String authorName) async {
    try {
      final postCollection = FirebaseFirestore.instance.collection('posts');
      final newPostRef = postCollection.doc();
      final postCountSnapshot =
          await postCollection.where('threadId', isEqualTo: threadId).get();

      await newPostRef.set({
        'threadId': threadId,
        'content': content,
        'author': authorName,
        'postNo': postCountSnapshot.docs.length + 1, // 投稿番号
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('threads')
          .doc(threadId)
          .update({
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 投稿後スクロール処理を追加
      _handlePostScroll(content);
    } catch (e) {
      print('Error adding post: $e');
    }
  }

  /// 投稿内容に応じたスクロール処理
  void _handlePostScroll(String content) {
    // アンカーリンクが含まれているか判定
    final anchorRegex = RegExp(r'>>(\d+)');
    final match = anchorRegex.firstMatch(content);

    if (match != null) {
      // アンカー先の投稿番号にスクロール
      final postNo = int.tryParse(match.group(1)!);
      if (postNo != null) {
        // 返信群の一番下にスクロール
        _scrollToLastReply(postNo);
      }
    } else {
      // アンカーがない場合はリストの一番下にスクロール
      _scrollToBottom();
    }
  }

  /// リストの一番下にスクロール
  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToLastReply(int postNo) {
    // `postNo` に対するすべての返信を取得
    final replies = organizedPosts.where((post) {
      final content = post['content'] as String;
      return content.contains('>>$postNo');
    }).toList();

    if (replies.isNotEmpty) {
      // 一番最後の返信の `postNo` を取得
      final lastReply = replies.last;
      final lastReplyNo = lastReply['postNo'] as int;

      // その `postNo` へスクロール
      _scrollToPost(lastReplyNo);
    } else {
      // 返信がない場合は通常の動作
      _scrollToPost(postNo);
    }
  }

  void _scrollToPost(int postNo) {
    final key = postKeys[postNo];
    if (key != null && key.currentContext != null) {
      // 対応する投稿全体の一番下にスクロール
      final postRepliesKey = postKeys[postNo];
      if (postRepliesKey != null && postRepliesKey.currentContext != null) {
        final RenderBox box =
            postRepliesKey.currentContext!.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        _scrollController.animateTo(
          position.dy,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿No: $postNo が見つかりません')),
      );
    }
  }
}

// class _HeaderDelegate extends SliverPersistentHeaderDelegate {
//   @override
//   double get minExtent => 50; // 最小の高さ
//   @override
//   double get maxExtent => 100; // 最大の高さ

//   @override
//   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return Container(
//       color: Colors.white,
//       padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       child: const Row(
//         children: [
//           Icon(Icons.category, color: Colors.black),
//           SizedBox(width: 8),
//           Text("カテゴリ選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }

//   @override
//   bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
// }
