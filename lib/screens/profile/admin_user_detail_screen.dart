import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  UserProfile? _profile;
  List<JobApplication>? _applications;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final p = await apiService.getUserById(widget.userId);
      final a = await apiService.getMyApplications(widget.userId);
      if (mounted) {
        setState(() {
          _profile = p;
          _applications = a;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    final updates = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: _profile!),
    );

    if (updates != null && mounted) {
      setState(() => _loading = true);
      try {
        final updated = await apiService.updateUser(_profile!.id, updates);
        setState(() {
          _profile = updated;
          _loading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_profile?.name ?? 'User Details', style: const TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk')),
        backgroundColor: AppTheme.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.text),
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editProfile,
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _profile == null
              ? const Center(child: Text('User not found.', style: TextStyle(color: AppTheme.text)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.bgElevated,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // User Basic Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.bgMuted),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppTheme.bgMuted,
                              child: Text(
                                _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text, fontSize: 32),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(_profile!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 20)),
                            const SizedBox(height: 8),
                            Text('${_profile!.location} · ${_profile!.experience}y exp', style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(_profile!.number, style: const TextStyle(color: AppTheme.teal, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Applications', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 18)),
                      const SizedBox(height: 12),
                      if (_applications == null || _applications!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(child: Text('No applications yet.', style: TextStyle(color: AppTheme.textMuted))),
                        )
                      else
                        ..._applications!.map((a) {
                          Color statusColor = AppTheme.textMuted;
                          if (a.status == 'ACCEPTED' || a.status == 'OFFERED') statusColor = AppTheme.teal;
                          if (a.status == 'REJECTED') statusColor = AppTheme.rose;
                          if (a.status == 'INTERVIEWING') statusColor = AppTheme.amber;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.bgMuted),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(a.jobTitle, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text, fontFamily: 'SpaceGrotesk', fontSize: 16))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text('Applied: ${a.appliedAt?.substring(0, 10)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        a.status,
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

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
            const Text('Update user information', style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 28),
            const Text('Full Name', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 6),
            BrutalTextField(label: 'Full Name', controller: _nameCtrl,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
            const SizedBox(height: 16),
            const Text('Location', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 6),
            BrutalTextField(label: 'City / Location', controller: _locCtrl,
                prefixIcon: const Icon(Icons.location_on_outlined),
                validator: (v) => v == null || v.trim().isEmpty ? 'Location is required' : null),
            const SizedBox(height: 16),
            const Text('Phone Number', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 6),
            BrutalTextField(label: 'Phone Number', controller: _numCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone number required';
                  if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Enter a valid 10-digit number';
                  return null;
                }),
            const SizedBox(height: 16),
            const Text('Years of Experience', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 6),
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
                  onPressed: _save, width: double.infinity)),
            ]),
          ]),
        ),
      ),
    );
  }
}
