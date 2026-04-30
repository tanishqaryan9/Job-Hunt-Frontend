import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/brutal_widgets.dart';
import '../../models/models.dart';

enum _PayType { salary, stipend }
enum _PayPeriod { hour, day, month, year }

extension _PayPeriodLabel on _PayPeriod {
  String get label {
    switch (this) {
      case _PayPeriod.hour:  return '/ Hour';
      case _PayPeriod.day:   return '/ Day';
      case _PayPeriod.month: return '/ Month';
      case _PayPeriod.year:  return '/ Year';
    }
  }
  String get shortLabel {
    switch (this) {
      case _PayPeriod.hour:  return '/hr';
      case _PayPeriod.day:   return '/day';
      case _PayPeriod.month: return '/mo';
      case _PayPeriod.year:  return '/yr';
    }
  }
  double toAnnual(double amount) {
    switch (this) {
      case _PayPeriod.hour:  return amount * 8 * 26 * 12;
      case _PayPeriod.day:   return amount * 26 * 12;
      case _PayPeriod.month: return amount * 12;
      case _PayPeriod.year:  return amount;
    }
  }
}

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});
  @override State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _salaryCtrl   = TextEditingController();

  String  _jobType     = 'FULL_TIME';
  bool    _submitting  = false;
  bool    _gettingLoc  = false;
  double? _latitude;
  double? _longitude;
  String? _resolvedAddress; // state + district from reverse geocode

  _PayType   _payType   = _PayType.salary;
  _PayPeriod _payPeriod = _PayPeriod.month;

  List<Skill>       _allSkills     = [];
  final List<Skill> _selected      = [];
  bool              _skillsLoading = true;
  bool              _skillsError   = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  static const _jobTypes = ['FULL_TIME', 'PART_TIME', 'CONTRACT', 'INTERNSHIP'];
  static const _jobTypeLabels = {
    'FULL_TIME':  'Full Time',
    'PART_TIME':  'Part Time',
    'CONTRACT':   'Contract',
    'INTERNSHIP': 'Apprentice',
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _loadSkills();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    setState(() { _skillsLoading = true; _skillsError = false; });
    try {
      final skills = await apiService.getAllSkills();
      setState(() { _allSkills = skills; _skillsLoading = false; });
    } catch (_) {
      setState(() { _skillsLoading = false; _skillsError = true; _allSkills = _fallbackSkills(); });
    }
  }

  List<Skill> _fallbackSkills() => [
    Skill(id: -1,  name: 'Welding'),       Skill(id: -2,  name: 'Plumbing'),
    Skill(id: -3,  name: 'Electrical Work'),Skill(id: -4,  name: 'Carpentry'),
    Skill(id: -5,  name: 'Masonry'),        Skill(id: -6,  name: 'Painting'),
    Skill(id: -7,  name: 'Driving (LMV)'), Skill(id: -8,  name: 'Driving (HMV)'),
    Skill(id: -9,  name: 'Machine Operation'), Skill(id: -10, name: 'Forklift Operation'),
    Skill(id: -11, name: 'Security Guard'), Skill(id: -12, name: 'Housekeeping'),
    Skill(id: -13, name: 'Cooking'),        Skill(id: -14, name: 'Tailoring'),
    Skill(id: -15, name: 'AC Repair'),      Skill(id: -16, name: 'Mechanic'),
    Skill(id: -17, name: 'Delivery'),       Skill(id: -18, name: 'Data Entry'),
    Skill(id: -19, name: 'Packing & Loading'), Skill(id: -20, name: 'Gardening'),
  ];

  // ── Location detection + reverse geocode ───────────────────────────────
  Future<void> _getLocation() async {
    setState(() => _gettingLoc = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied. Enter location manually.'),
            backgroundColor: AppTheme.amber,
            behavior: SnackBarBehavior.floating,
          ));
          setState(() => _gettingLoc = false);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      setState(() {
        _latitude  = pos.latitude;
        _longitude = pos.longitude;
      });

      // Reverse geocode → auto-fill district + state in the location field
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          // Build "District, State" — subAdministrativeArea = district, administrativeArea = state
          final parts = <String>[
            if (p.subAdministrativeArea?.isNotEmpty == true) p.subAdministrativeArea!,
            if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
          ];
          final addr = parts.join(', ');
          if (addr.isNotEmpty) {
            setState(() {
              _resolvedAddress = addr;
              // Only auto-fill if user hasn't typed anything yet
              if (_locationCtrl.text.trim().isEmpty) {
                _locationCtrl.text = addr;
              }
            });
          }
        }
      } catch (_) {
        // Geocoding failed — GPS coords still captured, text field stays as-is
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_resolvedAddress != null
              ? 'Location set: $_resolvedAddress'
              : 'GPS captured (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})'),
          backgroundColor: AppTheme.teal,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not get location. Enter manually.'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  // ── Skill creation ──────────────────────────────────────────
  Future<Skill> _createNewSkill(String name) async {
    final trimmed = name.trim();
    final existing = _allSkills.firstWhere(
      (s) => s.name.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => Skill(id: 0, name: ''),
    );
    if (existing.id != 0) return existing;
    try {
      final newSkill = await apiService.createSkill(trimmed);
      setState(() { if (!_allSkills.any((s) => s.id == newSkill.id)) _allSkills.add(newSkill); });
      return newSkill;
    } on Exception catch (e) {
      final s = e.toString();
      if (s.contains('409') || s.contains('already') || s.contains('Duplicate')) {
        final match = _allSkills.firstWhere(
          (s) => s.name.toLowerCase() == trimmed.toLowerCase(),
          orElse: () => Skill(id: 0, name: ''),
        );
        if (match.id != 0) return match;
        try {
          final refreshed = await apiService.getAllSkills();
          setState(() => _allSkills = refreshed);
          return refreshed.firstWhere(
            (s) => s.name.toLowerCase() == trimmed.toLowerCase(),
            orElse: () => Skill(id: 0, name: trimmed),
          );
        } catch (_) {}
      }
      final localId = -(DateTime.now().millisecondsSinceEpoch % 100000);
      final localSkill = Skill(id: localId, name: trimmed);
      setState(() => _allSkills.add(localSkill));
      return localSkill;
    }
  }

  void _showSkillPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillPickerSheet(
        allSkills: _allSkills, selected: List.of(_selected), skillsLoading: _skillsLoading,
        onDone: (updatedSelected, newSkillsToCreate) async {
          setState(() { _selected.clear(); _selected.addAll(updatedSelected); });
          for (final name in newSkillsToCreate) {
            final skill = await _createNewSkill(name);
            if (!_selected.any((s) => s.name.toLowerCase() == skill.name.toLowerCase())) {
              setState(() => _selected.add(skill));
            }
          }
        },
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────
  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.userProfile?.isVerified != true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Verification Required', style: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text)),
          content: const Text('You must verify your account in the Profile section before posting a job.', style: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textMuted)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to feed so they can go to profile
              },
              child: const Text('OK', style: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.accent)),
            )
          ],
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final rawSalary = double.tryParse(_salaryCtrl.text.replaceAll(',', '')) ?? 0;
      final createdJob = await apiService.createJob({
        'title':        _titleCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'location':     _locationCtrl.text.trim(),
        'salary':       rawSalary,
        'salaryPeriod': _payPeriod.name,
        'jobType':      _jobType,
        if (_latitude  != null) 'latitude':  _latitude,
        if (_longitude != null) 'longitude': _longitude,
      });

      final realSkillIds = _selected.map((s) => s.id).where((id) => id > 0).toList();
      for (final skillId in realSkillIds) {
        try { await apiService.addSkillToJob(createdJob.id, skillId); } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Job posted successfully! 🎉'),
          backgroundColor: AppTheme.teal,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_parseSubmitError(e)),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _parseSubmitError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      final code = (e as dynamic).response?.statusCode as int?;
      final msg  = data?['message']?.toString() ?? data?['error']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
      if (code == 403) {
        if (msg != null && msg.toLowerCase().contains('verified')) return msg;
        return "You don't have permission to post jobs.";
      }
      if (code == 400) return 'Invalid job data. Please check all fields.';
      if (code == 401) return 'Session expired. Please log in again.';
    } catch (_) {}
    return 'Failed to post job. Please try again.';
  }

  String get _payLabel => '${_payType == _PayType.salary ? 'Salary' : 'Stipend'} (₹ ${_payPeriod.label})';
  String get _payHint {
    switch (_payPeriod) {
      case _PayPeriod.hour:  return 'e.g. 150';
      case _PayPeriod.day:   return 'e.g. 800';
      case _PayPeriod.month: return 'e.g. 18000';
      case _PayPeriod.year:  return 'e.g. 240000';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: BrutalAppBar(
        title: 'Post a Job',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.accentShadow(),
                ),
                child: const Row(children: [
                  Icon(Icons.construction_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('New Job Posting', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                    Text('Fill in the details below', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: Colors.white70)),
                  ]),
                ]),
              ),
              const SizedBox(height: 32),

              // Job Title
              const _SectionLabel('Job Title'),
              const SizedBox(height: 8),
              BrutalTextField(
                label: 'e.g. Electrician, Delivery Driver, Mason',
                controller: _titleCtrl,
                prefixIcon: const Icon(Icons.title_rounded),
                validator: (v) => v!.trim().isEmpty ? 'Enter job title' : null,
              ),
              const SizedBox(height: 20),

              // Description
              const _SectionLabel('Job Description'),
              const SizedBox(height: 8),
              BrutalTextField(
                label: 'Describe duties, timings, requirements…',
                controller: _descCtrl, maxLines: 4,
                prefixIcon: const Icon(Icons.description_outlined),
                validator: (v) => v!.trim().length < 20 ? 'Description must be at least 20 characters' : null,
              ),
              const SizedBox(height: 20),

              // Location + Get Location button
              Row(children: [
                const _SectionLabel('Work Location'),
                const Spacer(),
                GestureDetector(
                  onTap: _gettingLoc ? null : _getLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _latitude != null ? AppTheme.teal.withOpacity(0.12) : AppTheme.accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _latitude != null ? AppTheme.teal.withOpacity(0.4) : AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _gettingLoc
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                          : Icon(
                              _latitude != null ? Icons.location_on_rounded : Icons.my_location_rounded,
                              size: 13,
                              color: _latitude != null ? AppTheme.teal : AppTheme.accent,
                            ),
                      const SizedBox(width: 4),
                      Text(
                        _latitude != null ? 'Location Set ✓' : 'Get Location',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 11,
                          color: _latitude != null ? AppTheme.teal : AppTheme.accent,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              BrutalTextField(
                label: 'e.g. Andheri West, Mumbai',
                controller: _locationCtrl,
                prefixIcon: const Icon(Icons.location_on_outlined),
                validator: (v) => v!.trim().isEmpty ? 'Enter location' : null,
              ),
              if (_latitude != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.teal.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.gps_fixed_rounded, size: 13, color: AppTheme.teal),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _resolvedAddress != null
                          ? 'GPS set · $_resolvedAddress — enables distance-based matching'
                          : 'GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}  — enables distance-based matching',
                      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 10, color: AppTheme.teal),
                    )),
                  ]),
                ),
              ],
              const SizedBox(height: 24),

              // Pay Type
              const _SectionLabel('Pay Type'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _PayTypeCard(label: 'Salary', subtitle: 'Regular employment pay', icon: Icons.account_balance_wallet_rounded, selected: _payType == _PayType.salary, color: AppTheme.accent, onTap: () => setState(() => _payType = _PayType.salary))),
                const SizedBox(width: 12),
                Expanded(child: _PayTypeCard(label: 'Stipend', subtitle: 'Internship / training pay', icon: Icons.school_rounded, selected: _payType == _PayType.stipend, color: AppTheme.teal, onTap: () => setState(() => _payType = _PayType.stipend))),
              ]),
              const SizedBox(height: 20),

              // Pay Period
              const _SectionLabel('Pay Period'),
              const SizedBox(height: 10),
              Row(children: _PayPeriod.values.map((p) {
                final active = _payPeriod == p;
                final activeColor = _payType == _PayType.stipend ? AppTheme.teal : AppTheme.accent;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _payPeriod = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: p != _PayPeriod.year ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? activeColor : AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? activeColor : AppTheme.bgMuted),
                    ),
                    child: Center(child: Text(
                      p == _PayPeriod.hour ? 'Hour' : p == _PayPeriod.day ? 'Day' : p == _PayPeriod.month ? 'Month' : 'Year',
                      style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 12, color: active ? Colors.white : AppTheme.textMuted),
                    )),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 20),

              // Salary Amount
              _SectionLabel(_payLabel),
              const SizedBox(height: 8),
              BrutalTextField(
                label: _payHint, controller: _salaryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_payType == _PayType.stipend ? AppTheme.teal : AppTheme.accent).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_payPeriod.shortLabel, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 12, color: _payType == _PayType.stipend ? AppTheme.teal : AppTheme.accent)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n < 0) return 'Enter a valid amount';
                  if (n == 0) return 'Amount cannot be zero';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              if (_salaryCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                _SalaryConvertedHint(
                  raw: double.tryParse(_salaryCtrl.text.replaceAll(',', '')) ?? 0,
                  period: _payPeriod, payType: _payType,
                ),
              ],
              const SizedBox(height: 24),

              // Job Type
              const _SectionLabel('Employment Type'),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: _jobTypes.map((type) {
                final active = _jobType == type;
                return GestureDetector(
                  onTap: () => setState(() => _jobType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.accent : AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppTheme.accent : AppTheme.bgMuted),
                      boxShadow: active ? AppTheme.accentShadow(opacity: 0.25) : null,
                    ),
                    child: Text(_jobTypeLabels[type] ?? type, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : AppTheme.textMuted)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 28),

              // Required Skills
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const _SectionLabel('Required Skills'),
                GestureDetector(
                  onTap: _showSkillPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 14, color: AppTheme.accent),
                      SizedBox(width: 4),
                      Text('Add Skills', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.accent)),
                    ]),
                  ),
                ),
              ]),
              if (_skillsError) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.amber.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.amber.withOpacity(0.3))),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.amber),
                    SizedBox(width: 8),
                    Expanded(child: Text("Couldn't load skills — showing common trades. Type to create custom skills.", style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 11, color: AppTheme.amber))),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              if (_selected.isEmpty)
                GestureDetector(
                  onTap: _showSkillPicker,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.bgMuted, width: 1.5)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.extension_outlined, color: AppTheme.textFaint, size: 18),
                      SizedBox(width: 8),
                      Text('Tap to add required skills', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint)),
                    ]),
                  ),
                )
              else
                Wrap(spacing: 8, runSpacing: 8, children: _selected.map((skill) => _SkillChip(skill: skill, onRemove: () => setState(() => _selected.removeWhere((s) => s.id == skill.id)))).toList()),

              const SizedBox(height: 40),
              BrutalButton(label: 'POST JOB', onPressed: _submitting ? null : _submit, isLoading: _submitting, width: double.infinity, icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Pay Type Card ─────────────────────────────────────────────
class _PayTypeCard extends StatelessWidget {
  final String label, subtitle; final IconData icon; final bool selected; final Color color; final VoidCallback onTap;
  const _PayTypeCard({required this.label, required this.subtitle, required this.icon, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(
    duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: selected ? color.withOpacity(0.12) : AppTheme.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? color : AppTheme.bgMuted, width: selected ? 1.5 : 1)),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: selected ? color.withOpacity(0.18) : AppTheme.bgMuted, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: selected ? color : AppTheme.textFaint)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13, color: selected ? color : AppTheme.text)),
        Text(subtitle, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 10, color: AppTheme.textFaint)),
      ])),
      if (selected) Icon(Icons.check_circle_rounded, size: 16, color: color),
    ]),
  ));
}

