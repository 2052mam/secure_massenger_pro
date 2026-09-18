import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat/create_channel_screen.dart';

import 'main_shell.dart';
import 'archived_chats_screen.dart';
import 'folder_editor_screen.dart';

import '../../providers/chat_list_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../../data/models/chat_folder_model.dart';
import '../../../core/utils/chat_search.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/services/api_service.dart';
import '../chat/chat_screen.dart';
import '../settings/device_management_screen.dart';
import '../../widgets/chat/chat_labels.dart';
import '../../widgets/chat/chat_list_actions.dart';
import '../../widgets/chat/chat_list_tile.dart';
import '../../widgets/chat/sponsored_banner.dart';
import '../../widgets/stories/story_bar.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  /// null = the "All" folder, [_personalFolderId] = the built in personal
  /// folder, anything else is a custom folder id.
  String? _selectedFolderId;

  static const String _personalFolderId = '__personal__';

  /// In-list search (Item 4). Empty means the normal folder view.
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  ChatFolderModel? _selectedFolder(List<ChatFolderModel> folders) {
    final id = _selectedFolderId;
    if (id == null || id == _personalFolderId) return null;
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  List<ChatModel> _visibleChats(
    List<ChatModel> chats,
    List<ChatFolderModel> folders, {
    List<ChatModel> archived = const [],
  }) {
    // While searching, Telegram ignores the folder filter and looks through
    // every conversation — including archived groups and channels.
    if (_query.trim().isNotEmpty) {
      final pool = <ChatModel>[...chats];
      final seen = pool.map((chat) => chat.id).toSet();
      for (final chat in archived) {
        if (seen.add(chat.id)) pool.add(chat);
      }
      return filterChats(pool, _query);
    }
    final id = _selectedFolderId;
    if (id == null) return chats;
    if (id == _personalFolderId) {
      return chats.where((c) => c.isPersonal).toList();
    }
    final folder = _selectedFolder(folders);
    if (folder == null) return chats;
    // A folder that includes the archive shows those chats inline, so the
    // archive row is not needed while such a folder is selected.
    final pool = folder.includeArchived ? [...chats, ...archived] : chats;
    return pool.where(folder.contains).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatListProvider);
    final foldersAsync = ref.watch(chatFoldersProvider);
    final folders = foldersAsync.valueOrNull ?? const <ChatFolderModel>[];
    final locale = ref.watch(localeProvider);
    final isFa = locale.languageCode == 'fa';
    final labels = ChatLabels.of(context);
    final theme = Theme.of(context);

    // A folder that was deleted elsewhere must not keep the list empty.
    if (_selectedFolderId != null &&
        _selectedFolderId != _personalFolderId &&
        foldersAsync.hasValue &&
        !folders.any((f) => f.id == _selectedFolderId)) {
      _selectedFolderId = null;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: _searching
            ? TextField(
                key: const ValueKey('chat-list-search-field'),
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: isFa
                      ? 'جستجو در چت‌ها، گروه‌ها و کانال‌ها...'
                      : 'Search chats, groups and channels...',
                ),
              )
            : Text(
                isFa ? 'پیام‌رسان' : 'Messenger',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
              ),
        actions: [
          IconButton(
            key: const ValueKey('chat-list-search'),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _toggleSearch,
            tooltip: isFa ? 'جستجو' : 'Search',
          ),
          if (!_searching)
            IconButton(
              key: const ValueKey('global-search'),
              icon: const Icon(Icons.travel_explore_rounded),
              onPressed: () {
                ref.read(shellIndexProvider.notifier).state = 1;
              },
              tooltip: isFa ? 'جستجوی سراسری' : 'Global search',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => _onMenu(v, isFa),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'saved',
                child: Text(isFa ? 'پیام‌های ذخیره‌شده' : 'Saved Messages'),
              ),
              PopupMenuItem(
                value: 'group',
                child: Text(isFa ? 'گروه جدید' : 'New Group'),
              ),
              PopupMenuItem(
                value: 'channel',
                child: Text(isFa ? 'کانال جدید' : 'New Channel'),
              ),
              PopupMenuItem(value: 'folder', child: Text(labels.newFolder)),
              PopupMenuItem(
                value: 'archive',
                child: Text(labels.archivedChats),
              ),
              PopupMenuItem(
                value: 'support',
                child: Text(isFa ? 'پشتیبانی' : 'Support'),
              ),
            ],
          ),
        ],
        bottom: _searching
            ? null
            : PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: _FolderBar(
            folders: folders,
            selectedId: _selectedFolderId,
            personalId: _personalFolderId,
            onSelected: (id) => setState(() => _selectedFolderId = id),
            onEdit: _openFolderEditor,
            onCreate: () => _openFolderEditor(null),
          ),
        ),
      ),
      body: SafeArea(
        child: chatsAsync.when(
          data: (data) {
            final folder = _selectedFolder(folders);
            final searching = _query.trim().isNotEmpty;
            final archived = (folder?.includeArchived == true || searching)
                ? (ref.watch(archivedChatListProvider).valueOrNull?.chats ??
                      const <ChatModel>[])
                : const <ChatModel>[];
            final chats = _visibleChats(
              data.chats,
              folders,
              archived: archived,
            );
            // The archive row lives on top of the "All" folder, like Telegram.
            final showArchiveRow =
                !searching && _selectedFolderId == null && data.hasArchive;
            if (chats.isEmpty && !showArchiveRow) {
              return _EmptyState(
                isFa: isFa,
                inFolder: _selectedFolderId != null,
                searching: searching,
              );
            }
            final itemCount = chats.length + (showArchiveRow ? 1 : 0);
            return Column(
              children: [
                if (!searching) const _SecurityAlertBanner(),
                if (!searching) const StoryBar(),
                if (!searching && _selectedFolderId == null)
                  const _SponsoredStrip(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: itemCount,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 76,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                      itemBuilder: (context, index) {
                        if (showArchiveRow && index == 0) {
                          return _ArchiveRow(
                            state: data,
                            labels: labels,
                            onTap: _openArchive,
                          );
                        }
                        final chat = chats[index - (showArchiveRow ? 1 : 0)];
                        return ChatListTile(
                              key: ValueKey(chat.id),
                              chat: chat,
                              isFa: isFa,
                              onTap: () => _openChat(chat),
                              onLongPress: () =>
                                  showChatContextMenu(context, ref, chat),
                            )
                            .animate()
                            .fadeIn(duration: 280.ms, delay: (20 * (index % 12)).ms)
                            .slideX(begin: 0.05, curve: Curves.easeOut);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isFa ? 'خطا در بارگذاری' : 'Failed to load',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(chatListProvider.notifier).refresh(),
                  child: Text(isFa ? 'تلاش مجدد' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      // بدون FloatingActionButton مداد
    );
  }

  void _openChat(ChatModel chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chat.id,
          title: chat.displayTitle,
          chatType: chat.chatType,
          otherUser: chat.otherUser,
          avatarUrl: chat.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _openArchive() async {
    await openArchivedChats(context, ref);
    if (!mounted) return;
    ref.read(chatListProvider.notifier).refresh();
  }

  Future<void> _openFolderEditor(ChatFolderModel? folder) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FolderEditorScreen(folder: folder)),
    );
    if (!mounted) return;
    if (saved == true) {
      await ref.read(chatFoldersProvider.notifier).load();
    }
  }

  Future<void> _onMenu(String value, bool isFa) async {
    try {
      if (value == 'saved') {
        final res = await ApiService().post('/chats/saved', {});
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: res['chat_id'] as String,
              title: isFa ? 'پیام‌های ذخیره‌شده' : 'Saved Messages',
              chatType: 'saved',
            ),
          ),
        );
      } else if (value == 'support') {
        final res = await ApiService().post('/chats/support', {});
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: res['chat_id'] as String,
              title: isFa ? 'پشتیبانی' : 'Support',
              chatType: 'support',
            ),
          ),
        );
      } else if (value == 'group') {
        await _createGroupDialog(isFa);
      } else if (value == 'channel') {
        await _createChannelDialog(isFa);
      } else if (value == 'folder') {
        await _openFolderEditor(null);
        return;
      } else if (value == 'archive') {
        await _openArchive();
        return;
      }
      ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _createGroupDialog(bool isFa) async {
    final titleCtrl = TextEditingController();
    final List<String> selectedIds = [];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFa ? 'گروه جدید' : 'New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: isFa ? 'نام گروه' : 'Group name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFa ? 'لغو' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isFa ? 'ایجاد' : 'Create'),
          ),
        ],
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final res = await ApiService().post('/chats/group', {
        'title': titleCtrl.text.trim(),
        'member_ids': selectedIds,
      });
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: res['chat_id'] as String,
            title: titleCtrl.text.trim(),
            chatType: 'group',
          ),
        ),
      );
    }
  }

  Future<void> _createChannelDialog(bool isFa) async {
    final session = ref.read(authenticatedSessionProvider);
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => CreateChannelScreen(api: session.api)),
    );
    if (!mounted || created == null) return;
    ref.read(chatListProvider.notifier).refresh();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: created['chat_id'] as String,
          title: created['title'] as String,
          chatType: 'channel',
        ),
      ),
    );
  }
}

