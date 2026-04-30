import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import 'saved_jobs_screen.dart';
import 'applicant_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  UserProfile? _profile;
  bool _loading = true;
  File? _pickedImage;
  bool _uploadingPhoto = false;
  List<Job> _myJobs = [];
  bool _loadingJobs = false;
  final Map<int, List<JobApplication>> _applicantsMap = {};
  final Map<int, bool> _loadingApplicants = {};
  int? _expandedJobId;

  late AnimationController _headerCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _headerExpand;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _floatCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
          ..repeat(reverse: true);
    _headerExpand = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _floatAnim = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUserId;

    // FIX: If userId is null here the session was restored without a profile_id
    // (tryRestoreSession would have caught this and set status to unauthenticated,
    // but guard defensively in case the user navigates here via another path).
    if (userId == null) {
      setState(() => _loading = false);
      if (mounted) await context.read<AuthProvider>().forceLogout();
      return;
    }

    try {
      final profile = await apiService.getUserById(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
      auth.setCurrentUser(profile);
      _headerCtrl.forward();
      _loadMyJobs(userId);
    } on DioException catch (e) {
      if (!mounted) return;
      // FIX: A 401 here means the token is expired and could not be refreshed.
      // The interceptor already cleared the tokens. Log out cleanly so the
      // router sends the user back to the login screen instead of showing a
      // cryptic "DioException [bad response]" snackbar.
      if (e.response?.statusCode == 401) {
        await context.read<AuthProvider>().forceLogout();
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load profile: ${e.message ?? 'Network error'}'),
        backgroundColor: AppTheme.rose,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load profile: ${e.toString().split('\n').first}'),
        backgroundColor: AppTheme.rose,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _loadMyJobs(int userId) async {
    setState(() => _loadingJobs = true);
    try {
      final jobs = await apiService.getMyJobs(userId);
      if (mounted) setState(() { _myJobs = jobs; _loadingJobs = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _loadApplicants(int jobId) async {
    setState(() => _loadingApplicants[jobId] = true);
    try {
      final apps = await apiService.getApplicationsByJob(jobId);
      if (mounted) {
        setState(() {
          _applicantsMap[jobId] = apps;
          _loadingApplicants[jobId] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingApplicants[jobId] = false);
    }
  }

  Future<void> _updateApplicationStatus(JobApplication app, String status) async {
    try {
      await apiService.updateApplicationStatus(app.id, status);
      _loadApplicants(app.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status updated to $status'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteJob(Job job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.bgMuted, width: 1)),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppTheme.rose.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.rose.withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppTheme.rose, size: 26),
            ),
            const SizedBox(height: 16),
            const Text('Delete Job?', style: TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
            const SizedBox(height: 8),
            Text('Remove "${job.title}"? This cannot be undone.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: BrutalButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context, false),
                  color: AppTheme.bgElevated,
                  textColor: AppTheme.text)),
              const SizedBox(width: 12),
              Expanded(child: BrutalButton(
                  label: 'Delete',
                  onPressed: () => Navigator.pop(context, true),
                  color: AppTheme.rose)),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await apiService.deleteJob(job.id);
      setState(() {
        _myJobs.removeWhere((j) => j.id == job.id);
        _applicantsMap.remove(job.id);
        if (_expandedJobId == job.id) _expandedJobId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${job.title}" deleted'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete job'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.bgMuted, width: 1),
              boxShadow: AppTheme.cardShadow()),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Update Photo', style: TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
            const SizedBox(height: 20),
            BrutalButton(
                label: 'Camera',
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                color: AppTheme.accent, width: double.infinity,
                icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white)),
            const SizedBox(height: 10),
            BrutalButton(
                label: 'Gallery',
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
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
    } catch (_) {
      setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditProfileSheet(profile: _profile!));
    if (result != null && mounted) {
      try {
        final updated = await apiService.updateUser(_profile!.id, result);
        setState(() => _profile = updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Profile updated!'),
              backgroundColor: AppTheme.green,
              behavior: SnackBarBehavior.floating));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to save: ${_parseUpdateError(e)}'),
              backgroundColor: AppTheme.rose,
              behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  String _parseUpdateError(dynamic e) {
    try {
      final msg = (e as dynamic).response?.data?['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Please try again.';
  }

  void _openNotificationSettings() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _NotificationSettingsSheet());
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
                color: AppTheme.bgCard,
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
                Expanded(child: BrutalButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                    color: AppTheme.bgElevated, textColor: AppTheme.text)),
                const SizedBox(width: 12),
                Expanded(child: BrutalButton(
                    label: 'Sign Out',
                    onPressed: () => Navigator.pop(context, true),
                    color: AppTheme.rose)),
              ]),
            ]),
          )),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  // ── Pull-to-refresh ─────────────────────────────────────────
  Future<void> _onRefresh() async {
    _headerCtrl.reset();
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.accent,
                backgroundColor: AppTheme.bgCard,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildStats()),
                    SliverToBoxAdapter(child: _buildSkills()),
                    SliverToBoxAdapter(child: _buildMyJobs()),
                    SliverToBoxAdapter(child: _buildActions()),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
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
        Positioned(top: -40, right: -40, child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.accent.withOpacity(0.15), Colors.transparent])))),
        Positioned(bottom: -30, left: -30, child: Container(width: 120, height: 120,
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
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, __) => SizedBox(
                width: 180, height: 130,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(right: 8, top: _floatAnim.value + 6,
                      child: const _Orb(size: 38, color: AppTheme.teal, icon: Icons.trending_up_rounded)),
                  Positioned(left: 8, bottom: -_floatAnim.value * 0.6,
                      child: const _Orb(size: 30, color: AppTheme.accent, icon: Icons.bolt_rounded)),
                  GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: Stack(children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            gradient: AppTheme.heroGradient, boxShadow: AppTheme.glowShadow(radius: 24)),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                            child: _uploadingPhoto
                                ? const Center(child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2))
                                : _pickedImage != null
                                    ? Image.file(_pickedImage!, fit: BoxFit.cover)
                                    : _profile?.profilePhoto != null
                                        ? Image.network(_profile!.profilePhoto!, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _DefaultAvatar(_profile?.name ?? 'U'))
                                        : _DefaultAvatar(_profile?.name ?? 'U')),
                      ),
                      Positioned(bottom: 2, right: 2, child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(gradient: AppTheme.accentGradient,
                              shape: BoxShape.circle, border: Border.all(color: AppTheme.bgCard, width: 2)),
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
              Text(_profile?.location ?? '', style: const TextStyle(fontFamily: 'SpaceGrotesk',
                  fontSize: 13, color: AppTheme.textMuted)),
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
                decoration: BoxDecoration(gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.accentShadow()),
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
                  child: Text('No skills yet — add your expertise!', style: TextStyle(
                      fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint))))
              : Wrap(spacing: 8, runSpacing: 8,
                  children: _profile!.skills.map((s) =>
                      SkillChip(label: s.name, onDelete: () => _removeSkill(s))).toList()),
        ]),
      ),
    );
  }

  Widget _buildMyJobs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: AppTheme.cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('My Posted Jobs', style: TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.text)),
            const Spacer(),
            if (_myJobs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_myJobs.length}', style: const TextStyle(fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.accent)),
              ),
          ]),
          const SizedBox(height: 14),
          if (_loadingJobs)
            const Center(child: Padding(padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)))
          else if (_myJobs.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12),
                child: Text("You haven't posted any jobs yet.", style: TextStyle(
                    fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint))))
          else
            ...(_myJobs.map((job) {
              final isExpanded = _expandedJobId == job.id;
              final applicants = _applicantsMap[job.id] ?? [];
              final isLoadingApps = _loadingApplicants[job.id] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isExpanded ? AppTheme.accent.withOpacity(0.4) : AppTheme.bgMuted,
                      width: 1),
                ),
                child: Column(children: [
                  GestureDetector(
                    onTap: () {
                      final newId = isExpanded ? null : job.id;
                      setState(() => _expandedJobId = newId);
                      if (newId != null && !_applicantsMap.containsKey(job.id)) {
                        _loadApplicants(job.id);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(job.title, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.text)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on_outlined, size: 11, color: AppTheme.textFaint),
                            const SizedBox(width: 3),
                            Text(job.location, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                                fontSize: 12, color: AppTheme.textMuted)),
                            const SizedBox(width: 10),
                            // FIX: Use currency icon + salaryDisplay (no double ₹)
                            const Icon(Icons.currency_rupee, size: 11, color: AppTheme.accent),
                            Text(job.salaryDisplay, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.accent)),
                          ]),
                        ])),
                        JobTypeBadge(type: job.jobType),
                        const SizedBox(width: 8),
                        // Delete button
                        GestureDetector(
                          onTap: () => _deleteJob(job),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.rose.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.rose.withOpacity(0.25), width: 1),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.rose),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.people_outline_rounded,
                          size: 18,
                          color: isExpanded ? AppTheme.accent : AppTheme.textFaint,
                        ),
                      ]),
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(height: 1, color: AppTheme.bgMuted),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.people_rounded, size: 14, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Text('Applicants${applicants.isNotEmpty ? " (${applicants.length})" : ""}',
                            style: const TextStyle(fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.accent)),
                        ]),
                        const SizedBox(height: 10),
                        if (isLoadingApps)
                          const Center(child: Padding(padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)))
                        else if (applicants.isEmpty)
                          const Text('No applicants yet.', style: TextStyle(
                              fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.textFaint))
                        else
                          ...applicants.map((app) => _ApplicantRow(
                            app: app,
                            onUpdateStatus: (status) => _updateApplicationStatus(app, status),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ApplicantDetailScreen(app: app))),
                          )),
                      ]),
                    ),
                  ],
                ]),
              );
            })),
        ]),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Account', style: TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5, color: AppTheme.textFaint)),
        const SizedBox(height: 12),
        if (_profile?.isVerified == false)
          _ActionRow(
            icon: Icons.verified_user_outlined,
            label: 'Verify Account',
            onTap: _verifyAccount,
            danger: true,
            badge: 1, // Just to show an alert style
          ),
        _ActionRow(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: _editProfile),
        // Saved Jobs
        _ActionRow(
          icon: Icons.bookmark_outline_rounded,
          label: 'Saved Jobs',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedJobsScreen())),
          badge: apiService.getSavedJobs().length,
        ),
        _ActionRow(icon: Icons.notifications_outlined, label: 'Notification Settings', onTap: _openNotificationSettings),
        _ActionRow(icon: Icons.security_outlined, label: 'Privacy & Security', onTap: () => _showComingSoon('Privacy & Security')),
        _ActionRow(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => _showComingSoon('Help & Support')),
        const SizedBox(height: 8),
        _ActionRow(icon: Icons.logout_rounded, label: 'Sign Out', onTap: _logout, danger: true),
      ]),
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$title coming soon!'),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _verifyAccount() async {
    if (_profile == null) return;
    // Use a dedicated StatefulWidget instead of StatefulBuilder to avoid:
    // 1. Context shadowing (builder's `context` param hiding outer screen context)
    // 2. setModalState becoming stale after async gaps
    // 3. ScaffoldMessenger using a context that has no Scaffold ancestor
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerifyAccountSheet(username: context.read<AuthProvider>().username),
    );

    if (success == true && mounted) {
      final auth = context.read<AuthProvider>();
      await auth.refreshUserProfile();
      if (mounted) {
        setState(() => _profile = auth.currentUser);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account Verified! ✓'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _showAddSkillSheet() async {
    List<Skill> allSkills = [];
    try {
      allSkills = await apiService.getAllSkills();
    } catch (_) {
      allSkills = [
        Skill(id: 1, name: 'Flutter'), Skill(id: 2, name: 'Dart'),
        Skill(id: 3, name: 'Java'), Skill(id: 4, name: 'Spring Boot'),
        Skill(id: 5, name: 'Python'), Skill(id: 6, name: 'React'),
        Skill(id: 7, name: 'Node.js'), Skill(id: 8, name: 'Kotlin'),
        Skill(id: 9, name: 'AWS'),
      ];
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

// ═══════════════════════════════════════════════════════════════════════════
// EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  final UserProfile profile;
  const _EditProfileSheet({required this.profile});
  @override State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.profile.name);
  late final _locCtrl  = TextEditingController(text: widget.profile.location);
  late final _numCtrl  = TextEditingController(text: widget.profile.number);
  late final _expCtrl  = TextEditingController(text: '${widget.profile.experience}');
  final bool _saving   = false;

  @override
  void dispose() { _nameCtrl.dispose(); _locCtrl.dispose(); _numCtrl.dispose(); _expCtrl.dispose(); super.dispose(); }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'location': _locCtrl.text.trim(),
      'number': _numCtrl.text.trim(),
      'experience': int.tryParse(_expCtrl.text) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.bgMuted, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Edit Profile', style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text))),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 8),
            const Text('Update your personal information', style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 28),
            const _FieldLabel('Full Name'), const SizedBox(height: 6),
            BrutalTextField(label: 'Full Name', controller: _nameCtrl,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
            const SizedBox(height: 16),
            const _FieldLabel('Location'), const SizedBox(height: 6),
            BrutalTextField(label: 'City / Location', controller: _locCtrl,
                prefixIcon: const Icon(Icons.location_on_outlined),
                validator: (v) => v == null || v.trim().isEmpty ? 'Location is required' : null),
            const SizedBox(height: 16),
            const _FieldLabel('Phone Number'), const SizedBox(height: 6),
            BrutalTextField(label: 'Phone Number', controller: _numCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone number required';
                  if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Enter a valid 10-digit number';
                  return null;
                }),
            const SizedBox(height: 16),
            const _FieldLabel('Years of Experience'), const SizedBox(height: 6),
            BrutalTextField(label: 'e.g. 3', controller: _expCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.work_outline),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null || n < 0 || n > 50) return 'Enter a number between 0 and 50';
                  return null;
                }),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: BrutalButton(label: 'Cancel', onPressed: () => Navigator.pop(context),
                  color: AppTheme.bgElevated, textColor: AppTheme.text)),
              const SizedBox(width: 12),
              Expanded(child: BrutalButton(label: 'Save Changes',
                  onPressed: _saving ? null : _save, isLoading: _saving, width: double.infinity)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION SETTINGS SHEET (unchanged from original)
// ═══════════════════════════════════════════════════════════════════════════
class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet();
  @override State<_NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<_NotificationSettingsSheet> {
  bool _jobMatches = true, _applicationUpdates = true, _newMessages = true,
      _profileViews = false, _weeklyDigest = true, _marketingEmails = false,
      _pushEnabled = true, _emailEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.bgMuted, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.teal.withOpacity(0.3), width: 1)),
                child: const Icon(Icons.notifications_rounded, size: 18, color: AppTheme.teal)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Notification Settings', style: TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text))),
            GestureDetector(onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
          ]),
          const SizedBox(height: 4),
          const Text('Control how and when you hear from us', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 28),
          const _SectionHeader('Channels'), const SizedBox(height: 12),
          _ToggleTile(icon: Icons.phone_android_rounded, color: AppTheme.accent, title: 'Push Notifications',
              subtitle: 'Receive alerts on your device', value: _pushEnabled, onChanged: (v) => setState(() => _pushEnabled = v)),
          _ToggleTile(icon: Icons.email_outlined, color: AppTheme.teal, title: 'Email Notifications',
              subtitle: 'Receive updates by email', value: _emailEnabled, onChanged: (v) => setState(() => _emailEnabled = v)),
          const SizedBox(height: 20),
          const _SectionHeader('Activity'), const SizedBox(height: 12),
          _ToggleTile(icon: Icons.work_rounded, color: AppTheme.accent, title: 'Job Matches',
              subtitle: 'New jobs that match your skills', value: _jobMatches, onChanged: (v) => setState(() => _jobMatches = v)),
          _ToggleTile(icon: Icons.assignment_turned_in_rounded, color: AppTheme.green, title: 'Application Updates',
              subtitle: 'Status changes on your applications', value: _applicationUpdates, onChanged: (v) => setState(() => _applicationUpdates = v)),
          _ToggleTile(icon: Icons.chat_bubble_outline_rounded, color: AppTheme.blue, title: 'New Messages',
              subtitle: 'Messages from recruiters', value: _newMessages, onChanged: (v) => setState(() => _newMessages = v)),
          _ToggleTile(icon: Icons.visibility_outlined, color: AppTheme.amber, title: 'Profile Views',
              subtitle: 'When someone views your profile', value: _profileViews, onChanged: (v) => setState(() => _profileViews = v)),
          const SizedBox(height: 20),
          const _SectionHeader('Digest & Marketing'), const SizedBox(height: 12),
          _ToggleTile(icon: Icons.summarize_outlined, color: AppTheme.teal, title: 'Weekly Digest',
              subtitle: 'Top job picks every Monday', value: _weeklyDigest, onChanged: (v) => setState(() => _weeklyDigest = v)),
          _ToggleTile(icon: Icons.campaign_outlined, color: AppTheme.textFaint, title: 'Marketing Emails',
              subtitle: 'Offers, tips and product news', value: _marketingEmails, onChanged: (v) => setState(() => _marketingEmails = v)),
          const SizedBox(height: 28),
          BrutalButton(
            label: 'Save Preferences',
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Notification preferences saved!'),
                  backgroundColor: AppTheme.green, behavior: SnackBarBehavior.floating));
            },
            width: double.infinity,
          ),
        ]),
      ),
    );
  }
}

