import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  UserProfile? _profile;
  bool _loading = true;
  File? _pickedImage;
  bool _uploadingPhoto = false;

  late AnimationController _headerCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _headerExpand;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _floatCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _headerExpand = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _floatAnim    = Tween<double>(begin: -8,  end: 8).animate(CurvedAnimation(parent: _floatCtrl,  curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() { _headerCtrl.dispose(); _floatCtrl.dispose(); super.dispose(); }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUserId;
    if (userId == null) { setState(() => _loading = false); return; }
    try {
      final profile = await apiService.getUserById(userId);
      setState(() { _profile = profile; _loading = false; });
      auth.setCurrentUser(profile);
      _headerCtrl.forward();
    } catch (_) {
      setState(() {
        _loading = false;
        _profile = UserProfile(id: 1, name: 'Demo User', number: '9876543210',
          location: 'Bangalore', experience: 3, skills: [
            Skill(id: 1, name: 'Flutter'), Skill(id: 2, name: 'Dart'), Skill(id: 3, name: 'Java'),
          ]);
      });
      _headerCtrl.forward();
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.bgMuted, width: 1),
            boxShadow: AppTheme.cardShadow()),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Update Photo', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
            const SizedBox(height: 20),
            BrutalButton(label: 'Camera', onPressed: () => Navigator.pop(context, ImageSource.camera),
              color: AppTheme.accent, width: double.infinity,
              icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white)),
            const SizedBox(height: 10),
            BrutalButton(label: 'Gallery', onPressed: () => Navigator.pop(context, ImageSource.gallery),
              color: AppTheme.bgElevated, textColor: AppTheme.text, width: double.infinity,
              icon: const Icon(Icons.photo_library_rounded, size: 18, color: AppTheme.textMuted)),
          ]),
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    setState(() { _pickedImage = File(picked.path); _uploadingPhoto = true; });
    try {
      final updated = await apiService.uploadProfilePhoto(_profile!.id, _pickedImage!);
      setState(() { _profile = updated.copyWith(profilePhoto: updated.profilePhoto); _uploadingPhoto = false; });
    } catch (_) { setState(() => _uploadingPhoto = false); }
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(profile: _profile!));
    if (result != null && mounted) {
      try {
        final updated = await apiService.updateUser(_profile!.id, result);
        setState(() => _profile = updated);
      } catch (_) {}
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.bgMuted, width: 1)),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Sign out?', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
            const SizedBox(height: 8),
            const Text('Are you sure you want to log out?', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: BrutalButton(label: 'Cancel',
                onPressed: () => Navigator.pop(context, false),
                color: AppTheme.bgElevated, textColor: AppTheme.text)),
              const SizedBox(width: 12),
              Expanded(child: BrutalButton(label: 'Sign Out',
                onPressed: () => Navigator.pop(context, true), color: AppTheme.rose)),
            ]),
          ]),
        ),
      ),
    );
    if (ok == true && mounted) context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
          : SafeArea(
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildStats()),
                SliverToBoxAdapter(child: _buildSkills()),
                SliverToBoxAdapter(child: _buildActions()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ]),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D2E), Color(0xFF16192A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2), width: 1),
        boxShadow: AppTheme.glowShadow(radius: 40),
      ),
      child: Stack(children: [
        // Glow orb top-right
        Positioned(top: -40, right: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppTheme.accent.withOpacity(0.15), Colors.transparent])))),
        // Teal orb bottom-left
        Positioned(bottom: -30, left: -30,
          child: Container(width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppTheme.teal.withOpacity(0.1), Colors.transparent])))),

        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Profile', style: TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 22, color: AppTheme.text)),
              Row(children: [
                _IconBtn(icon: Icons.edit_rounded, onTap: _editProfile),
                const SizedBox(width: 8),
                _IconBtn(icon: Icons.logout_rounded, onTap: _logout, danger: true),
              ]),
            ]),
            const SizedBox(height: 28),
            // Avatar + floating orbs
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, __) => SizedBox(
                width: 180, height: 130,
                child: Stack(alignment: Alignment.center, children: [
                  // Floating orb 1 — career star
                  Positioned(right: 8, top: _floatAnim.value + 6,
                    child: _Orb(size: 38, color: AppTheme.teal, icon: Icons.trending_up_rounded)),
                  // Floating orb 2 — lightning bolt
                  Positioned(left: 8, bottom: -_floatAnim.value * 0.6,
                    child: _Orb(size: 30, color: AppTheme.accent, icon: Icons.bolt_rounded)),
                  // Avatar
                  GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: Stack(children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.heroGradient,
                          boxShadow: AppTheme.glowShadow(radius: 24),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(child: _uploadingPhoto
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2))
                          : _pickedImage != null ? Image.file(_pickedImage!, fit: BoxFit.cover)
                            : _profile?.profilePhoto != null
                                ? Image.network(_profile!.profilePhoto!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _DefaultAvatar(_profile?.name ?? 'U'))
                                : _DefaultAvatar(_profile?.name ?? 'U')),
                      ),
                      Positioned(bottom: 2, right: 2,
                        child: Container(width: 28, height: 28,
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient, shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.bgCard, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white))),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(_profile?.name ?? '', style: const TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5, color: AppTheme.text)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 3),
              Text(_profile?.location ?? '', style: const TextStyle(
                fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(children: [
        Expanded(child: _StatCard(label: 'Experience', value: '${_profile?.experience ?? 0} yrs',
          icon: Icons.work_rounded, color: AppTheme.accent)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Phone', value: _profile?.number ?? '–',
          icon: Icons.phone_rounded, color: AppTheme.teal)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Skills', value: '${_profile?.skills.length ?? 0}',
          icon: Icons.psychology_rounded, color: AppTheme.amber)),
      ]),
    );
  }

  Widget _buildSkills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: AppTheme.cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Skills', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.text)),
            const Spacer(),
            GestureDetector(
              onTap: _showAddSkillSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.accentShadow(),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Add', style: TextStyle(fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _profile?.skills.isEmpty ?? true
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No skills yet — add your expertise!',
                    style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint))))
              : Wrap(spacing: 8, runSpacing: 8,
                  children: _profile!.skills.map((s) => SkillChip(
                    label: s.name, onDelete: () => _removeSkill(s))).toList()),
        ]),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Account', style: TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5, color: AppTheme.textFaint)),
        const SizedBox(height: 12),
        _ActionRow(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: _editProfile),
        _ActionRow(icon: Icons.notifications_outlined, label: 'Notification Settings', onTap: () {}),
        _ActionRow(icon: Icons.security_outlined, label: 'Privacy & Security', onTap: () {}),
        _ActionRow(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () {}),
        const SizedBox(height: 8),
        _ActionRow(icon: Icons.logout_rounded, label: 'Sign Out', onTap: _logout, danger: true),
      ]),
    );
  }

  Future<void> _showAddSkillSheet() async {
    List<Skill> allSkills = [];
    try { allSkills = await apiService.getAllSkills(); }
    catch (_) { allSkills = [
      Skill(id: 1, name: 'Flutter'), Skill(id: 2, name: 'Dart'), Skill(id: 3, name: 'Java'),
      Skill(id: 4, name: 'Spring Boot'), Skill(id: 5, name: 'Python'), Skill(id: 6, name: 'React'),
      Skill(id: 7, name: 'Node.js'), Skill(id: 8, name: 'Kotlin'), Skill(id: 9, name: 'AWS'),
    ]; }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _AddSkillSheet(
        allSkills: allSkills,
        existingSkillIds: _profile?.skills.map((s) => s.id).toSet() ?? {},
        onAdd: (skill) async {
          try {
            final updated = await apiService.addSkillToUser(_profile!.id, skill.id);
            setState(() => _profile = updated);
          } catch (_) {
            setState(() => _profile = _profile?.copyWith(skills: [...?_profile?.skills, skill]));
          }
        },
      ),
    );
  }

  Future<void> _removeSkill(Skill skill) async {
    try {
      await apiService.removeSkillFromUser(_profile!.id, skill.id);
      setState(() => _profile = _profile?.copyWith(
          skills: _profile!.skills.where((s) => s.id != skill.id).toList()));
    } catch (_) {}
  }
}

