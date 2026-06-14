const csacDeepLinkScheme = 'csacflutterleon';

enum CsacDeepLinkAction {
  chats,
  space,
  search,
  notices,
  profile,
  userProfile,
  groupChat,
  privateChat,
  unsupported,
}

class CsacDeepLinkTarget {
  const CsacDeepLinkTarget(this.action, {this.id});

  final CsacDeepLinkAction action;
  final int? id;

  bool get isSupported => action != CsacDeepLinkAction.unsupported;
}

bool isCsacDeepLink(Uri uri) {
  return uri.scheme.toLowerCase() == csacDeepLinkScheme;
}

CsacDeepLinkTarget parseCsacDeepLink(Uri uri) {
  if (!isCsacDeepLink(uri)) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
  }
  final segments = csacDeepLinkSegments(uri);
  if (segments.isEmpty) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.chats);
  }

  final command = segments.first;
  switch (command) {
    case 'home':
    case 'chatlist':
    case 'chats':
    case 'conversations':
    case 'messages':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.chats);
    case 'space':
    case 'discover':
    case 'discovery':
    case 'dynamic':
    case 'feed':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.space);
    case 'search':
    case 'find':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.search);
    case 'notice':
    case 'notices':
    case 'notification':
    case 'notifications':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.notices);
    case 'me':
    case 'mine':
    case 'settings':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.profile);
    case 'profile':
      return _profileLinkTarget(uri, segments);
    case 'u':
    case 'uid':
    case 'user-profile':
    case 'profile-user':
      return _typedDeepLinkTarget(
        CsacDeepLinkAction.userProfile,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
      );
    case 'chat':
    case 'conversation':
      return _chatLinkTarget(uri, segments);
    case 'group':
    case 'room':
      return _typedDeepLinkTarget(
        CsacDeepLinkAction.groupChat,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
      );
    case 'private':
    case 'friend':
    case 'user':
      return _typedDeepLinkTarget(
        CsacDeepLinkAction.privateChat,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
      );
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
}

String csacUserProfileDeepLink(int uid) {
  return '$csacDeepLinkScheme://profile/user/$uid';
}

String csacGroupChatDeepLink(int roomId) {
  return '$csacDeepLinkScheme://chat/group/$roomId';
}

List<String> csacDeepLinkSegments(Uri uri) {
  final segments = <String>[];
  if (uri.host.trim().isNotEmpty) {
    segments.add(uri.host.trim());
  }
  for (final segment in uri.pathSegments) {
    final trimmed = segment.trim();
    if (trimmed.isNotEmpty) {
      segments.add(trimmed);
    }
  }
  if (segments.isEmpty && uri.fragment.trim().isNotEmpty) {
    final fragment = uri.fragment.trim().replaceFirst(RegExp(r'^/+'), '');
    segments.addAll(
      fragment
          .split('/')
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty),
    );
  }
  return [
    for (final segment in segments) Uri.decodeComponent(segment).toLowerCase(),
  ];
}

CsacDeepLinkTarget _chatLinkTarget(Uri uri, List<String> segments) {
  final type = segments.length > 1
      ? segments[1]
      : (uri.queryParameters['type'] ?? uri.queryParameters['kind'] ?? '');
  final id = segments.length > 2 ? segments[2] : uri.queryParameters['id'];
  switch (type.toLowerCase()) {
    case 'group':
    case 'room':
      return _typedDeepLinkTarget(CsacDeepLinkAction.groupChat, id);
    case 'private':
    case 'friend':
    case 'user':
      return _typedDeepLinkTarget(CsacDeepLinkAction.privateChat, id);
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
}

CsacDeepLinkTarget _profileLinkTarget(Uri uri, List<String> segments) {
  if (segments.length > 1) {
    final kind = segments[1];
    if (kind == 'user' || kind == 'uid') {
      return _typedDeepLinkTarget(
        CsacDeepLinkAction.userProfile,
        segments.length > 2 ? segments[2] : uri.queryParameters['id'],
      );
    }
    final id = int.tryParse(kind) ?? 0;
    if (id > 0) {
      return CsacDeepLinkTarget(CsacDeepLinkAction.userProfile, id: id);
    }
  }
  final id = int.tryParse(uri.queryParameters['uid'] ?? '') ?? 0;
  if (id > 0) {
    return CsacDeepLinkTarget(CsacDeepLinkAction.userProfile, id: id);
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.profile);
}

CsacDeepLinkTarget _typedDeepLinkTarget(
  CsacDeepLinkAction action,
  String? rawId,
) {
  final id = int.tryParse((rawId ?? '').trim()) ?? 0;
  if (id <= 0) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
  }
  return CsacDeepLinkTarget(action, id: id);
}
