import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import '../jobs/job_detail_screen.dart';
import '../feed/feed_screen.dart' show FeedJobCard;

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});
  @override State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<Job> _saved = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _saved = apiService.getSavedJobs());

  Future<void> _onRefresh() async {
    // Saved jobs are local — just rebuild
    setState(() => _saved = apiService.getSavedJobs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        // AppBar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text('Saved Jobs', style: TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 22, letterSpacing: -0.5, color: AppTheme.text)),
            ),
            if (_saved.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_saved.length}', style: const TextStyle(
                    fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                    fontSize: 13, color: AppTheme.accent)),
              ),
          ]),
        ),
        Expanded(
          child: _saved.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.bgCard,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                    itemCount: _saved.length,
                    itemBuilder: (_, i) {
                      final job = _saved[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: FeedJobCard(
                          key: ValueKey(job.id),
                          job: job,
                          showDistance: job.distanceKm != null,
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)));
                            // Reload in case user unsaved during detail view
                            _reload();
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ])),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bgMuted, width: 1.5),
            ),
            child: const Icon(Icons.bookmark_outline_rounded,
                size: 40, color: AppTheme.textFaint),
          ),
          const SizedBox(height: 24),
          const Text('No saved jobs yet',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 18, color: AppTheme.text)),
          const SizedBox(height: 10),
          const Text('Bookmark jobs from the feed\nto find them here quickly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13,
                  height: 1.6, color: AppTheme.textMuted)),
        ]),
      ),
    );
  }
}