// ── Sub-widgets ───────────────────────────────────────────────
class _DefaultAvatar extends StatelessWidget {
  final String name;
  const _DefaultAvatar(this.name);
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.bgMuted,
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800,
        fontSize: 36, color: AppTheme.text))),
  );
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final IconData icon;
  const _Orb({required this.size, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15), shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(0.4), width: 1),
      boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12)],
    ),
    child: Icon(icon, size: size * 0.46, color: color),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _IconBtn({required this.icon, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: danger ? AppTheme.rose.withOpacity(0.12) : AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger ? AppTheme.rose.withOpacity(0.3) : AppTheme.bgMuted, width: 1),
      ),
      child: Icon(icon, size: 18, color: danger ? AppTheme.rose : AppTheme.textMuted),
    ),
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
      Text(value, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800,
        fontSize: 13, color: color), overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontFamily: 'SpaceGrotesk',
        fontSize: 9, letterSpacing: 0.3, color: AppTheme.textFaint)),
    ]),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: AppTheme.cardDecoration(radius: 16),
      child: Row(children: [
        Icon(icon, size: 20, color: danger ? AppTheme.rose : AppTheme.textMuted),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w600, fontSize: 14,
          color: danger ? AppTheme.rose : AppTheme.text))),
        Icon(Icons.arrow_forward_ios_rounded, size: 13,
          color: danger ? AppTheme.rose.withOpacity(0.4) : AppTheme.textFaint),
      ]),
    ),
  );
}

