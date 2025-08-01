import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThreadDetailPage extends StatefulWidget {
  final String threadId;
  final String threadTitle;

  const ThreadDetailPage({
    required this.threadId,
    required this.threadTitle,
    Key? key,
  }) : super(key: key);

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  late final Stream<QuerySnapshot> postStream;
  final TextEditingController postController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> postKeys = {}; // 投稿番号とキーを紐づけ
  String defaultUsername = "";
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _postFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    // FocusNodeの状態変更を監視
    _usernameFocusNode.addListener(() {
      setState(() {}); // フォーカス状態に応じてUIを更新
    });
    _postFocusNode.addListener(() {
      setState(() {}); // フォーカス状態に応じてUIを更新
    });
    // postStreamを初期化
    postStream = FirebaseFirestore.instance
        .collection('posts')
        .where('threadId', isEqualTo: widget.threadId)
        .orderBy('createdAt', descending: false)
        .snapshots();

    _initializeUsername();
  }

  Future<void> _initializeUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');

    if (savedUsername != null && savedUsername.isNotEmpty) {
      setState(() {
        defaultUsername = savedUsername;
        _usernameController.text = defaultUsername;
      });
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists) {
          final firestoreUsername = doc.data()?['username'] ?? '';
          setState(() {
            defaultUsername = firestoreUsername;
            _usernameController.text = defaultUsername;
          });
        }
      }
    }
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('username', username);
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
        _scrollToPost(postNo);
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

  void _scrollToPost(int postNo) {
    final key = postKeys[postNo];
    if (key != null && key.currentContext != null) {
      // Scrollable.ensureVisible(
      //   key.currentContext!,
      //   duration: const Duration(milliseconds: 300),
      //   curve: Curves.easeInOut,
      // );
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.primaryDelta! > 20) {
          // スワイプで前の画面に戻る
          Navigator.of(context).pop();
        }
      },
      onTap: () {
        // 画面全体をタップしたらキーボードを閉じる
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        // appBar: AppBar(title: Text(widget.threadName)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: postStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('エラーが発生しました: ${snapshot.error}'),
                      );
                    }

                    final posts = snapshot.data?.docs ?? [];
                    if (posts.isEmpty) {
                      return const Center(child: Text("まだ投稿がありません。"));
                    }

                    // 投稿データをツリー構造に並べ替え
                    final organizedPosts = _organizePosts(posts);

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: organizedPosts.length,
                      itemBuilder: (context, index) {
                        final post = organizedPosts[index];
                        final postNo = post['postNo'];
                        final indentLevel = post['indentLevel'] as int;

                        if (!postKeys.containsKey(postNo)) {
                          postKeys[postNo] = GlobalKey();
                        }

                        return Container(
                          key: postKeys[postNo],
                          margin: EdgeInsets.only(
                              left: 16.0 * indentLevel), // インデント
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
                                            : '不明', // null または型が違う場合は「不明」を表示
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    )
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
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                focusNode: _usernameFocusNode,
                                controller: _usernameController,
                                maxLength: 20,
                                decoration: const InputDecoration(
                                    labelText: "ユーザー名を入力"),
                              ),
                            ),
                            if (!_usernameFocusNode.hasFocus)
                              const SizedBox(
                                  width: 48), // ここにボタンを追加（キーボードが開いているときのみ表示）
                            Visibility(
                              visible: _usernameFocusNode.hasFocus,
                              child: IconButton(
                                onPressed: () {
                                  FocusScope.of(context).unfocus(); // キーボードを閉じる
                                },
                                icon: const Icon(Icons.keyboard_hide),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                focusNode: _postFocusNode,
                                controller: postController,
                                minLines: 2,
                                maxLines: null, // 自動で高さ調整
                                maxLength: 80,
                                decoration:
                                    const InputDecoration(labelText: "投稿を追加"),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () async {
                                final content = postController.text.trim();
                                final userName =
                                    _usernameController.text.trim().isEmpty
                                        ? defaultUsername
                                        : _usernameController.text.trim();

                                if (userName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('ユーザー名を入力してください')),
                                  );
                                  return;
                                }
                                await _saveUsername(userName);
                                if (content.isNotEmpty) {
                                  // await addPost(widget.threadId, content, userName);
                                  postController.clear();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('投稿内容を入力してください')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    postController.dispose();
    _usernameController.dispose();
    _scrollController.dispose();

    _usernameFocusNode.dispose();
    _postFocusNode.dispose(); // メモリリークを防ぐ
    super.dispose();
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
}