/// Horizontal folder strip: All | Personal | custom folders | +
class _FolderBar extends StatelessWidget {
  const _FolderBar({
    required this.folders,
    required this.selectedId,
    required this.personalId,
    required this.onSelected,
    required this.onEdit,
    required this.onCreate,
  });

  final List<ChatFolderModel> folders;
  final String? selectedId;
  final String personalId;
  final ValueChanged<String?> onSelected;
  final ValueChanged<ChatFolderModel> onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final labels = ChatLabels.of(context);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _chip(context, labels.folderAll, null),
          _chip(context, labels.folderPersonal, personalId),
          for (final folder in folders)
            _chip(context, folder.name, folder.id, folder: folder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: IconButton(
              key: const ValueKey('folder-add'),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              tooltip: labels.newFolder,
              icon: const Icon(Icons.add_rounded),
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    String? id, {
    ChatFolderModel? folder,
  }) {
    final selected = selectedId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: GestureDetector(
        onLongPress: folder == null ? null : () => onEdit(folder),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(id),
        ),
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.state,
    required this.labels,
    required this.onTap,
  });

  final ChatListState state;
  final ChatLabels labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: const ValueKey('archive-row'),
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blueGrey.withValues(alpha: 0.2),
        child: Icon(
          state.hasArchivePin ? Icons.lock_outline : Icons.archive_outlined,
          color: Colors.blueGrey,
        ),
      ),
      title: Text(
        labels.archivedChats,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${state.archivedTotal}'),
      trailing: state.archivedUnread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.archivedUnread > 99 ? '99+' : '${state.archivedUnread}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}


/// Point 3: account-security banner.
///
/// The old version fetched `/devices/notifications` exactly once when the
/// widget mounted, so an alert raised while the user sat on the chat list only
/// appeared after a full app restart — that was the "arrives very late"
/// complaint. It now polls the dedicated `/security/alerts` feed, shows the
/// newest undismissed alert immediately, and dismissing it tells the server so
/// the alert does not come back on another device.
class _SecurityAlertBanner extends ConsumerStatefulWidget {
  const _SecurityAlertBanner();

  @override
  ConsumerState<_SecurityAlertBanner> createState() =>
      _SecurityAlertBannerState();
}

class _SecurityAlertBannerState extends ConsumerState<_SecurityAlertBanner> {
  static const Duration _pollInterval = Duration(seconds: 20);

  Map<String, dynamic>? _alert;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_pollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final api = ref.read(authenticatedSessionProvider).api;
      final response = await api.get('/security/alerts',
          query: {'unread': '1', 'limit': '1'});
      if (!mounted) return;
      final alerts = response['alerts'] as List? ?? const [];
      setState(() {
        _alert = alerts.isEmpty
            ? null
            : Map<String, dynamic>.from(alerts.first as Map);
      });
    } catch (_) {
      // Offline or a transient error: keep whatever is already on screen.
    }
  }

  Future<void> _dismiss() async {
    final alert = _alert;
    if (alert == null || _busy) return;
    setState(() {
      _busy = true;
      _alert = null;
    });
    try {
      final api = ref.read(authenticatedSessionProvider).api;
      await api.post('/security/alerts/${alert['id']}/dismiss', {});
    } catch (_) {
      // The banner is already hidden locally; the next poll re-syncs.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDevices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alert = _alert;
    if (alert == null) return const SizedBox.shrink();

    final critical = alert['severity'] == 'critical';
    final accent = critical ? Colors.red : Colors.orange;
    final title = (alert['title'] as String?)?.trim();
    final body = (alert['body'] as String?)?.trim();

    return Container(
      key: const ValueKey('security-alert-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openDevices,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  critical ? Icons.gpp_maybe : Icons.security,
                  color: accent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title?.isNotEmpty == true
                            ? title!
                            : 'رویداد امنیتی در حساب شما',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (body?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          body!,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black87),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'برای مدیریت دستگاه‌ها ضربه بزنید',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'بستن',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _busy ? null : _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sponsored channels strip (visible to everyone, set by the general admin).
class _SponsoredStrip extends StatefulWidget {
  const _SponsoredStrip();
  @override
  State<_SponsoredStrip> createState() => _SponsoredStripState();
}

class _SponsoredStripState extends State<_SponsoredStrip> {
  List<ChatModel> _channels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/chats/sponsored');
      if (!mounted) return;
      final list = (res['channels'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatModel.fromJson)
          .toList();
      setState(() => _channels = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => SponsoredBanner(channels: _channels);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isFa,
    required this.inFolder,
    this.searching = false,
  });

  final bool isFa;
  final bool inFolder;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final labels = ChatLabels.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searching
                ? Icons.search_off_rounded
                : inFolder
                    ? Icons.folder_open_rounded
                    : Icons.chat_bubble_outline_rounded,
            size: 72,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            searching
                ? (isFa ? 'چتی پیدا نشد' : 'No chats found')
                : inFolder
                    ? labels.folderEmpty
                    : (isFa ? 'هنوز گفتگویی ندارید' : 'No conversations yet'),
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? (isFa
                      ? 'جستجوی سراسری را برای یافتن کاربر یا کانال جدید امتحان کنید'
                      : 'Try global search to find new users or channels')
                : isFa
                    ? 'از تب جستجو کاربر پیدا کنید'
                    : 'Find users from the Search tab',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