// ── Salary hint ───────────────────────────────────────────────
class _SalaryConvertedHint extends StatelessWidget {
  final double raw; final _PayPeriod period; final _PayType payType;
  const _SalaryConvertedHint({required this.raw, required this.period, required this.payType});
  @override
  Widget build(BuildContext context) {
    if (raw <= 0) return const SizedBox.shrink();
    final annual = period.toAnnual(raw); final monthly = annual / 12;
    final color = payType == _PayType.stipend ? AppTheme.teal : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 13, color: color), const SizedBox(width: 8),
        Expanded(child: Text('≈ ₹${_fmt(monthly)}/mo  •  ₹${_fmt(annual)}/yr', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 11, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }
  String _fmt(double v) { if (v >= 100000) return '${(v/100000).toStringAsFixed(1)}L'; if (v >= 1000) return '${(v/1000).toStringAsFixed(1)}K'; return v.toStringAsFixed(0); }
}

class _SectionLabel extends StatelessWidget {
  final String text; const _SectionLabel(this.text);
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.4, color: AppTheme.textMuted));
}

class _SkillChip extends StatelessWidget {
  final Skill skill; final VoidCallback onRemove;
  const _SkillChip({required this.skill, required this.onRemove});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(skill.name, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accent)),
      const SizedBox(width: 6),
      GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.accent)),
    ]),
  );
}