// ── Small helpers ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text; const _FieldLabel(this.text);
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 12,
      letterSpacing: 0.3, color: AppTheme.textMuted));
}

class _SectionHeader extends StatelessWidget {
  final String text; const _SectionHeader(this.text);
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13,
      letterSpacing: 0.5, color: AppTheme.textFaint));
}

class _ToggleTile extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle;
  final bool value; final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.color, required this.title,
      required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? color.withOpacity(0.25) : AppTheme.bgMuted, width: 1)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: value ? color.withOpacity(0.12) : AppTheme.bgMuted,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: value ? color : AppTheme.textFaint)),
      title: Text(title, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
          fontSize: 14, color: value ? AppTheme.text : AppTheme.textMuted)),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'SpaceGrotesk',
          fontSize: 11, color: AppTheme.textFaint)),
      trailing: Switch(value: value, onChanged: onChanged,
          activeThumbColor: color, activeTrackColor: color.withOpacity(0.3),
          inactiveThumbColor: AppTheme.textFaint, inactiveTrackColor: AppTheme.bgMuted),
    ),
  );
}

class _DefaultAvatar extends StatelessWidget {
  final String name; const _DefaultAvatar(this.name);
  @override Widget build(BuildContext context) => Container(
    color: AppTheme.bgMuted,
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800,
            fontSize: 36, color: AppTheme.text))));
}

