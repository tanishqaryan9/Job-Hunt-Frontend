import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});
  @override State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  List<JobApplication> _applications = [];
  bool _loading = true;
  String? _filterStatus;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadApplications();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadApplications() async {
    setState(() => _loading = true);
    try {
      final apps = await apiService.getApplications();
      setState(() { _applications = apps; _loading = false; });
      _animCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _loading = false;
        _applications = [
          JobApplication(id: 1, jobId: 1, jobTitle: 'Senior Flutter Developer', status: 'APPLIED', coverLetter: 'I am very interested in this role.', appliedAt: '2026-04-01'),
          JobApplication(id: 2, jobId: 2, jobTitle: 'Backend Engineer (Java)', status: 'SHORTLISTED', appliedAt: '2026-03-28'),
          JobApplication(id: 3, jobId: 3, jobTitle: 'React Developer', status: 'REJECTED', appliedAt: '2026-03-20'),
          JobApplication(id: 4, jobId: 4, jobTitle: 'Data Scientist', status: 'HIRED', appliedAt: '2026-03-15'),
          JobApplication(id: 5, jobId: 5, jobTitle: 'DevOps Engineer', status: 'PENDING', appliedAt: '2026-04-03'),
        ];
      });
      _animCtrl.forward(from: 0);
    }
  }

  List<JobApplication> get _filtered =>
      _filterStatus == null ? _applications : _applications.where((a) => a.status == _filterStatus).toList();

  Future<void> _deleteApplication(JobApplication app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.bgMuted, width: 1),
            boxShadow: AppTheme.cardShadow()),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Withdraw?', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
            const SizedBox(height: 8),
            Text('Withdraw application for "${app.jobTitle}"?',
              style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: BrutalButton(label: 'Cancel',
                onPressed: () => Navigator.pop(context, false), color: AppTheme.bgElevated, textColor: AppTheme.text)),
              const SizedBox(width: 12),
              Expanded(child: BrutalButton(label: 'Withdraw',
                onPressed: () => Navigator.pop(context, true), color: AppTheme.rose)),
            ]),
          ]),
        ),
      ),
    );
    if (confirm == true) {
      try {
        await apiService.deleteApplication(app.id);
        setState(() => _applications.removeWhere((a) => a.id == app.id));
      } catch (_) {}
    }
  }

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
              const Expanded(child: Text('Applications', style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                fontSize: 28, letterSpacing: -1, color: AppTheme.text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.accentShadow(),
                ),
                child: Text('${_applications.length}', style: const TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800,
                  fontSize: 14, color: AppTheme.white)),
              ),
            ]),
            const SizedBox(height: 16),
            // Summary row
            if (!_loading && _applications.isNotEmpty) _buildSummaryRow(),
            const SizedBox(height: 16),
            // Filter pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterPill(label: 'All', selected: _filterStatus == null,
                  onTap: () => setState(() => _filterStatus = null)),
                const SizedBox(width: 8),
                for (final s in ['APPLIED', 'SHORTLISTED', 'HIRED', 'REJECTED', 'PENDING'])
                  Padding(padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(label: s, selected: _filterStatus == s,
                      onTap: () => setState(() => _filterStatus = s))),
              ]),
            ),
            const SizedBox(height: 4),
          ]),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(padding: const EdgeInsets.all(24), itemCount: 4,
                  itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 14),
                    child: BrutalShimmer(height: 110)))
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadApplications,
                      color: AppTheme.accent, backgroundColor: AppTheme.bgCard,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final app = _filtered[i];
                          return AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (_, child) {
                              final delay = i * 0.12;
                              final t = ((_animCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                              return Opacity(opacity: t,
                                child: Transform.translate(offset: Offset(0, 28 * (1 - t)), child: child));
                            },
                            child: Padding(padding: const EdgeInsets.only(bottom: 14),
                              child: _ApplicationCard(app: app, onDelete: () => _deleteApplication(app))),
                          );
                        },
                      ),
                    ),
        ),
      ])),
    );
  }

  Widget _buildSummaryRow() {
    final counts = <String, int>{};
    for (final a in _applications) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }
    return Row(children: [
      _SummaryDot(label: 'Active', count: (counts['APPLIED'] ?? 0) + (counts['SHORTLISTED'] ?? 0), color: AppTheme.blue),
      const SizedBox(width: 16),
      _SummaryDot(label: 'Hired', count: counts['HIRED'] ?? 0, color: AppTheme.green),
      const SizedBox(width: 16),
      _SummaryDot(label: 'Rejected', count: counts['REJECTED'] ?? 0, color: AppTheme.rose),
    ]);
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient.scale(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.accent.withOpacity(0.2), width: 1),
        ),
        child: const Icon(Icons.assignment_outlined, size: 40, color: AppTheme.accent)),
      const SizedBox(height: 20),
      const Text('No applications yet', style: TextStyle(fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.text)),
      const SizedBox(height: 8),
      const Text('Start applying to jobs from the feed!', style: TextStyle(
        fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
    ]),
  );
}

