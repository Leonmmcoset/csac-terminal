part of '../../main.dart';

class SpaceFeedScreen extends StatefulWidget {
  const SpaceFeedScreen({
    super.key,
    required this.state,
    this.embedded = false,
  });

  final CsacAppState state;
  final bool embedded;

  @override
  State<SpaceFeedScreen> createState() => _SpaceFeedScreenState();
}

class _SpaceFeedScreenState extends State<SpaceFeedScreen> {
  static const pageSize = 20;

  List<SpacePost> posts = const <SpacePost>[];
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int page = 1;
  int total = 0;

  bool get hasMore {
    if (posts.isEmpty) {
      return false;
    }
    if (total <= 0) {
      return posts.length >= page * pageSize;
    }
    return posts.length < total;
  }

  @override
  void initState() {
    super.initState();
    unawaited(loadPosts());
  }

  Future<void> loadPosts({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        loading = true;
        error = null;
      });
    } else if (loadingMore || !hasMore) {
      return;
    } else {
      setState(() {
        loadingMore = true;
        error = null;
      });
    }
    try {
      final targetPage = refresh ? 1 : page + 1;
      final loaded = await widget.state.client.spacePosts(
        page: targetPage,
        pageSize: pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        page = loaded.page <= 0 ? targetPage : loaded.page;
        total = loaded.total;
        posts = refresh ? loaded.posts : _mergeSpacePosts(posts, loaded.posts);
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> composePost() async {
    final draft = await showModalBottomSheet<_SpaceDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SpaceComposeSheet(
        title: context.strings.text('Post update'),
        submitLabel: context.strings.text('Post'),
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() => loading = posts.isEmpty);
    try {
      await widget.state.client.sendSpacePost(
        content: draft.content,
        images: draft.uploadFiles,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Post published.'))),
      );
      await loadPosts();
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString())));
      setState(() => loading = false);
    }
  }

  Future<void> replyToPost(SpacePost post) async {
    final draft = await showModalBottomSheet<_SpaceDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SpaceComposeSheet(
        title: context.strings.format('Reply to {name}', {
          'name': post.displayName,
        }),
        submitLabel: context.strings.text('Reply'),
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      await widget.state.client.replySpacePost(
        post.id,
        content: draft.content,
        images: draft.uploadFiles,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Reply sent.'))),
      );
      await loadPosts();
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> toggleLike(SpacePost post) async {
    try {
      final update = await widget.state.client.toggleSpaceLike(post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        posts = _replaceSpacePost(
          posts,
          post.id,
          (item) =>
              item.copyWith(isLiked: update.isLiked, likesNum: update.likesNum),
        );
      });
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> deletePost(SpacePost post) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.text(post.isReply ? 'Delete reply?' : 'Delete post?'),
        ),
        content: Text(
          strings.text(
            post.isReply
                ? 'This reply will be deleted.'
                : 'This post and its replies will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.client.deleteSpacePost(post.id);
      if (!mounted) {
        return;
      }
      setState(() => posts = _removeSpacePost(posts, post.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Post deleted.'))));
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Future<void> openPostUser(SpacePost post, Object avatarHeroTag) {
    return openUserProfile(
      context,
      widget.state,
      post.senderUid,
      avatarHeroTag: avatarHeroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final body = Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(
                onPressed: () => loadPosts(),
                child: Text(strings.text('Retry')),
              ),
              TextButton(
                onPressed: () => setState(() => error = null),
                child: Text(strings.text('Dismiss')),
              ),
            ],
          ),
        if (loading && posts.isNotEmpty) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: loadPosts,
            child: loading && posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 220),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    itemCount: posts.isEmpty
                        ? 1
                        : posts.length + (hasMore || loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (posts.isEmpty) {
                        return _EmptyPanel(
                          message: strings.text('No space posts yet.'),
                        );
                      }
                      if (index >= posts.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: loadingMore
                                ? const CircularProgressIndicator()
                                : OutlinedButton.icon(
                                    onPressed: () => loadPosts(refresh: false),
                                    icon: const Icon(
                                      Icons.expand_more_outlined,
                                    ),
                                    label: Text(strings.text('Load more')),
                                  ),
                          ),
                        );
                      }
                      final post = posts[index];
                      final avatarHeroTag = userAvatarHeroTag(
                        post.senderUid,
                        'space-post-${post.id}',
                      );
                      return _MotionListItem(
                        index: index,
                        child: _SpacePostCard(
                          post: post,
                          currentUserId: widget.state.user?.uid ?? 0,
                          avatarHeroTag: avatarHeroTag,
                          onOpenUser: () => openPostUser(post, avatarHeroTag),
                          onLike: () => toggleLike(post),
                          onReply: () => replyToPost(post),
                          onDelete: () => deletePost(post),
                          onReplyLike: toggleLike,
                          onReplyDelete: deletePost,
                          onReplyOpenUser: (reply, tag) =>
                              openPostUser(reply, tag),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Space')),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
            onPressed: loading ? null : loadPosts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(top: !widget.embedded, child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: composePost,
        icon: const Icon(Icons.edit_outlined),
        label: Text(strings.text('Post')),
      ),
    );
  }
}

class _SpacePostCard extends StatelessWidget {
  const _SpacePostCard({
    required this.post,
    required this.currentUserId,
    required this.avatarHeroTag,
    required this.onOpenUser,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onReplyLike,
    required this.onReplyDelete,
    required this.onReplyOpenUser,
  });

  final SpacePost post;
  final int currentUserId;
  final Object avatarHeroTag;
  final VoidCallback onOpenUser;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final ValueChanged<SpacePost> onReplyLike;
  final ValueChanged<SpacePost> onReplyDelete;
  final void Function(SpacePost post, Object avatarHeroTag) onReplyOpenUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    final canDelete = currentUserId > 0 && currentUserId == post.senderUid;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpenUser,
                  child: _Avatar(
                    url: post.avatar,
                    fallback: Icons.person_rounded,
                    radius: 22,
                    heroTag: avatarHeroTag,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (post.createdAt.isNotEmpty)
                        Text(
                          post.createdAt,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: strings.text('Delete'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (post.content.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(post.content.trim()),
            ],
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SpaceImageGrid(postId: post.id, images: post.images),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text(
                    '${strings.text(post.isLiked ? 'Unlike' : 'Like')} ${post.likesNum}',
                  ),
                ),
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_outlined),
                  label: Text(strings.text('Reply')),
                ),
              ],
            ),
            if (post.replies.isNotEmpty) ...[
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < post.replies.length; i++) ...[
                        _SpaceReplyTile(
                          reply: post.replies[i],
                          currentUserId: currentUserId,
                          onLike: () => onReplyLike(post.replies[i]),
                          onDelete: () => onReplyDelete(post.replies[i]),
                          onOpenUser: (tag) =>
                              onReplyOpenUser(post.replies[i], tag),
                        ),
                        if (i != post.replies.length - 1)
                          Divider(color: colors.outlineVariant),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpaceReplyTile extends StatelessWidget {
  const _SpaceReplyTile({
    required this.reply,
    required this.currentUserId,
    required this.onLike,
    required this.onDelete,
    required this.onOpenUser,
  });

  final SpacePost reply;
  final int currentUserId;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final ValueChanged<Object> onOpenUser;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final canDelete = currentUserId > 0 && currentUserId == reply.senderUid;
    final avatarHeroTag = userAvatarHeroTag(
      reply.senderUid,
      'space-reply-${reply.id}',
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onOpenUser(avatarHeroTag),
            child: _Avatar(
              url: reply.avatar,
              fallback: Icons.person_rounded,
              radius: 16,
              heroTag: avatarHeroTag,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      reply.displayName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reply.createdAt.isNotEmpty)
                      Text(
                        reply.createdAt,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (reply.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(reply.content.trim()),
                ],
                if (reply.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SpaceImageGrid(postId: reply.id, images: reply.images),
                ],
                const SizedBox(height: 2),
                Wrap(
                  spacing: 2,
                  children: [
                    TextButton.icon(
                      onPressed: onLike,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        reply.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                      ),
                      label: Text(
                        '${strings.text(reply.isLiked ? 'Unlike' : 'Like')} ${reply.likesNum}',
                      ),
                    ),
                    if (canDelete)
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(strings.text('Delete')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceImageGrid extends StatelessWidget {
  const _SpaceImageGrid({required this.postId, required this.images});

  final int postId;
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    final columns = count == 1 ? 1 : (count <= 4 ? 2 : 3);
    final maxWidth = count == 1 ? 320.0 : (count <= 4 ? 380.0 : 450.0);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final url = images[index];
            final heroTag = 'space-image:$postId:$index';
            return InkWell(
              onTap: () => showImagePreview(context, url, heroTag: heroTag),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpaceComposeSheet extends StatefulWidget {
  const _SpaceComposeSheet({required this.title, required this.submitLabel});

  final String title;
  final String submitLabel;

  @override
  State<_SpaceComposeSheet> createState() => _SpaceComposeSheetState();
}

class _SpaceComposeSheetState extends State<_SpaceComposeSheet> {
  static const maxImages = 9;
  static const maxImageBytes = 5 * 1024 * 1024;

  final content = TextEditingController();
  final picker = ImagePicker();
  final images = <_SpaceImageDraft>[];
  bool picking = false;
  String? error;

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    if (picking || images.length >= maxImages) {
      return;
    }
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final picked = await picker.pickMultiImage(imageQuality: 90);
      if (!mounted || picked.isEmpty) {
        return;
      }
      var skippedLarge = false;
      for (final file in picked.take(maxImages - images.length)) {
        final bytes = await file.readAsBytes();
        if (bytes.length > maxImageBytes) {
          skippedLarge = true;
          continue;
        }
        images.add(
          _SpaceImageDraft(
            fileName: pickedImageFileName(file, ImageSource.gallery),
            bytes: bytes,
          ),
        );
      }
      setState(() {
        error = skippedLarge
            ? context.strings.text('Some images exceed 5 MB.')
            : null;
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => picking = false);
      }
    }
  }

  void submit() {
    if (content.text.trim().isEmpty && images.isEmpty) {
      setState(
        () => error = context.strings.text(
          'Please enter text or choose at least one image.',
        ),
      );
      return;
    }
    Navigator.of(
      context,
    ).pop(_SpaceDraft(content: content.text.trim(), images: List.of(images)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: content,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.text("What's new?"),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: picking || images.length >= maxImages
                      ? null
                      : pickImages,
                  icon: picking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(strings.text('Choose images')),
                ),
                const SizedBox(width: 10),
                Text(
                  strings.format('{count}/9 images', {'count': images.length}),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SpaceSelectedImageGrid(
                images: images,
                onRemove: (index) => setState(() => images.removeAt(index)),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(strings.text('Cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(widget.submitLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceSelectedImageGrid extends StatelessWidget {
  const _SpaceSelectedImageGrid({required this.images, required this.onRemove});

  final List<_SpaceImageDraft> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(images[index].bytes, fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: context.strings.text('Remove image'),
                visualDensity: VisualDensity.compact,
                onPressed: () => onRemove(index),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpaceDraft {
  const _SpaceDraft({required this.content, required this.images});

  final String content;
  final List<_SpaceImageDraft> images;

  List<CsacUploadFile> get uploadFiles {
    return [
      for (final image in images)
        CsacUploadFile(
          fieldName: 'images',
          bytes: image.bytes,
          fileName: image.fileName,
        ),
    ];
  }
}

class _SpaceImageDraft {
  const _SpaceImageDraft({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

List<SpacePost> _mergeSpacePosts(
  List<SpacePost> existing,
  List<SpacePost> incoming,
) {
  final byId = <int, SpacePost>{for (final post in existing) post.id: post};
  for (final post in incoming) {
    byId[post.id] = post;
  }
  final merged = byId.values.toList();
  merged.sort((a, b) {
    final byTime = timestampForSort(
      b.createdAt,
    ).compareTo(timestampForSort(a.createdAt));
    return byTime == 0 ? b.id.compareTo(a.id) : byTime;
  });
  return merged;
}

List<SpacePost> _replaceSpacePost(
  List<SpacePost> posts,
  int postId,
  SpacePost Function(SpacePost post) replace,
) {
  return [
    for (final post in posts)
      if (post.id == postId)
        replace(post)
      else
        post.copyWith(
          replies: [
            for (final reply in post.replies)
              if (reply.id == postId) replace(reply) else reply,
          ],
        ),
  ];
}

List<SpacePost> _removeSpacePost(List<SpacePost> posts, int postId) {
  return [
    for (final post in posts)
      if (post.id != postId)
        post.copyWith(
          replies: [
            for (final reply in post.replies)
              if (reply.id != postId) reply,
          ],
        ),
  ];
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final uid = TextEditingController();
  final message = TextEditingController(text: '请求添加你为好友');
  UserProfile? preview;
  bool sending = false;
  bool searching = false;
  String? error;

  @override
  void dispose() {
    uid.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> lookup() async {
    final target = int.tryParse(uid.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid UID.'));
      return;
    }
    setState(() {
      searching = true;
      error = null;
      preview = null;
    });
    try {
      final loaded = await widget.state.loadUserProfile(target);
      if (!mounted) {
        return;
      }
      setState(() => preview = loaded);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => searching = false);
      }
    }
  }

  Future<void> submit() async {
    final target = int.tryParse(uid.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid UID.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.state.sendFriendRequest(target, message.text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Friend request sent.'))),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> openPreviewProfile() async {
    final profile = preview;
    if (profile == null) {
      return;
    }
    await openUserProfile(context, widget.state, profile.uid);
    if (mounted) {
      await lookup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Add friend'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: uid,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => lookup(),
              decoration: InputDecoration(
                labelText: context.strings.text('User UID'),
                prefixIcon: const Icon(Icons.tag),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: searching ? null : lookup,
              icon: searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(context.strings.text('Lookup user')),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: ListTile(
                  onTap: openPreviewProfile,
                  leading: _Avatar(
                    url: preview!.avatar,
                    fallback: Icons.person_rounded,
                  ),
                  title: Text(preview!.displayName),
                  subtitle: Text(
                    preview!.subtitle.isEmpty
                        ? 'UID ${preview!.uid}'
                        : preview!.subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.strings.text('Request message'),
                prefixIcon: const Icon(Icons.message_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sending ? null : submit,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(context.strings.text('Send request')),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final roomId = TextEditingController();
  final code = TextEditingController();
  final answer = TextEditingController();
  final search = TextEditingController();
  List<GroupProfile> publicGroups = const <GroupProfile>[];
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadPublicGroups();
  }

  @override
  void dispose() {
    roomId.dispose();
    code.dispose();
    answer.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> loadPublicGroups() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadPublicGroups();
      if (!mounted) {
        return;
      }
      setState(() => publicGroups = loaded);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> submit({int? groupId}) async {
    final target = groupId ?? int.tryParse(roomId.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid room ID.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.state.applyJoinGroup(
        target,
        code: code.text,
        answer: answer.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Join request sent.'))),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void useGroup(GroupProfile group) {
    roomId.text = '${group.id}';
    if (group.code.isNotEmpty) {
      code.text = group.code;
    }
    if (group.question.isNotEmpty) {
      answer.selection = TextSelection.collapsed(offset: answer.text.length);
    }
  }

  List<GroupProfile> filteredPublicGroups() {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return publicGroups;
    }
    return publicGroups.where((group) {
      final target =
          '${group.id} ${group.name} ${group.subtitle} ${group.description} ${group.notice}'
              .toLowerCase();
      return target.contains(query);
    }).toList();
  }

  void openGroupDetail(GroupProfile group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationDetailScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.group,
            id: group.id,
            name: group.name,
            avatar: group.avatar,
            subtitle: group.subtitle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.text('Join group')),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: loading ? null : loadPublicGroups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadPublicGroups,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextField(
                controller: roomId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.strings.text('Room ID'),
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: context.strings.text('Invite code'),
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.strings.text('Answer'),
                  prefixIcon: const Icon(Icons.question_answer_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: sending ? null : submit,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add),
                label: Text(context.strings.text('Apply to join')),
              ),
              const SizedBox(height: 20),
              Text(
                context.strings.text('Public groups'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.strings.text('Search public groups'),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (filteredPublicGroups().isEmpty)
                _EmptyPanel(message: context.strings.text('No public groups.'))
              else
                for (final group in filteredPublicGroups())
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.groups_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        [
                          context.strings.format('Room {id}', {'id': group.id}),
                          group.subtitle,
                          group.description,
                        ].where((part) => part.isNotEmpty).join(' | '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: sending
                            ? null
                            : () {
                                useGroup(group);
                                submit(groupId: group.id);
                              },
                        child: Text(context.strings.text('Join')),
                      ),
                      onTap: () => useGroup(group),
                      onLongPress: () => openGroupDetail(group),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final roomName = TextEditingController();
  bool creating = false;
  String? error;

  @override
  void dispose() {
    roomName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final name = roomName.text.trim();
    if (name.isEmpty) {
      setState(() => error = context.strings.text('Room name is required.'));
      return;
    }
    setState(() {
      creating = true;
      error = null;
    });
    try {
      final group = await widget.state.createGroup(name);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Group created: {name}', {
              'name': group.name,
            }),
          ),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConversationDetailScreen(
            state: widget.state,
            conversation: Conversation(
              type: ConversationType.group,
              id: group.id,
              name: group.name,
              avatar: group.avatar,
              subtitle: group.subtitle,
            ),
          ),
        ),
      );
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Create group'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: roomName,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: strings.text('Room name'),
                prefixIcon: const Icon(Icons.groups_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: creating ? null : submit,
              icon: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(strings.text('Create group')),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({
    super.key,
    required this.state,
    this.embedded = false,
  });

  final CsacAppState state;
  final bool embedded;

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final search = TextEditingController();
  SearchScope scope = SearchScope.all;
  List<MessageSearchResult> results = const <MessageSearchResult>[];
  bool loading = false;
  String? error;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    runSearch();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void scheduleSearch() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), runSearch);
  }

  Future<void> runSearch() async {
    setState(() {});
    final query = search.text.trim();
    if (query.isEmpty &&
        scope != SearchScope.image &&
        scope != SearchScope.essence) {
      setState(() {
        results = const <MessageSearchResult>[];
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.searchMessages(query, scope);
      if (!mounted) {
        return;
      }
      setState(() => results = loaded);
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() => error = err.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void setScope(SearchScope value) {
    setState(() => scope = value);
    runSearch();
  }

  Future<void> openResult(MessageSearchResult result) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: result.conversation,
          focusMessageId: result.message.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: search,
            onChanged: (_) => scheduleSearch(),
            autofocus: !widget.embedded,
            decoration: InputDecoration(
              hintText: strings.text('Search cached messages'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: strings.text('Clear'),
                      onPressed: () {
                        search.clear();
                        runSearch();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _ScopeChip(
                label: strings.text('All'),
                selected: scope == SearchScope.all,
                onSelected: () => setScope(SearchScope.all),
              ),
              _ScopeChip(
                label: strings.text('Friends'),
                selected: scope == SearchScope.private,
                onSelected: () => setScope(SearchScope.private),
              ),
              _ScopeChip(
                label: strings.text('Groups'),
                selected: scope == SearchScope.group,
                onSelected: () => setScope(SearchScope.group),
              ),
              _ScopeChip(
                label: strings.text('Images'),
                selected: scope == SearchScope.image,
                onSelected: () => setScope(SearchScope.image),
              ),
              _ScopeChip(
                label: strings.text('Essence'),
                selected: scope == SearchScope.essence,
                onSelected: () => setScope(SearchScope.essence),
              ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(
                onPressed: () => setState(() => error = null),
                child: Text(strings.text('Dismiss')),
              ),
            ],
          ),
        Expanded(
          child: results.isEmpty
              ? _EmptyPanel(
                  message:
                      search.text.trim().isEmpty &&
                          scope != SearchScope.image &&
                          scope != SearchScope.essence
                      ? strings.text('Type to search cached messages.')
                      : strings.text('No matching messages.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _MotionListItem(
                      index: index,
                      child: _SearchResultTile(
                        result: result,
                        preferences: widget.state.preferences,
                        onTap: () => openResult(result),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(strings.text('Search messages'))),
      body: SafeArea(top: widget.embedded, child: body),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.preferences,
    required this.onTap,
  });

  final MessageSearchResult result;
  final CsacPreferences preferences;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = result.conversation.type == ConversationType.group;
    final message = result.message;
    final time = displayMessageTime(message, preferences);
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: _RoundedInkClip(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: isGroup
                ? colors.secondaryContainer
                : colors.primaryContainer,
            child: Icon(
              isGroup ? Icons.groups_rounded : Icons.person_rounded,
              color: isGroup
                  ? colors.onSecondaryContainer
                  : colors.onPrimaryContainer,
            ),
          ),
          title: Text(
            result.conversation.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${message.sender}${time.isEmpty ? '' : ' · $time'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                result.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: message.imageUrl.isNotEmpty
              ? const Icon(Icons.image_outlined)
              : message.isEssence
              ? const Icon(Icons.star_outline)
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
