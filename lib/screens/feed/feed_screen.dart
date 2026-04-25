import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import '../jobs/job_detail_screen.dart';

// ── Haversine distance ──────────────────────────────────────────────────────
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;

// Salary period options for the salary filter tab
enum _SalaryPeriod { hour, day, month, year }

extension _SalaryPeriodExt on _SalaryPeriod {
  String get label {
    switch (this) {
      case _SalaryPeriod.hour:  return 'Per Hour';
      case _SalaryPeriod.day:   return 'Per Day';
      case _SalaryPeriod.month: return 'Per Month';
      case _SalaryPeriod.year:  return 'Per Year';
    }
  }
  String get short {
    switch (this) {
      case _SalaryPeriod.hour:  return '/hr';
      case _SalaryPeriod.day:   return '/day';
      case _SalaryPeriod.month: return '/mo';
      case _SalaryPeriod.year:  return '/yr';
    }
  }
  // Default slider range per period
  double get defaultMin {
    switch (this) {
      case _SalaryPeriod.hour:  return 50;
      case _SalaryPeriod.day:   return 200;
      case _SalaryPeriod.month: return 5000;
      case _SalaryPeriod.year:  return 60000;
    }
  }
  double get defaultMax {
    switch (this) {
      case _SalaryPeriod.hour:  return 2000;
      case _SalaryPeriod.day:   return 5000;
      case _SalaryPeriod.month: return 150000;
      case _SalaryPeriod.year:  return 2000000;
    }
  }
  double get sliderMax {
    switch (this) {
      case _SalaryPeriod.hour:  return 5000;
      case _SalaryPeriod.day:   return 20000;
      case _SalaryPeriod.month: return 500000;
      case _SalaryPeriod.year:  return 5000000;
    }
  }
  String formatValue(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    return v.round().toString();
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Job> _nearestJobs = [], _skillMatchJobs = [], _salaryJobs = [];
  bool _loading = true;
  String? _error;

  // Salary filter
  _SalaryPeriod _salaryPeriod = _SalaryPeriod.month;
  late double _minSalary, _maxSalary;

  // Device GPS coords
  double? _deviceLat, _deviceLon;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _minSalary = _salaryPeriod.defaultMin;
    _maxSalary = _salaryPeriod.defaultMax;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFeed());
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _fetchLocation(int userId) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8));
      _deviceLat = pos.latitude;
      _deviceLon = pos.longitude;
      await apiService.updateUserLocation(userId, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  /// Attach Haversine distances to every job that has coordinates
  void _attachDistances(List<Job> jobs) {
    if (_deviceLat == null || _deviceLon == null) return;
    for (final job in jobs) {
      if (job.latitude != null && job.longitude != null) {
        job.distanceKm = _haversineKm(_deviceLat!, _deviceLon!, job.latitude!, job.longitude!);
      }
    }
  }

  Future<void> _loadFeed() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      int? userId = auth.currentUserId;

      if (userId == null) {
        userId = await apiService.getProfileId();
        if (userId != null) {
          try {
            final profile = await apiService.getUserById(userId);
            auth.setCurrentUser(profile);
          } catch (_) {}
        }
      }

      if (userId == null) {
        final jobsResult = await apiService.getJobs(page: 0, size: 20);
        setState(() {
          _nearestJobs = jobsResult.content;
          _skillMatchJobs = jobsResult.content;
          _salaryJobs = jobsResult.content;
          _loading = false;
        });
        return;
      }

      final locationFuture = _fetchLocation(userId);

      final results = await Future.wait([
        apiService.getSkillMatchJobs(userId).catchError((_) => <Job>[]),
        apiService.getJobsBySalary(_minSalary, _maxSalary, userId: userId).catchError((_) => <Job>[]),
        locationFuture.then((_) => <Job>[]).catchError((_) => <Job>[]),
      ]);

      List<Job> skillMatch = results[0];
      List<Job> salary = results[1];

      List<Job> nearest = [];
      try {
        final allJobsPage = await apiService.getJobs(page: 0, size: 50);
        final allJobs = allJobsPage.content
            .where((j) => j.createdById != userId)
            .toList();

        if (_deviceLat != null && _deviceLon != null) {
          for (final job in allJobs) {
            if (job.latitude != null && job.longitude != null) {
              job.distanceKm = _haversineKm(_deviceLat!, _deviceLon!, job.latitude!, job.longitude!);
            }
          }
          allJobs.sort((a, b) {
            final da = a.distanceKm ?? double.infinity;
            final db = b.distanceKm ?? double.infinity;
            return da.compareTo(db);
          });
          nearest = allJobs.take(10).toList();
        } else {
          nearest = await apiService.getNearestJobs(userId, k: 10).catchError((_) => allJobs.take(10).toList());
        }
      } catch (_) {
        nearest = skillMatch.isNotEmpty ? skillMatch : salary;
      }

      if (nearest.isEmpty && skillMatch.isEmpty) {
        try {
          final fallback = await apiService.getJobs(page: 0, size: 20);
          final filtered = fallback.content.where((j) => j.createdById != userId).toList();
          if (nearest.isEmpty) nearest = filtered;
          if (skillMatch.isEmpty) skillMatch = filtered;
        } catch (_) {}
      }

      // Attach distances to skill-match and salary lists too
      _attachDistances(skillMatch);
      _attachDistances(salary);

      setState(() {
        _nearestJobs = nearest;
        _skillMatchJobs = skillMatch;
        _salaryJobs = salary;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadSalary() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUserId ?? await apiService.getProfileId();
      final salary = await apiService.getJobsBySalary(_minSalary, _maxSalary, userId: userId)
          .catchError((_) => <Job>[]);
      _attachDistances(salary);
      if (mounted) setState(() => _salaryJobs = salary);
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your Feed', style: TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
                SizedBox(height: 2),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: _loadFeed,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.bgMuted, width: 1),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textMuted),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabController,
              isScrollable: false,
              dividerColor: AppTheme.bgMuted,
              tabs: const [Tab(text: 'Nearest'), Tab(text: 'Skill Match'), Tab(text: 'Salary')],
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? _buildShimmer()
              : TabBarView(controller: _tabController, children: [
                  _buildJobList(_nearestJobs, showDistance: true),
                  _buildJobList(_skillMatchJobs, showDistance: true),
                  _buildSalaryTab(),
                ]),
        ),
      ])),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(24),
    itemCount: 4,
    itemBuilder: (_, i) => const Padding(padding: EdgeInsets.only(bottom: 16), child: BrutalShimmer(height: 160)),
  );

  Widget _buildJobList(List<Job> jobs, {bool showDistance = false}) {
    if (jobs.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: AppTheme.bgElevated, shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bgMuted, width: 1)),
          child: const Icon(Icons.work_off_outlined, size: 32, color: AppTheme.textFaint),
        ),
        const SizedBox(height: 16),
        const Text('No jobs found', style: TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.text)),
        const SizedBox(height: 6),
        const Text('Try refreshing or adjusting filters', style: TextStyle(
            fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: AppTheme.accent,
      backgroundColor: AppTheme.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: jobs.length,
        itemBuilder: (_, i) {
          final job = jobs[i];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + i * 60),
            builder: (_, v, child) => Opacity(opacity: v,
              child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FeedJobCard(job: job, showDistance: showDistance,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalaryTab() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Period selector buttons
          const Text('Pay Period', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          Row(children: _SalaryPeriod.values.map((p) {
            final active = _salaryPeriod == p;
            return Expanded(child: GestureDetector(
              onTap: () {
                setState(() {
                  _salaryPeriod = p;
                  _minSalary = p.defaultMin;
                  _maxSalary = p.defaultMax;
                });
                _reloadSalary();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.only(right: p != _SalaryPeriod.year ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppTheme.accent : AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? AppTheme.accent : AppTheme.bgMuted),
                ),
                child: Center(child: Text(
                  p == _SalaryPeriod.hour ? 'Hour'
                    : p == _SalaryPeriod.day ? 'Day'
                    : p == _SalaryPeriod.month ? 'Month' : 'Year',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                      fontSize: 11, color: active ? Colors.white : AppTheme.textMuted),
                )),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
          // Range label
          Row(children: [
            const Text('Salary Range', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
              fontSize: 14, color: AppTheme.text)),
            const Spacer(),
            Text(
              '₹${_salaryPeriod.formatValue(_minSalary)}${_salaryPeriod.short} — ₹${_salaryPeriod.formatValue(_maxSalary)}${_salaryPeriod.short}',
              style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                fontSize: 13, color: AppTheme.accent)),
          ]),
          const SizedBox(height: 4),
          RangeSlider(
            values: RangeValues(_minSalary, _maxSalary),
            min: 0, max: _salaryPeriod.sliderMax, divisions: 100,
            onChanged: (v) => setState(() { _minSalary = v.start; _maxSalary = v.end; }),
            onChangeEnd: (_) => _reloadSalary(),
          ),
        ]),
      ),
      Expanded(child: _buildJobList(_salaryJobs, showDistance: true)),
    ]);
  }
}

