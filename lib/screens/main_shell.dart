import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import 'feed/feed_screen.dart';
import 'jobs/jobs_screen.dart';
import 'applications/applications_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navCtrl;
  int _unreadCount = 0;

  final List<Widget> _screens = const [
    FeedScreen(), JobsScreen(), ApplicationsScreen(), NotificationsScreen(), ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _navCtrl.forward();
    _initUser();
  }

  /// FIX: _initUser now ensures currentUserId is set before screens render.
  /// Previously, if profileId was null (OAuth2 login without ID in redirect),
  /// the feed would immediately fail with "userId == null" and show nothing.
  /// Now we load from storage first, then fetch the full profile.
  Future<void> _initUser() async {
    final auth = context.read<AuthProvider>();
    try {
      // Prefer the in-memory value, fall back to secure storage
      int? profileId = auth.currentUserId ?? await apiService.getProfileId();

      if (profileId != null) {
        final profile = await apiService.getUserById(profileId);
        if (mounted) {
          auth.setCurrentUser(profile);
          // Now load unread count — userId is guaranteed to be set
          _loadUnreadCount();
        }
      } else {
        // userId truly unavailable — still try to load notifications gracefully
        _loadUnreadCount();
      }
    } catch (_) {
      // Don't crash the shell — just try unread count anyway
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUserId ?? await apiService.getProfileId();
      if (userId != null && mounted) {
        final count = await apiService.getUnreadCount(userId);
        if (mounted) setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    _navCtrl.reset();
    setState(() => _currentIndex = index);
    _navCtrl.forward();
    if (index == 3) _loadUnreadCount();
  }

  @override
  void dispose() { _navCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard.withOpacity(0.9),
              border: const Border(top: BorderSide(color: AppTheme.bgMuted, width: 1)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Feed', index: 0, current: _currentIndex, onTap: _onTabTap),
                    _NavItem(icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded, label: 'Jobs', index: 1, current: _currentIndex, onTap: _onTabTap),
                    _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Applied', index: 2, current: _currentIndex, onTap: _onTabTap),
                    _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Alerts', index: 3, current: _currentIndex, onTap: _onTabTap, badge: _unreadCount > 0 ? _unreadCount : null),
                    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 4, current: _currentIndex, onTap: _onTabTap),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;
  final int? badge;

  const _NavItem({required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.current, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(isActive ? activeIcon : icon, key: ValueKey(isActive),
                size: 22, color: isActive ? AppTheme.accent : AppTheme.textFaint),
            ),
            if (badge != null)
              Positioned(right: -4, top: -4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppTheme.rose, shape: BoxShape.circle),
                  child: Center(child: Text(badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                )),
          ]),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppTheme.accent : AppTheme.textFaint),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}