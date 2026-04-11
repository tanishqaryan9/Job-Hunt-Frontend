import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import 'job_detail_screen.dart';
import 'create_job_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Job> _jobs = [];
  bool _loading = true;
  int _page = 0;
  bool _hasMore = true;
  String _search = '';
  String? _filterType;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 200) _loadMore();
    });
  }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _loadJobs({bool reset = true}) async {
    if (reset) setState(() { _loading = true; _page = 0; _hasMore = true; });
    try {
      final result = await apiService.getJobs(page: _page, size: 10);
      setState(() {
        if (reset) {
          _jobs = result.content;
        } else {
          _jobs.addAll(result.content);
        }
        _hasMore = result.page < result.totalPages - 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        if (_jobs.isEmpty) {
          _jobs = [
          Job(id: 1, title: 'Senior Flutter Developer', description: 'Build cross-platform apps', location: 'Bangalore', salary: 120000, jobType: 'FULL_TIME', createdByName: 'TechCorp India', skills: [Skill(id: 1, name: 'Flutter'), Skill(id: 2, name: 'Dart')]),
          Job(id: 2, title: 'Backend Engineer', description: 'Spring Boot microservices', location: 'Mumbai', salary: 95000, jobType: 'FULL_TIME', createdByName: 'FinTech Startup'),
          Job(id: 3, title: 'React Developer', description: 'Build responsive web apps', location: 'Delhi', salary: 85000, jobType: 'CONTRACT', createdByName: 'WebStudio'),
          Job(id: 4, title: 'Data Scientist', description: 'ML model development', location: 'Hyderabad', salary: 110000, jobType: 'FULL_TIME', createdByName: 'AI Labs'),
          Job(id: 5, title: 'DevOps Engineer', description: 'Kubernetes and AWS', location: 'Pune', salary: 100000, jobType: 'PART_TIME', createdByName: 'CloudTech'),
        ];
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    _page++;
    await _loadJobs(reset: false);
  }

  List<Job> get _filtered => _jobs.where((j) {
    final ms = _search.isEmpty || j.title.toLowerCase().contains(_search.toLowerCase()) || j.location.toLowerCase().contains(_search.toLowerCase());
    final mt = _filterType == null || j.jobType == _filterType;
    return ms && mt;
  }).toList();

  void _openCreateJob() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateJobScreen()),
    );
    if (created == true) _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      // FIX: Moved FAB out of bottomNavigationBar slot (which caused a render error)
      // and into the proper floatingActionButton property, positioned bottom-right.
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateJob,
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Post a Job',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Expanded(
                child: Text('All Jobs', style: TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
              ),
            ]),
            const SizedBox(height: 16),
            // Search
            Container(
              decoration: BoxDecoration(color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.bgMuted, width: 1)),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Search jobs, locations…',
                  hintStyle: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint),
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in [null, 'FULL_TIME', 'PART_TIME', 'CONTRACT'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      label: f == null ? 'All' : f.replaceAll('_', ' '),
                      selected: _filterType == f,
                      onTap: () => setState(() => _filterType = f),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: 5,
                  itemBuilder: (_, i) => const Padding(padding: EdgeInsets.only(bottom: 12), child: BrutalShimmer(height: 100)))
              : RefreshIndicator(
                  onRefresh: () => _loadJobs(),
                  color: AppTheme.accent, backgroundColor: AppTheme.bgCard,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 80), // bottom padding for FAB
                    itemCount: _filtered.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _filtered.length) {
                        return const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)));
                      }
                      final job = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _JobListItem(job: job,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)))),
                      );
                    },
                  ),
                ),
        ),
      ])),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accent : AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.bgMuted, width: 1),
        boxShadow: selected ? AppTheme.accentShadow() : null,
      ),
      child: Text(label, style: TextStyle(fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w600, fontSize: 12,
        color: selected ? AppTheme.white : AppTheme.textMuted)),
    ),
  );
}

class _JobListItem extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _JobListItem({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: AppTheme.cardDecoration(),
      child: Row(children: [
        // Left accent gradient bar
        Container(
          width: 5,
          height: 80,
          decoration: const BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job.title, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2, color: AppTheme.text)),
              if (job.createdByName != null) ...[
                const SizedBox(height: 2),
                Text(job.createdByName!, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                  fontSize: 12, color: AppTheme.textMuted)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textFaint),
                const SizedBox(width: 3),
                Text(job.location, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                  fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(width: 14),
                const Icon(Icons.currency_rupee, size: 12, color: AppTheme.accent),
                Text('${(job.salary / 1000).round()}K', style: const TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 12, color: AppTheme.accent)),
              ]),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.only(right: 16), child: JobTypeBadge(type: job.jobType)),
      ]),
    ),
  );
}