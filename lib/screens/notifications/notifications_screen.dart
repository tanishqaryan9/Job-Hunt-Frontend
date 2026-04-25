import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  bool _unreadOnly = false;
  late AnimationController _bellCtrl;

  @override
  void initState() {
    super.initState();
    _bellCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _loadNotifications();
  }

  @override
  void dispose() { _bellCtrl.dispose(); super.dispose(); }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().currentUserId;
    if (userId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      final result = _unreadOnly
          ? await apiService.getUnreadNotifications(userId)
          : await apiService.getNotifications(userId);
      if (!mounted) return;
      setState(() { _notifications = result; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notifications = [
          AppNotification(id: 1, body: 'Your application for Senior Flutter Developer has been shortlisted!', isRead: false, createdAt: '2026-04-04T10:30:00'),
          AppNotification(id: 2, body: 'Congratulations! You have been hired for Data Scientist role.', isRead: false, createdAt: '2026-04-03T14:20:00'),
          AppNotification(id: 3, body: 'New job matching your skills: Backend Engineer at FinTech', isRead: true, createdAt: '2026-04-02T09:00:00'),
          AppNotification(id: 4, body: 'Your application for React Developer was not selected this time.', isRead: true, createdAt: '2026-04-01T16:45:00'),
        ];
      });
    }
    if (!mounted) return;
    _bellCtrl.forward().then((_) { if (mounted) _bellCtrl.reverse(); });
  }

  Future<void> _markAllRead() async {
    final userId = context.read<AuthProvider>().currentUserId;
    if (userId == null) return;
    try {
      await apiService.markAllRead(userId);
      setState(() => _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList());
    } catch (_) {}
  }

  Future<void> _markOneRead(AppNotification item) async {
    if (item.isRead) return;
    try {
      await apiService.markNotificationRead(item.id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == item.id);
        if (idx != -1) _notifications[idx] = item.copyWith(isRead: true);
      });
    } catch (_) {}
  }

  Future<void> _deleteOne(int id) async {
    try { await apiService.deleteNotification(id); } catch (_) {}
    setState(() => _notifications.removeWhere((n) => n.id == id));
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: _loading ? _buildShimmer()
          : _notifications.isEmpty ? _buildEmpty() : _buildList()),
      ])),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RotationTransition(
            turns: Tween(begin: -0.04, end: 0.04).animate(_bellCtrl),
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: _unreadCount > 0 ? AppTheme.accentGradient : null,
                color: _unreadCount > 0 ? null : AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_rounded, size: 20,
                color: _unreadCount > 0 ? AppTheme.white : AppTheme.textMuted)),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Notifications', style: TextStyle(
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
            fontSize: 26, letterSpacing: -1, color: AppTheme.text))),
          if (_unreadCount > 0) ...[
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1),
                ),
                child: const Text('Mark all read', style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.accent)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        Row(children: [
          if (_unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.rose.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.rose.withOpacity(0.3), width: 1),
              ),
              child: Text('$_unreadCount unread', style: const TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.rose))),
          GestureDetector(
            onTap: () { setState(() => _unreadOnly = !_unreadOnly); _loadNotifications(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _unreadOnly ? AppTheme.accent : AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _unreadOnly ? AppTheme.accent : AppTheme.bgMuted, width: 1),
              ),
              child: Text('Unread only', style: TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w600, fontSize: 11,
                color: _unreadOnly ? AppTheme.white : AppTheme.textMuted)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    itemCount: 5,
    itemBuilder: (_, i) => const Padding(padding: EdgeInsets.only(bottom: 12), child: BrutalShimmer(height: 80)),
  );

  Widget _buildList() => RefreshIndicator(
    onRefresh: _loadNotifications,
    color: AppTheme.accent, backgroundColor: AppTheme.bgCard,
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _notifications.length,
      itemBuilder: (_, i) {
        final item = _notifications[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: Key('notif_${item.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: AppTheme.rose.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.delete_outline_rounded, color: AppTheme.rose, size: 22),
                SizedBox(height: 2),
                Text('Delete', style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600, fontSize: 10, color: AppTheme.rose)),
              ]),
            ),
            onDismissed: (_) => _deleteOne(item.id),
            child: _NotifCard(item: item, onTap: () => _markOneRead(item)),
          ),
        );
      },
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.bgMuted, width: 1),
        ),
        child: const Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.textFaint)),
      const SizedBox(height: 20),
      const Text('All caught up!', style: TextStyle(fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
      const SizedBox(height: 6),
      const Text('No notifications right now.', style: TextStyle(
        fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
    ]),
  );
}

class _NotifCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  const _NotifCard({required this.item, required this.onTap});

  (Color, IconData) get _meta {
    final msg = item.message.toLowerCase();
    if (msg.contains('hired') || msg.contains('congratulations')) return (AppTheme.green, Icons.emoji_events_rounded);
    if (msg.contains('shortlisted')) return (AppTheme.amber, Icons.star_rounded);
    if (msg.contains('rejected') || msg.contains('not selected')) return (AppTheme.rose, Icons.close_rounded);
    if (msg.contains('application')) return (AppTheme.blue, Icons.send_rounded);
    return (AppTheme.accent, Icons.notifications_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _meta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: item.isRead ? AppTheme.bgCard : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isRead ? AppTheme.bgElevated : color.withOpacity(0.3),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: item.isRead ? AppTheme.cardShadow()
              : [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, spreadRadius: -2)],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Left color indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: item.isRead ? AppTheme.bgMuted : color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            ),
          ),
          const SizedBox(width: 14),
          // Icon
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(item.isRead ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: item.isRead ? color.withOpacity(0.5) : color),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.message, style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
                  fontSize: 13, height: 1.5,
                  color: item.isRead ? AppTheme.textMuted : AppTheme.text)),
                if (item.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(_formatTime(item.createdAt!), style: const TextStyle(
                    fontFamily: 'SpaceGrotesk', fontSize: 11, color: AppTheme.textFaint)),
                ],
              ]),
            ),
          ),
          // Unread dot
          if (!item.isRead)
            Padding(
              padding: const EdgeInsets.only(top: 18, right: 14),
              child: Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
                )),
            ),
        ]),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return iso.split('T').first; }
  }
}