class _Orb extends StatelessWidget {
  final double size; final Color color; final IconData icon;
  const _Orb({required this.size, required this.color, required this.icon});
  @override Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12)]),
    child: Icon(icon, size: size * 0.46, color: color));
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool danger;
  const _IconBtn({required this.icon, required this.onTap, this.danger = false});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: danger ? AppTheme.rose.withOpacity(0.12) : AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger ? AppTheme.rose.withOpacity(0.3) : AppTheme.bgMuted, width: 1)),
      child: Icon(icon, size: 18, color: danger ? AppTheme.rose : AppTheme.textMuted)));
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2), width: 1)),
    child: Column(children: [
      Icon(icon, size: 22, color: color), const SizedBox(height: 6),
      Text(value, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800,
          fontSize: 13, color: color), overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 9,
          letterSpacing: 0.3, color: AppTheme.textFaint)),
    ]));
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  final bool danger; final int badge;
  const _ActionRow({required this.icon, required this.label, required this.onTap,
      this.danger = false, this.badge = 0});
  @override Widget build(BuildContext context) => GestureDetector(
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
        if (badge > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('$badge', style: const TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.accent)),
          ),
          const SizedBox(width: 6),
        ],
        Icon(Icons.arrow_forward_ios_rounded, size: 13,
            color: danger ? AppTheme.rose.withOpacity(0.4) : AppTheme.textFaint),
      ]),
    ));
}

