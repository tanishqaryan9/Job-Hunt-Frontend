import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import '../jobs/job_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Job> _nearestJobs = [], _skillMatchJobs = [], _salaryJobs = [];
  bool _loading = true;
  String? _error;
  double _minSalary = 100, _maxSalary = 150000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFeed());
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadFeed() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUserId;
      if (userId == null) { setState(() { _loading = false; _error = 'Not logged in.'; }); return; }
      final results = await Future.wait([
        apiService.getNearestJobs(userId, k: 10),
        apiService.getSkillMatchJobs(userId),
        apiService.getJobsBySalary(_minSalary, _maxSalary),
      ]);
      setState(() { _nearestJobs = results[0]; _skillMatchJobs = results[1]; _salaryJobs = results[2]; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Could not load feed';
        _nearestJobs = _skillMatchJobs = _salaryJobs = _demoJobs();
        _loading = false;
      });
    }
  }

  List<Job> _demoJobs() => [
    Job(id: 1, title: 'Senior Flutter Developer', description: 'Build amazing apps', location: 'Bangalore', salary: 120000, jobType: 'FULL_TIME', createdByName: 'TechCorp'),
    Job(id: 2, title: 'Backend Engineer', description: 'Spring Boot microservices', location: 'Mumbai', salary: 95000, jobType: 'FULL_TIME', createdByName: 'StartupXYZ'),
    Job(id: 3, title: 'UI/UX Designer', description: 'Design pixel-perfect interfaces', location: 'Delhi', salary: 75000, jobType: 'CONTRACT', createdByName: 'DesignStudio'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Feed', style: TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
                const SizedBox(height: 2),
                Text('AI-powered recommendations', style: TextStyle(
                  fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
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
        // Content
        Expanded(
          child: _loading
              ? _buildShimmer()
              : TabBarView(controller: _tabController, children: [
                  _buildJobList(_nearestJobs, showDistance: true),
                  _buildJobList(_skillMatchJobs),
                  _buildSalaryTab(),
                ]),
        ),
      ])),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(24),
    itemCount: 4,
    itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 16), child: BrutalShimmer(height: 160)),
  );

  Widget _buildJobList(List<Job> jobs, {bool showDistance = false}) {
    if (jobs.isEmpty) return Center(child: Text('No jobs found',
      style: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textMuted)));
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
          Row(children: [
            const Text('Salary Range', style: TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
              fontSize: 14, color: AppTheme.text)),
            const Spacer(),
            Text('₹${(_minSalary / 1000).round()}K — ₹${(_maxSalary / 1000).round()}K',
              style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                fontSize: 14, color: AppTheme.accent)),
          ]),
          const SizedBox(height: 8),
          RangeSlider(
            values: RangeValues(_minSalary, _maxSalary),
            min: 100, max: 500000, divisions: 100,
            onChanged: (v) => setState(() { _minSalary = v.start; _maxSalary = v.end; }),
            onChangeEnd: (_) => _loadFeed(),
          ),
        ]),
      ),
      Expanded(child: _buildJobList(_salaryJobs)),
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
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

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
              // Top gradient accent
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Company avatar
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
                      onTap: () => setState(() => _isSaved = !_isSaved),
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
                    _Chip(icon: Icons.currency_rupee, text: '${(widget.job.salary / 1000).round()}K/mo', accent: true),
                    if (widget.showDistance && widget.job.distanceKm != null)
                      _Chip(icon: Icons.near_me_outlined, text: '${widget.job.distanceKm!.round()}km'),
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
  const _Chip({required this.icon, required this.text, this.accent = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: accent ? AppTheme.accent.withOpacity(0.1) : AppTheme.bgElevated,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent ? AppTheme.accent.withOpacity(0.3) : AppTheme.bgMuted, width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: accent ? AppTheme.accent : AppTheme.textMuted),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
        fontSize: 11, color: accent ? AppTheme.accent : AppTheme.textMuted)),
    ]),
  );
}