class _SummaryDot extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryDot({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text('$count $label', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
  ]);
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accent : AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.bgMuted, width: 1),
        boxShadow: selected ? AppTheme.accentShadow() : null,
      ),
      child: Text(label, style: TextStyle(fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w600, fontSize: 11,
        color: selected ? AppTheme.white : AppTheme.textMuted)),
    ),
  );
}

class _ApplicationCard extends StatefulWidget {
  final JobApplication app;
  final VoidCallback onDelete;
  const _ApplicationCard({required this.app, required this.onDelete});
  @override State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _expanded = false;

  (Color, Color) get _statusColors {
    switch (widget.app.status.toUpperCase()) {
      case 'APPLIED':     return (AppTheme.blue,  AppTheme.blueLight);
      case 'SHORTLISTED': return (AppTheme.amber, AppTheme.amberLight);
      case 'HIRED':       return (AppTheme.green, AppTheme.greenLight);
      case 'REJECTED':    return (AppTheme.rose,  AppTheme.roseLight);
      default:            return (AppTheme.textMuted, AppTheme.bgMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, _) = _statusColors;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.bgElevated, width: 1),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top status bar
          Container(height: 3,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            )),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Icon avatar
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(_statusIcon(widget.app.status), size: 22, color: statusColor)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.app.jobTitle, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2, color: AppTheme.text)),
                  if (widget.app.appliedAt != null) ...[
                    const SizedBox(height: 3),
                    Text('Applied ${widget.app.appliedAt!.split('T').first}',
                      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.textFaint)),
                  ],
                ])),
                StatusBadge(status: widget.app.status),
              ]),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.bgMuted),
                  const SizedBox(height: 12),
                  if (widget.app.coverLetter != null) ...[
                    Text('Cover Letter', style: TextStyle(fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700, fontSize: 11,
                      letterSpacing: 0.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    Text(widget.app.coverLetter!, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                      fontSize: 13, height: 1.6, color: AppTheme.textMuted)),
                    const SizedBox(height: 14),
                  ],
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.rose.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.rose.withOpacity(0.3), width: 1),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close_rounded, size: 14, color: AppTheme.rose),
                        SizedBox(width: 6),
                        Text('Withdraw', style: TextStyle(fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.rose)),
                      ]),
                    ),
                  ),
                ]),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppTheme.textFaint),
                const SizedBox(width: 4),
                Text(_expanded ? 'Less' : 'Details', style: const TextStyle(
                  fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.textFaint)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s.toUpperCase()) {
      case 'HIRED': return Icons.emoji_events_rounded;
      case 'SHORTLISTED': return Icons.star_rounded;
      case 'REJECTED': return Icons.close_rounded;
      case 'APPLIED': return Icons.send_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }
}

extension on LinearGradient {
  LinearGradient scale(double opacity) => LinearGradient(
    begin: begin, end: end,
    colors: colors.map((c) => c.withOpacity(opacity)).toList(),
  );
}