// ═══════════════════════════════════════════════════════════════════════════
// APPLICANT ROW — shows only name; tap opens ApplicantDetailScreen
// ═══════════════════════════════════════════════════════════════════════════
class _ApplicantRow extends StatelessWidget {
  final JobApplication app;
  final void Function(String status) onUpdateStatus;
  final VoidCallback onTap;
  const _ApplicantRow({required this.app, required this.onUpdateStatus, required this.onTap});

  static const _statuses = ['PENDING', 'SHORTLISTED', 'HIRED', 'REJECTED'];

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'SHORTLISTED': return AppTheme.amber;
      case 'HIRED':       return AppTheme.green;
      case 'REJECTED':    return AppTheme.rose;
      default:            return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = app.displayName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.bgMuted, width: 1)),
        child: Row(children: [
          // Avatar initial
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.accent))),
          ),
          const SizedBox(width: 10),
          // Name only
          Expanded(
            child: Text(name,
                style: const TextStyle(fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.text),
                overflow: TextOverflow.ellipsis),
          ),
          // Tap hint
          const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textFaint),
          const SizedBox(width: 8),
          // Status dropdown
          PopupMenuButton<String>(
            initialValue: app.status,
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: onUpdateStatus,
            itemBuilder: (_) => _statuses.map((s) => PopupMenuItem<String>(
              value: s,
              child: Text(s, style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600, fontSize: 13, color: _statusColor(s))),
            )).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _statusColor(app.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(app.status).withOpacity(0.4), width: 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(app.status, style: TextStyle(fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700, fontSize: 10, color: _statusColor(app.status))),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded, size: 14, color: _statusColor(app.status)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VERIFY ACCOUNT SHEET — proper StatefulWidget to avoid StatefulBuilder pitfalls:
//   • No context shadowing (builder param hiding outer screen context)
//   • setState is always called on THIS widget's State, never on a stale closure
//   • ScaffoldMessenger uses the sheet's own mounted context safely
// ═══════════════════════════════════════════════════════════════════════════
class _VerifyAccountSheet extends StatefulWidget {
  final String? username;
  const _VerifyAccountSheet({this.username});
  @override State<_VerifyAccountSheet> createState() => _VerifyAccountSheetState();
}

class _VerifyAccountSheetState extends State<_VerifyAccountSheet> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  bool _otpSent   = false;
  bool _sending   = false;
  bool _verifying = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // Extracts human-readable error from a DioException.
  // The backend's APIError DTO uses the key "error", not "message".
  String _parseError(dynamic e, String fallback) {
    if (e is DioException) {
      return ApiService.extractApiError(e, fallback: fallback);
    }
    return fallback;
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    setState(() => _sending = true);
    try {
      await apiService.sendOtp(
        type: 'EMAIL',
        value: email,
        username: widget.username,
      );
      if (!mounted) return;
      setState(() { _sending = false; _otpSent = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(_parseError(e, 'Failed to send OTP. Please try again.'));
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) return;
    setState(() => _verifying = true);
    try {
      await apiService.verifyOtp(
        type: 'EMAIL',
        value: _emailCtrl.text.trim(),
        otp: otp,
        username: widget.username,
      );
      if (!mounted) return;
      setState(() => _verifying = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _showError(_parseError(e, 'Incorrect OTP. Please try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Verify Account',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                    fontSize: 20, color: AppTheme.text))),
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
              ]),
              const SizedBox(height: 8),
              const Text('Verifying your email builds trust with employers.',
                style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 24),
              if (!_otpSent) ...[
                BrutalTextField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  prefixIcon: const Icon(Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                BrutalButton(
                  label: 'Send OTP',
                  isLoading: _sending,
                  width: double.infinity,
                  onPressed: _sending ? null : _sendOtp,
                ),
              ] else ...[
                Text('Enter the code sent to ${_emailCtrl.text}',
                  style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13,
                    color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                BrutalTextField(
                  label: '6-digit code',
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _sending ? null : () => setState(() { _otpSent = false; _otpCtrl.clear(); }),
                  child: const Text('Wrong email? Go back',
                    style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12,
                      color: AppTheme.accent, decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 16),
                BrutalButton(
                  label: 'Verify',
                  isLoading: _verifying,
                  width: double.infinity,
                  onPressed: _verifying ? null : _verifyOtp,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADD SKILL SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _AddSkillSheet extends StatefulWidget {
  final List<Skill> allSkills;
  final Set<int> existingSkillIds;
  final Function(Skill) onAdd;
  const _AddSkillSheet({required this.allSkills, required this.existingSkillIds, required this.onAdd});
  @override State<_AddSkillSheet> createState() => _AddSkillSheetState();
}

class _AddSkillSheetState extends State<_AddSkillSheet> {
  String _search = '';
  List<Skill> get _filtered => widget.allSkills
      .where((s) => !widget.existingSkillIds.contains(s.id) &&
          s.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.6,
    decoration: const BoxDecoration(color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1))),
    child: Column(children: [
      Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.bgMuted, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Add Skills', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 16),
        BrutalTextField(label: 'Search skills',
            prefixIcon: const Icon(Icons.search_rounded),
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
                      const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.accent),
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