class _EditSheet extends StatefulWidget {
  final UserProfile profile;
  const _EditSheet({required this.profile});
  @override State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _nameCtrl = TextEditingController(text: widget.profile.name);
  late final _locCtrl  = TextEditingController(text: widget.profile.location);
  late final _numCtrl  = TextEditingController(text: widget.profile.number);
  late final _expCtrl  = TextEditingController(text: '${widget.profile.experience}');

  @override
  void dispose() { _nameCtrl.dispose(); _locCtrl.dispose(); _numCtrl.dispose(); _expCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1)),
    ),
    padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.bgMuted, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      Row(children: [
        const Text('Edit Profile', style: TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
        const Spacer(),
        GestureDetector(onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
      ]),
      const SizedBox(height: 20),
      BrutalTextField(label: 'Full Name', controller: _nameCtrl, prefixIcon: const Icon(Icons.person_outline)),
      const SizedBox(height: 14),
      BrutalTextField(label: 'Location', controller: _locCtrl, prefixIcon: const Icon(Icons.location_on_outlined)),
      const SizedBox(height: 14),
      BrutalTextField(label: 'Phone', controller: _numCtrl, keyboardType: TextInputType.phone, prefixIcon: const Icon(Icons.phone_outlined)),
      const SizedBox(height: 14),
      BrutalTextField(label: 'Years of Experience', controller: _expCtrl, keyboardType: TextInputType.number, prefixIcon: const Icon(Icons.work_outline)),
      const SizedBox(height: 24),
      BrutalButton(label: 'Save Changes', width: double.infinity, onPressed: () {
        Navigator.pop(context, {
          'name': _nameCtrl.text.trim(), 'location': _locCtrl.text.trim(),
          'number': _numCtrl.text.trim(), 'experience': int.tryParse(_expCtrl.text) ?? 0,
        });
      }),
    ])),
  );
}

class _AddSkillSheet extends StatefulWidget {
  final List<Skill> allSkills;
  final Set<int> existingSkillIds;
  final Function(Skill) onAdd;
  const _AddSkillSheet({required this.allSkills, required this.existingSkillIds, required this.onAdd});
  @override State<_AddSkillSheet> createState() => _AddSkillSheetState();
}

class _AddSkillSheetState extends State<_AddSkillSheet> {
  String _search = '';
  List<Skill> get _filtered => widget.allSkills.where((s) =>
    !widget.existingSkillIds.contains(s.id) && s.name.toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.6,
    decoration: const BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1)),
    ),
    child: Column(children: [
      Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.bgMuted, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Add Skills', style: TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 16),
        BrutalTextField(label: 'Search skills', prefixIcon: const Icon(Icons.search_rounded),
          onChanged: (v) => setState(() => _search = v)),
      ])),
      Expanded(child: _filtered.isEmpty
        ? const Center(child: Text('No skills found', style: TextStyle(
            fontFamily: 'SpaceGrotesk', color: AppTheme.textMuted)))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final s = _filtered[i];
              return GestureDetector(
                onTap: () { widget.onAdd(s); Navigator.pop(context); },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: AppTheme.cardDecoration(radius: 14),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Text(s.name, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.text)),
                  ]),
                ),
              );
            })),
    ]),
  );
}
