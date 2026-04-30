import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/brutal_widgets.dart';
import 'public_profile_screen.dart';

/// Full-detail screen shown when an employer taps an applicant's name.
/// Displays the cover letter (if any) and provides one-tap Call + Email actions.
class ApplicantDetailScreen extends StatelessWidget {
  final JobApplication app;

  const ApplicantDetailScreen({super.key, required this.app});

  // ── URL helpers ────────────────────────────────────────────────────────────

  Future<void> _call(BuildContext context) async {
    final number = app.applicantNumber;
    if (number == null || number.isEmpty) {
      _snack(context, 'No phone number available', AppTheme.rose);
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack(context, 'Could not open dialler', AppTheme.rose);
    }
  }

  Future<void> _mail(BuildContext context) async {
    final email = app.applicantEmail;
    if (email == null || email.isEmpty) {
      _snack(context, 'No email address available', AppTheme.rose);
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Regarding your application for ${app.jobTitle}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack(context, 'Could not open mail app', AppTheme.rose);
    }
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = app.displayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom AppBar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppTheme.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // View full public profile
                if (app.applicantId != null)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicProfileScreen(
                          userId: app.applicantId!,
                          preloadedName: name,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.3), width: 1),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_outline_rounded,
                            size: 14, color: AppTheme.accent),
                        SizedBox(width: 5),
                        Text('Profile',
                            style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppTheme.accent)),
                      ]),
                    ),
                  ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero card ──────────────────────────────────────────
                    _HeroCard(name: name, initial: initial, app: app),
                    const SizedBox(height: 20),

                    // ── Contact Actions ────────────────────────────────────
                    const _SectionLabel(label: 'Contact Candidate'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.call_rounded,
                          label: 'Call',
                          subtitle: app.applicantNumber ?? 'N/A',
                          color: AppTheme.green,
                          onTap: () => _call(context),
                          enabled: app.applicantNumber?.isNotEmpty == true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          subtitle: app.applicantEmail ?? 'N/A',
                          color: AppTheme.accent,
                          onTap: () => _mail(context),
                          enabled: app.applicantEmail?.isNotEmpty == true,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── Cover Letter ───────────────────────────────────────
                    const _SectionLabel(label: 'Cover Letter'),
                    const SizedBox(height: 12),
                    _CoverLetterCard(coverLetter: app.coverLetter),
                    const SizedBox(height: 24),

                    // ── Application Meta ───────────────────────────────────
                    const _SectionLabel(label: 'Application Details'),
                    const SizedBox(height: 12),
                    _MetaCard(app: app),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String name;
  final String initial;
  final JobApplication app;

  const _HeroCard(
      {required this.name, required this.initial, required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D2E), Color(0xFF16192A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2), width: 1),
        boxShadow: AppTheme.glowShadow(radius: 32),
      ),
      child: Column(children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.heroGradient,
            boxShadow: AppTheme.glowShadow(radius: 20),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(name,
            style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5,
                color: AppTheme.text)),
        const SizedBox(height: 6),
        // Quick info chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            if (app.applicantLocation?.isNotEmpty == true)
              _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: app.applicantLocation!,
                  color: AppTheme.textMuted),
            if (app.applicantExperience != null)
              _InfoChip(
                  icon: Icons.work_outline_rounded,
                  label:
                      '${app.applicantExperience} yr${app.applicantExperience == 1 ? "" : "s"} exp',
                  color: AppTheme.accent),
            _InfoChip(
              icon: Icons.circle,
              label: app.status,
              color: _statusColor(app.status),
            ),
          ],
        ),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'SHORTLISTED':
        return AppTheme.amber;
      case 'HIRED':
        return AppTheme.green;
      case 'REJECTED':
        return AppTheme.rose;
      default:
        return AppTheme.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : AppTheme.textFaint;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: effectiveColor.withOpacity(0.25), width: 1.5),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: effectiveColor.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effectiveColor, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: effectiveColor)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  color: AppTheme.textFaint),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER LETTER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CoverLetterCard extends StatefulWidget {
  final String? coverLetter;
  const _CoverLetterCard({this.coverLetter});

  @override
  State<_CoverLetterCard> createState() => _CoverLetterCardState();
}

class _CoverLetterCardState extends State<_CoverLetterCard> {
  bool _expanded = false;
  static const _previewLines = 4;

  @override
  Widget build(BuildContext context) {
    final text = widget.coverLetter;
    final hasLetter = text != null && text.trim().isNotEmpty;

    if (!hasLetter) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: const Row(children: [
          Icon(Icons.description_outlined, size: 20, color: AppTheme.textFaint),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No cover letter was provided.',
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textFaint),
            ),
          ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withOpacity(0.15), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.format_quote_rounded, size: 20, color: AppTheme.accent),
          SizedBox(width: 8),
          Text('Cover Letter',
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.accent)),
        ]),
        const SizedBox(height: 14),
        // Divider
        Container(height: 1, color: AppTheme.accent.withOpacity(0.10)),
        const SizedBox(height: 14),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Text(
            text,
            maxLines: _previewLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 14,
                height: 1.65,
                color: AppTheme.text),
          ),
          secondChild: Text(
            text,
            style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 14,
                height: 1.65,
                color: AppTheme.text),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.accent),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppTheme.accent,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META CARD (applied date, job)
// ─────────────────────────────────────────────────────────────────────────────
class _MetaCard extends StatelessWidget {
  final JobApplication app;
  const _MetaCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(children: [
        _MetaRow(
          icon: Icons.work_outline_rounded,
          label: 'Applied for',
          value: app.jobTitle,
          color: AppTheme.accent,
        ),
        if (app.appliedAt != null) ...[
          const SizedBox(height: 14),
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            label: 'Applied on',
            value: app.appliedAt!.split('T').first,
            color: AppTheme.teal,
          ),
        ],
      ]),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetaRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 10,
                    color: AppTheme.textFaint,
                    letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.text)),
          ]),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
            color: AppTheme.textFaint),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: color)),
        ]),
      );
}
