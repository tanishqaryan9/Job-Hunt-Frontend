import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal_widgets.dart';
import 'admin_user_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  
  final List<UserProfile> _users = [];
  bool _loadingUsers = true;
  int _userPage = 0;
  bool _hasMoreUsers = true;
  final Set<int> _selectedUsers = {};
  
  List<Skill> _skills = [];
  bool _loadingSkills = true;
  final Set<int> _selectedSkills = {};

  final List<Job> _jobs = [];
  bool _loadingJobs = true;
  int _jobPage = 0;
  bool _hasMoreJobs = true;
  final Set<int> _selectedJobs = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
    _loadUsers();
    _loadSkills();
    _loadJobs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      _userPage = 0;
      _hasMoreUsers = true;
      setState(() {
        _loadingUsers = true;
        _selectedUsers.clear();
      });
    }
    if (!_hasMoreUsers) return;

    try {
      final res = await apiService.getUsers(page: _userPage);
      if (mounted) {
        setState(() {
          if (refresh) _users.clear();
          _users.addAll(res.content.where((u) => u.role != 'ROLE_ADMIN'));
          _hasMoreUsers = res.page < res.totalPages - 1;
          _userPage++;
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _deleteUsers(List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete ${ids.length} User(s)', style: const TextStyle(color: AppTheme.rose, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: const Text('Are you sure? This cannot be undone.', style: TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.rose))),
        ],
      ),
    );

    if (ok == true && mounted) {
      try {
        for (var id in ids) {
          await apiService.deleteUserAsAdmin(id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} user(s) deleted'), backgroundColor: AppTheme.green));
          _loadUsers(refresh: true);
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete user(s)'), backgroundColor: AppTheme.rose));
      }
    }
  }

  Future<void> _loadSkills() async {
    if (!mounted) return;
    setState(() {
      _loadingSkills = true;
      _selectedSkills.clear();
    });
    try {
      final skills = await apiService.getSkills();
      if (mounted) setState(() { _skills = skills; _loadingSkills = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSkills = false);
    }
  }

  Future<void> _addSkill() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('New Skill', style: TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: BrutalTextField(label: 'Skill Name', controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Add', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      try {
        await apiService.createSkill(name);
        _loadSkills();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create skill'), backgroundColor: AppTheme.rose));
      }
    }
  }

  Future<void> _deleteSkills(List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete ${ids.length} Skill(s)', style: const TextStyle(color: AppTheme.rose, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: const Text('Are you sure? This cannot be undone.', style: TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.rose))),
        ],
      ),
    );

    if (ok == true && mounted) {
      try {
        for (var id in ids) {
          await apiService.deleteSkillAsAdmin(id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} skill(s) deleted'), backgroundColor: AppTheme.green));
          _loadSkills();
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete skill(s)'), backgroundColor: AppTheme.rose));
      }
    }
  }

  // ============== JOBS TAB ============== //

  Future<void> _loadJobs({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      _jobPage = 0;
      _hasMoreJobs = true;
      setState(() {
        _loadingJobs = true;
        _selectedJobs.clear();
      });
    }
    if (!_hasMoreJobs) return;

    try {
      final res = await apiService.getJobs(page: _jobPage);
      if (mounted) {
        setState(() {
          if (refresh) _jobs.clear();
          _jobs.addAll(res.content);
          _hasMoreJobs = res.page < res.totalPages - 1;
          _jobPage++;
          _loadingJobs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _deleteJobs(List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete ${ids.length} Job(s)', style: const TextStyle(color: AppTheme.rose, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: const Text('Are you sure? This cannot be undone.', style: TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.rose))),
        ],
      ),
    );

    if (ok == true && mounted) {
      try {
        for (var id in ids) {
          await apiService.deleteJob(id); // Using the standard delete job method
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} job(s) deleted'), backgroundColor: AppTheme.green));
          _loadJobs(refresh: true);
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete job(s)'), backgroundColor: AppTheme.rose));
      }
    }
  }

  Future<void> _showJobApplications(Job job) async {
    final List<JobApplication> applications = [];
    bool loading = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Future<void> load() async {
          try {
            final items = await apiService.getApplicationsByJob(job.id);
            applications
              ..clear()
              ..addAll(items);
          } finally {
            loading = false;
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading && applications.isEmpty) {
              load().then((_) {
                if (context.mounted) setModalState(() {});
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applications: ${job.title}',
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (loading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          ),
                        )
                      else if (applications.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No applications yet.',
                              style: TextStyle(color: AppTheme.textMuted, fontFamily: 'SpaceGrotesk'),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: applications.length,
                            itemBuilder: (context, index) {
                              final app = applications[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  title: Text(
                                    app.displayName,
                                    style: const TextStyle(
                                      color: AppTheme.text,
                                      fontFamily: 'SpaceGrotesk',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Status: ${app.status}',
                                    style: const TextStyle(color: AppTheme.textMuted, fontFamily: 'SpaceGrotesk'),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.edit_outlined, color: AppTheme.accent),
                                        color: AppTheme.bgCard,
                                        onSelected: (status) async {
                                          try {
                                            final updated = await apiService.updateApplicationStatus(app.id, status);
                                            applications[index] = updated;
                                            if (context.mounted) setModalState(() {});
                                          } catch (_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Failed to update status'),
                                                  backgroundColor: AppTheme.rose,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'PENDING', child: Text('PENDING')),
                                          PopupMenuItem(value: 'REVIEWED', child: Text('REVIEWED')),
                                          PopupMenuItem(value: 'SHORTLISTED', child: Text('SHORTLISTED')),
                                          PopupMenuItem(value: 'REJECTED', child: Text('REJECTED')),
                                          PopupMenuItem(value: 'ACCEPTED', child: Text('ACCEPTED')),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.rose),
                                        onPressed: () async {
                                          try {
                                            await apiService.deleteApplication(app.id);
                                            applications.removeAt(index);
                                            if (context.mounted) setModalState(() {});
                                          } catch (_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Failed to delete application'),
                                                  backgroundColor: AppTheme.rose,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUsersTab = _tabCtrl.index == 0;
    final bool isSkillsTab = _tabCtrl.index == 1;
    final int selectedCount = isUsersTab ? _selectedUsers.length : (isSkillsTab ? _selectedSkills.length : _selectedJobs.length);
    final bool hasSelection = selectedCount > 0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: hasSelection
            ? Text('$selectedCount Selected', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.accent))
            : const Text('Admin Dashboard', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
        backgroundColor: AppTheme.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.text),
        leading: hasSelection
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectedUsers.clear();
                  _selectedSkills.clear();
                  _selectedJobs.clear();
                }),
              )
            : IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  context.read<AuthProvider>().logout();
                },
              ),
        actions: [
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.rose),
              onPressed: () {
                if (isUsersTab) {
                  _deleteUsers(_selectedUsers.toList());
                } else if (isSkillsTab) {
                  _deleteSkills(_selectedSkills.toList());
                } else {
                  _deleteJobs(_selectedJobs.toList());
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Users'), Tab(text: 'Skills'), Tab(text: 'Jobs')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: hasSelection ? const NeverScrollableScrollPhysics() : null, // Prevent swipe when selecting
        children: [
          _buildUsersTab(),
          _buildSkillsTab(),
          _buildJobsTab(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return _loadingUsers && _userPage == 0
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : RefreshIndicator(
            onRefresh: () => _loadUsers(refresh: true),
            color: AppTheme.accent,
            backgroundColor: AppTheme.bgElevated,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length + (_hasMoreUsers ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  _loadUsers();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                  );
                }
                final u = _users[index];
                final bool isSelected = _selectedUsers.contains(u.id);

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _selectedUsers.add(u.id);
                    });
                  },
                  onTap: () {
                    if (_selectedUsers.isNotEmpty) {
                      setState(() {
                        if (isSelected) {
                          _selectedUsers.remove(u.id);
                        } else {
                          _selectedUsers.add(u.id);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: u.id)),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.bgMuted,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.bgMuted,
                          child: Text(
                            u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'SpaceGrotesk',
                                  color: AppTheme.text,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${u.location} · ${u.experience}y exp',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'SpaceGrotesk',
                                ),
                              ),
                              if (u.role == 'ROLE_ADMIN')
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(color: AppTheme.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
  }

  Widget _buildSkillsTab() {
    return _loadingSkills
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                itemCount: _skills.length,
                itemBuilder: (context, index) {
                  final s = _skills[index];
                  final bool isSelected = _selectedSkills.contains(s.id);

                  return GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _selectedSkills.add(s.id);
                      });
                    },
                    onTap: () {
                      if (_selectedSkills.isNotEmpty) {
                        setState(() {
                          if (isSelected) {
                            _selectedSkills.remove(s.id);
                          } else {
                            _selectedSkills.add(s.id);
                          }
                        });
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.accent : Colors.transparent,
                          width: isSelected ? 2 : 0,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          s.name,
                          style: const TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                  backgroundColor: AppTheme.accent,
                  onPressed: _addSkill,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          );
  }

  Widget _buildJobsTab() {
    return _loadingJobs && _jobPage == 0
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : RefreshIndicator(
            onRefresh: () => _loadJobs(refresh: true),
            color: AppTheme.accent,
            backgroundColor: AppTheme.bgElevated,
            child: ListView.builder(
              padding: const EdgeInsets.all(16).copyWith(bottom: 80),
              itemCount: _jobs.length,
              itemBuilder: (context, index) {
                if (index == _jobs.length - 1 && _hasMoreJobs) {
                  _loadJobs();
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  );
                }

                final j = _jobs[index];
                final bool isSelected = _selectedJobs.contains(j.id);
                
                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _selectedJobs.add(j.id);
                    });
                  },
                  onTap: () {
                    if (_selectedJobs.isNotEmpty) {
                      setState(() {
                        if (isSelected) {
                          _selectedJobs.remove(j.id);
                        } else {
                          _selectedJobs.add(j.id);
                        }
                      });
                    } else {
                      _showJobApplications(j);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : Colors.transparent,
                        width: isSelected ? 2 : 0,
                      ),
                    ),
                    child: ListTile(
                      title: Text(j.title, style: const TextStyle(color: AppTheme.text, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600)),
                      subtitle: Text('${j.location} • ${j.jobType}', style: const TextStyle(color: AppTheme.textMuted, fontFamily: 'SpaceGrotesk', fontSize: 13)),
                      trailing: Text(j.salaryDisplay, style: const TextStyle(color: AppTheme.accent, fontFamily: 'SpaceGrotesk', fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ),
                );
              },
            ),
          );
  }
}
