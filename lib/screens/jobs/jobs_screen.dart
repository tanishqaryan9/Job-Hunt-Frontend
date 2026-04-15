import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import 'job_detail_screen.dart';
import 'create_job_screen.dart';

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

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
  double? _userLat, _userLon;

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

    // Grab user lat/lon from AuthProvider (set during feed load / signup)
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    _userLat = user?.latitude;
    _userLon = user?.longitude;

    try {
      final result = await apiService.getJobs(page: _page, size: 10);
      // Compute distances client-side
      final jobs = result.content;
      if (_userLat != null && _userLon != null) {
        for (final job in jobs) {
          if (job.latitude != null && job.longitude != null) {
            job.distanceKm = _haversineKm(_userLat!, _userLon!, job.latitude!, job.longitude!);
          }
        }
      }
      setState(() {
        if (reset) {
          _jobs = jobs;
        } else {
          _jobs.addAll(jobs);
        }
        _hasMore = result.page < result.totalPages - 1;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
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
                        child: _JobListItem(
                          job: job,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
                        ),
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
              Wrap(spacing: 12, runSpacing: 4, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textFaint),
                  const SizedBox(width: 3),
                  Text(job.location, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                    fontSize: 12, color: AppTheme.textMuted)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.currency_rupee, size: 12, color: AppTheme.accent),
                  Text(job.salaryDisplay, style: const TextStyle(
                    fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                    fontSize: 12, color: AppTheme.accent)),
                ]),
                // Distance chip — shown only when user coords and job coords available
                if (job.distanceKm != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.near_me_outlined, size: 12, color: AppTheme.teal),
                    const SizedBox(width: 3),
                    Text(
                      job.distanceKm! < 1 ? '< 1 km' : '${job.distanceKm!.round()} km',
                      style: const TextStyle(fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.teal),
                    ),
                  ]),
              ]),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.only(right: 16), child: JobTypeBadge(type: job.jobType)),
      ]),
    ),
  );
}
