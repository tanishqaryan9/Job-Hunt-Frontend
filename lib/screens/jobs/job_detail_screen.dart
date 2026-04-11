import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});
  @override State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  bool _applying = false, _applied = false;
  final _coverLetterCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _coverLetterCtrl.dispose();
    super.dispose();
  }

  void _applyNow() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ApplySheet(
            job: widget.job,
            ctrl: _coverLetterCtrl,
            onApply: _submitApplication),
      );

  Future<void> _submitApplication() async {
    setState(() => _applying = true);

    // Resolve userId — try in-memory first, then storage
    final authProvider = context.read<AuthProvider>();
    int? userId = authProvider.currentUserId ?? await apiService.getProfileId();

    if (userId == null) {
      setState(() => _applying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please log in to apply.'),
            backgroundColor: AppTheme.rose,
            behavior: SnackBarBehavior.floating));
      }
      return;
    }

    try {
      await apiService.createApplication(widget.job.id, userId,
          coverLetter: _coverLetterCtrl.text.isNotEmpty
              ? _coverLetterCtrl.text
              : null);
      setState(() {
        _applying = false;
        _applied = true;
      });
      if (mounted) {
        Navigator.pop(context); // close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application submitted! 🎉'),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      setState(() => _applying = false);
      if (mounted) {
        // FIX: Parse the error properly instead of dumping the raw exception.
        final msg = _parseApplicationError(e);
        Navigator.pop(context); // close bottom sheet so user can see snackbar
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.rose,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5)));
      }
    }
  }

  /// Converts application-submit errors into readable messages.
  String _parseApplicationError(dynamic e) {
    final s = e.toString();
    try {
      final dynamic response = (e as dynamic).response?.data;
      final int? statusCode = (e as dynamic).response?.statusCode;

      if (response != null) {
        final msg = response['message']?.toString()
            ?? response['error']?.toString();
        if (msg != null && msg.isNotEmpty) {
          if (msg.toLowerCase().contains('already applied') ||
              msg.toLowerCase().contains('duplicate')) {
            return 'You have already applied for this job.';
          }
          if (msg.toLowerCase().contains('not found')) {
            return 'Job or user not found. Please refresh and try again.';
          }
          return msg;
        }
        if (statusCode == 404) {
          return 'Job not found. It may have been removed. Please go back and refresh.';
        }
        if (statusCode == 409) return 'You have already applied for this job.';
        if (statusCode == 400) return 'Invalid application data. Please try again.';
        if (statusCode == 403) return 'You are not allowed to apply for this job.';
      }
    } catch (_) {}

    if (s.contains('404')) {
      return 'Job or user profile not found (404). Please go back and refresh the jobs list.';
    }
    if (s.contains('409')) return 'You have already applied for this job.';
    if (s.contains('403')) return 'You are not permitted to apply for this job.';
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Failed to submit application. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
          child: Column(children: [
        // App bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
                onPressed: () => Navigator.pop(context)),
            const Expanded(
                child: Text('Job Details',
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppTheme.text))),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.bgMuted, width: 1)),
              child: const Icon(Icons.share_outlined,
                  size: 18, color: AppTheme.textMuted),
            ),
          ]),
        ),
        Expanded(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Hero card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.accentShadow(),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                                child: Text(
                              widget.job.createdByName
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                              style: const TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: Colors.white),
                            )),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(widget.job.title,
                                    style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                        letterSpacing: -0.5,
                                        color: Colors.white)),
                                if (widget.job.createdByName != null)
                                  Text(widget.job.createdByName!,
                                      style: TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 13,
                                          color:
                                              Colors.white.withOpacity(0.75))),
                              ])),
                        ]),
                        const SizedBox(height: 18),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _WhiteTag(
                              icon: Icons.location_on_outlined,
                              text: widget.job.location),
                          _WhiteTag(
                              icon: Icons.currency_rupee,
                              text:
                                  '${(widget.job.salary / 1000).round()}K / mo'),
                          _WhiteTag(
                              icon: Icons.schedule_rounded,
                              text: widget.job.jobType.replaceAll('_', ' ')),
                        ]),
                      ]),
                ),
                const SizedBox(height: 28),
                const _SectionLabel('About the Role'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration(),
                  child: Text(widget.job.description,
                      style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 14,
                          height: 1.7,
                          color: AppTheme.textMuted)),
                ),
                if (widget.job.skills.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionLabel('Required Skills'),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.job.skills
                          .map((s) => SkillChip(label: s.name))
                          .toList()),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: _StatBox(
                    label: 'Monthly Pay',
                    value: '₹${(widget.job.salary / 1000).round()}K',
                    icon: Icons.payments_rounded,
                    color: AppTheme.teal,
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _StatBox(
                    label: 'Type',
                    value: widget.job.jobType.replaceAll('_', '\n'),
                    icon: Icons.schedule_rounded,
                    color: AppTheme.accent,
                  )),
                ]),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
        // Apply bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1))),
          child: Builder(builder: (context) {
            final auth = context.watch<AuthProvider>();
            final isOwner = widget.job.createdById != null &&
                widget.job.createdById == auth.currentUserId;
            if (isOwner) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.teal.withOpacity(0.3), width: 1),
                ),
                child: const Center(
                  child: Text('You posted this job',
                      style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.teal)),
                ),
              );
            }
            return BrutalButton(
              label: _applied ? '✓ Applied' : 'Apply Now',
              onPressed: _applied ? null : _applyNow,
              isLoading: _applying,
              color: _applied ? AppTheme.green : AppTheme.accent,
              width: double.infinity,
            );
          }),
        ),
      ])),
    );
  }
}

// ── Supporting widgets (unchanged) ────────────────────────────

class _WhiteTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _WhiteTag({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white)),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppTheme.text,
          letterSpacing: -0.3));
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.3)),
        ]),
      );
}

class _ApplySheet extends StatelessWidget {
  final Job job;
  final TextEditingController ctrl;
  final VoidCallback onApply;
  const _ApplySheet(
      {required this.job, required this.ctrl, required this.onApply});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.bgMuted, width: 1)),
        ),
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.bgMuted,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Apply for',
                          style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppTheme.text)),
                      Text(job.title,
                          style: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 14,
                              color: AppTheme.accent)),
                    ])),
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted)),
              ]),
              const SizedBox(height: 20),
              BrutalTextField(
                  label: 'Cover Letter (optional)',
                  controller: ctrl,
                  maxLines: 4,
                  hint: "Tell them why you're the perfect fit…"),
              const SizedBox(height: 20),
              BrutalButton(
                  label: 'Submit Application',
                  onPressed: onApply,
                  width: double.infinity),
            ]),
      );
}