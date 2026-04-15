import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';

class PublicProfileScreen extends StatefulWidget {
  final int userId;
  final String? preloadedName; // optional hint shown while loading

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.preloadedName,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await apiService.getUserById(widget.userId);
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        // AppBar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                _loading
                    ? (widget.preloadedName ?? 'Profile')
                    : (_profile?.name ?? 'Profile'),
                style: const TextStyle(fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
              : _profile == null
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: () => _load(),
                      color: AppTheme.accent,
                      backgroundColor: AppTheme.bgCard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        child: Column(children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildStats(),
                          const SizedBox(height: 20),
                          _buildSkills(),
                        ]),
                      ),
                    ),
        ),
      ])),
    );
  }

  Widget _buildHeader() {
    final p = _profile!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D2E), Color(0xFF16192A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2), width: 1),
        boxShadow: AppTheme.glowShadow(radius: 32),
      ),
      child: Column(children: [
        // Avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.heroGradient,
            boxShadow: AppTheme.glowShadow(radius: 20),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: p.profilePhoto != null
                ? Image.network(p.profilePhoto!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _Avatar(p.name))
                : _Avatar(p.name),
          ),
        ),
        const SizedBox(height: 14),
        Text(p.name, style: const TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.5, color: AppTheme.text)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 3),
          Text(p.location, style: const TextStyle(fontFamily: 'SpaceGrotesk',
              fontSize: 13, color: AppTheme.textMuted)),
        ]),
      ]),
    );
  }

  Widget _buildStats() {
    final p = _profile!;
    return Row(children: [
      Expanded(child: _StatCard(
          label: 'Experience', value: '${p.experience} yr${p.experience == 1 ? '' : 's'}',
          icon: Icons.work_rounded, color: AppTheme.accent)),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
          label: 'Phone', value: p.number.isNotEmpty ? p.number : '—',
          icon: Icons.phone_rounded, color: AppTheme.teal)),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
          label: 'Skills', value: '${p.skills.length}',
          icon: Icons.psychology_rounded, color: AppTheme.amber)),
    ]);
  }

  Widget _buildSkills() {
    final p = _profile!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Skills', style: TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.text)),
        const SizedBox(height: 14),
        p.skills.isEmpty
            ? const Text('No skills listed.',
                style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint))
            : Wrap(
                spacing: 8, runSpacing: 8,
                children: p.skills.map((s) => SkillChip(label: s.name)).toList()),
      ]),
    );
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textFaint),
        const SizedBox(height: 16),
        const Text('Profile not found', style: TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.text)),
        const SizedBox(height: 24),
        BrutalButton(label: 'Go Back', onPressed: () => Navigator.pop(context)),
      ]),
    ));
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.bgMuted,
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w800, fontSize: 32, color: AppTheme.text),
    )),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withOpacity(0.2), width: 1),
    ),
    child: Column(children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w800, fontSize: 13, color: color),
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontFamily: 'SpaceGrotesk',
          fontSize: 9, letterSpacing: 0.3, color: AppTheme.textFaint)),
    ]),
  );
}