// ── Skill Picker Sheet ────────────────────────────────────────
class _SkillPickerSheet extends StatefulWidget {
  final List<Skill> allSkills; final List<Skill> selected; final bool skillsLoading;
  final void Function(List<Skill> selected, List<String> toCreate) onDone;
  const _SkillPickerSheet({required this.allSkills, required this.selected, required this.skillsLoading, required this.onDone});
  @override State<_SkillPickerSheet> createState() => _SkillPickerSheetState();
}

class _SkillPickerSheetState extends State<_SkillPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<Skill> _selectedLocal;
  final List<String> _toCreate = [];

  @override void initState() { super.initState(); _selectedLocal = List.of(widget.selected); _searchCtrl.addListener(() => setState(() {})); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Skill> get _filtered { final q = _searchCtrl.text.trim().toLowerCase(); if (q.isEmpty) return widget.allSkills; return widget.allSkills.where((s) => s.name.toLowerCase().contains(q)).toList(); }
  bool _isSelected(Skill s) => _selectedLocal.any((x) => x.id == s.id);
  void _toggle(Skill s) { setState(() { if (_isSelected(s)) { _selectedLocal.removeWhere((x) => x.id == s.id); } else { _selectedLocal.add(s); } }); }
  bool get _queryMatchesExisting { final q = _searchCtrl.text.trim().toLowerCase(); return q.isEmpty || widget.allSkills.any((s) => s.name.toLowerCase() == q); }

  void _addLocalSkill(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_selectedLocal.any((s) => s.name.toLowerCase() == trimmed.toLowerCase())) { _searchCtrl.clear(); return; }
    final placeholder = Skill(id: -(DateTime.now().millisecondsSinceEpoch % 100000), name: trimmed);
    setState(() { _selectedLocal.add(placeholder); _toCreate.add(trimmed); _searchCtrl.clear(); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$trimmed" added'), backgroundColor: AppTheme.teal, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
  }

  void _done() { widget.onDone(_selectedLocal, _toCreate); Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    final showCreate = _searchCtrl.text.trim().isNotEmpty && !_queryMatchesExisting;
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.bgMuted, borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Skills', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.text)),
              Text('Select from list or type to create', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.textMuted)),
            ])),
            GestureDetector(onTap: _done, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.accentShadow(opacity: 0.3)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 16), const SizedBox(width: 6),
                Text('Done (${_selectedLocal.length})', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              ]),
            )),
          ])),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) { if (showCreate) _addLocalSkill(v); },
            decoration: InputDecoration(
              hintText: 'Search or type new skill name…',
              hintStyle: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textFaint),
              suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.textFaint), onPressed: () => _searchCtrl.clear()) : null,
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )),
          if (showCreate) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GestureDetector(
              onTap: () => _addLocalSkill(_searchCtrl.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppTheme.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.teal.withOpacity(0.35))),
                child: Row(children: [
                  const Icon(Icons.add_rounded, color: AppTheme.teal, size: 18), const SizedBox(width: 10),
                  Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13), children: [
                    const TextSpan(text: 'Add  ', style: TextStyle(color: AppTheme.textMuted)),
                    TextSpan(text: '"${_searchCtrl.text.trim()}"', style: const TextStyle(color: AppTheme.teal, fontWeight: FontWeight.w700)),
                  ]))),
                  const Text('Tap or ↵', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 10, color: AppTheme.teal)),
                ]),
              ),
            )),
          ],
          if (_selectedLocal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Wrap(spacing: 6, runSpacing: 6, children: _selectedLocal.map((s) => GestureDetector(
              onTap: () => setState(() => _selectedLocal.removeWhere((x) => x.id == s.id)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.accent.withOpacity(0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.name, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.accent)),
                  const SizedBox(width: 4), const Icon(Icons.close_rounded, size: 11, color: AppTheme.accent),
                ]),
              ),
            )).toList())),
          ],
          const SizedBox(height: 12),
          Expanded(child: widget.skillsLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
            : _filtered.isEmpty
              ? Center(child: Text(showCreate ? 'No match — add it above' : 'No skills found', style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14)))
              : ListView.builder(
                  controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final skill = _filtered[i]; final sel = _isSelected(skill);
                    return GestureDetector(onTap: () => _toggle(skill), child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150), margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: sel ? AppTheme.accent.withOpacity(0.12) : AppTheme.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? AppTheme.accent.withOpacity(0.4) : AppTheme.bgMuted)),
                      child: Row(children: [
                        AnimatedContainer(duration: const Duration(milliseconds: 150), width: 22, height: 22,
                          decoration: BoxDecoration(color: sel ? AppTheme.accent : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? AppTheme.accent : AppTheme.bgMuted, width: 2)),
                          child: sel ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null),
                        const SizedBox(width: 12),
                        Expanded(child: Text(skill.name, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 14, color: sel ? AppTheme.accent : AppTheme.text))),
                      ]),
                    ));
                  },
                )),
        ]),
      ),
    );
  }
}