class FeedJobCard extends StatefulWidget {
  final Job job;
  final VoidCallback onTap;
  final bool showDistance;
  const FeedJobCard({super.key, required this.job, required this.onTap, this.showDistance = false});
  @override State<FeedJobCard> createState() => _FeedJobCardState();
}

class _FeedJobCardState extends State<FeedJobCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _isSaved = apiService.isJobSaved(widget.job.id);
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  void _toggleSave() {
    apiService.toggleSaveJob(widget.job);
    setState(() => _isSaved = apiService.isJobSaved(widget.job.id));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, __) => Transform.scale(scale: 1 - _pressCtrl.value * 0.02,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bgElevated, width: 1),
              boxShadow: AppTheme.cardShadow(),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(
                        widget.job.createdByName?.substring(0, 1).toUpperCase() ?? '?',
                        style: const TextStyle(fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                      )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.job.title, style: const TextStyle(
                        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                        fontSize: 16, letterSpacing: -0.3, color: AppTheme.text)),
                      const SizedBox(height: 2),
                      Text(widget.job.createdByName ?? '', style: const TextStyle(
                        fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
                    ])),
                    GestureDetector(
                      onTap: _toggleSave,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _isSaved ? AppTheme.accent.withOpacity(0.15) : AppTheme.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isSaved ? AppTheme.accent.withOpacity(0.4) : AppTheme.bgMuted, width: 1),
                        ),
                        child: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                          size: 18, color: _isSaved ? AppTheme.accent : AppTheme.textFaint),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Chip(icon: Icons.location_on_outlined, text: widget.job.location),
                    _Chip(icon: Icons.currency_rupee, text: widget.job.salaryChip, accent: true),
                    if (widget.showDistance && widget.job.distanceKm != null)
                      _Chip(
                        icon: Icons.near_me_outlined,
                        text: widget.job.distanceKm! < 1
                            ? '< 1 km'
                            : '${widget.job.distanceKm!.round()} km',
                        teal: true,
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    JobTypeBadge(type: widget.job.jobType),
                    const SizedBox(width: 8),
                    ...widget.job.skills.take(2).map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6), child: SkillChip(label: s.name))),
                    if (widget.job.skills.length > 2)
                      Text('+${widget.job.skills.length - 2}', style: const TextStyle(
                        fontFamily: 'SpaceGrotesk', fontSize: 11, color: AppTheme.textFaint)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool accent;
  final bool teal;
  const _Chip({required this.icon, required this.text, this.accent = false, this.teal = false});

  @override
  Widget build(BuildContext context) {
    final color = teal ? AppTheme.teal : (accent ? AppTheme.accent : AppTheme.textMuted);
    final bg = teal ? AppTheme.teal.withOpacity(0.1) : (accent ? AppTheme.accent.withOpacity(0.1) : AppTheme.bgElevated);
    final border = teal ? AppTheme.teal.withOpacity(0.3) : (accent ? AppTheme.accent.withOpacity(0.3) : AppTheme.bgMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
          fontSize: 11, color: color)),
      ]),
    );
  }
}