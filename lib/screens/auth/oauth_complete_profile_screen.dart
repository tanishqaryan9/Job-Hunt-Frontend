import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/brutal_widgets.dart';
import '../main_shell.dart';

const Map<String, List<String>> _cities = {
  'Andhra Pradesh': ['Visakhapatnam','Vijayawada','Guntur','Tirupati'],
  'Assam': ['Guwahati','Silchar','Dibrugarh'],
  'Bihar': ['Patna','Gaya','Bhagalpur','Muzaffarpur'],
  'Chhattisgarh': ['Raipur','Bhilai','Bilaspur'],
  'Delhi': ['New Delhi','Delhi','Dwarka','Rohini'],
  'Goa': ['Panaji','Margao'],
  'Gujarat': ['Ahmedabad','Surat','Vadodara','Rajkot','Gandhinagar'],
  'Haryana': ['Faridabad','Gurugram','Panipat','Rohtak'],
  'Himachal Pradesh': ['Shimla','Dharamsala'],
  'Jharkhand': ['Ranchi','Jamshedpur','Dhanbad'],
  'Karnataka': ['Bengaluru','Mysuru','Mangaluru','Hubballi','Belagavi'],
  'Kerala': ['Thiruvananthapuram','Kochi','Kozhikode','Thrissur'],
  'Madhya Pradesh': ['Indore','Bhopal','Jabalpur','Gwalior'],
  'Maharashtra': ['Mumbai','Pune','Nagpur','Thane','Nashik','Navi Mumbai'],
  'Odisha': ['Bhubaneswar','Cuttack','Rourkela'],
  'Punjab': ['Ludhiana','Amritsar','Jalandhar','Patiala','Mohali'],
  'Rajasthan': ['Jaipur','Jodhpur','Kota','Bikaner','Udaipur'],
  'Tamil Nadu': ['Chennai','Coimbatore','Madurai','Tiruchirappalli'],
  'Telangana': ['Hyderabad','Warangal','Nizamabad'],
  'Uttar Pradesh': ['Lucknow','Kanpur','Varanasi','Agra','Noida','Ghaziabad'],
  'Uttarakhand': ['Dehradun','Haridwar','Roorkee'],
  'West Bengal': ['Kolkata','Asansol','Siliguri','Durgapur'],
  'Chandigarh': ['Chandigarh'],
  'Jammu & Kashmir': ['Srinagar','Jammu'],
};

/// Shown after an OAuth login when the user has no profile yet.
/// Calls POST /users/oauth-profile/{appUserId} — a dedicated endpoint
/// that creates the User profile row and links it to the AppUser.
/// This avoids the 403 that PATCH /users/{id} would give because
/// requireOwnership() fails when getUserProfile() is null.
class OAuthCompleteProfileScreen extends StatefulWidget {
  const OAuthCompleteProfileScreen({super.key});
  @override
  State<OAuthCompleteProfileScreen> createState() => _OAuthCompleteProfileScreenState();
}

class _OAuthCompleteProfileScreenState extends State<OAuthCompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _numberCtrl     = TextEditingController();
  final _experienceCtrl = TextEditingController(text: '0');

  String? _selectedState;
  String? _selectedCity;
  double? _latitude;
  double? _longitude;
  bool _gettingLoc = false;
  bool _saving     = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from the OAuth provider (Google display name / GitHub login)
    // so the user doesn't have to type it manually.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = context.read<AuthProvider>().oauthName;
      if (name != null && name.isNotEmpty && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = name;
      }
    });
  }

  List<String> get _sortedStates => _cities.keys.toList()..sort();
  List<String> get _citiesForState =>
      _selectedState != null ? (_cities[_selectedState] ?? []) : [];

  String get _locationDisplay {
    if (_selectedCity != null && _selectedState != null) return '$_selectedCity, $_selectedState';
    if (_selectedState != null) return _selectedState!;
    return '';
  }

  Future<void> _autoDetect() async {
    setState(() => _gettingLoc = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      setState(() { _latitude = pos.latitude; _longitude = pos.longitude; });

      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final detectedState = p.administrativeArea;
          final detectedCity  = p.locality?.isNotEmpty == true
              ? p.locality : p.subAdministrativeArea;
          if (detectedState != null) {
            final matched = _sortedStates.firstWhere(
              (s) => s.toLowerCase() == detectedState.toLowerCase(),
              orElse: () => _sortedStates.firstWhere(
                (s) => s.toLowerCase().contains(detectedState.toLowerCase()),
                orElse: () => ''),
            );
            if (matched.isNotEmpty) {
              String? mc;
              if (detectedCity != null) {
                final found = (_cities[matched] ?? []).firstWhere(
                  (c) => c.toLowerCase().contains(detectedCity.toLowerCase()),
                  orElse: () => '');
                if (found.isNotEmpty) mc = found;
              }
              setState(() { _selectedState = matched; _selectedCity = mc; });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Location: ${mc ?? detectedCity ?? 'your area'}, $matched'),
                  backgroundColor: AppTheme.teal,
                  behavior: SnackBarBehavior.floating));
              }
            }
          }
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationDisplay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your location.'),
        backgroundColor: AppTheme.rose,
        behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final appUserId = auth.appUserId;
      if (appUserId == null) throw Exception('No app user ID — please log in again.');

      // ✅ Use the dedicated endpoint — avoids 403 from requireOwnership()
      final profile = await apiService.createOAuthProfile(appUserId, {
        'name':       _nameCtrl.text.trim(),
        'number':     _numberCtrl.text.trim(),
        'experience': int.tryParse(_experienceCtrl.text) ?? 0,
        'location':   _locationDisplay,
        if (_latitude  != null) 'latitude':  _latitude,
        if (_longitude != null) 'longitude': _longitude,
      });

      if (!mounted) return;
      await auth.markProfileCompleted(profile);

      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: ${_msg(e)}'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating));
      }
    }
  }

  String _msg(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      return data?['message']?.toString() ?? e.toString();
    } catch (_) {
      return e.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.accentShadow()),
                child: const Icon(Icons.person_add_rounded, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Complete Your Profile', style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800,
                fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
              const SizedBox(height: 8),
              const Text('Just a few details to get you started', style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
              const SizedBox(height: 36),

              // Name
              BrutalTextField(
                label: 'Full Name', controller: _nameCtrl,
                prefixIcon: const Icon(Icons.badge_outlined),
                validator: (v) => v!.trim().isEmpty ? 'Enter your name' : null),
              const SizedBox(height: 16),

              // Phone
              BrutalTextField(
                label: 'Phone Number', controller: _numberCtrl,
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) => v!.trim().length < 10
                    ? 'Enter a valid 10-digit number' : null),
              const SizedBox(height: 16),

              // Experience
              BrutalTextField(
                label: 'Years of Experience', controller: _experienceCtrl,
                prefixIcon: const Icon(Icons.work_outline_rounded),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 0) ? 'Enter a valid number' : null;
                }),
              const SizedBox(height: 24),

              // Auto-detect location
              GestureDetector(
                onTap: _gettingLoc ? null : _autoDetect,
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.bgMuted)),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.bgMuted,
                        borderRadius: BorderRadius.circular(10)),
                      child: _gettingLoc
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.teal)))
                          : const Icon(Icons.my_location_rounded, color: AppTheme.textMuted, size: 20)),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Auto-detect Location', style: TextStyle(
                        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
                        fontSize: 14, color: AppTheme.text)),
                      Text('Tap to use your current location',
                        style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 11, color: AppTheme.textFaint)),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // State dropdown
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.bgMuted)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  isExpanded: true, value: _selectedState,
                  hint: const Text('Select State', style: TextStyle(
                    fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                  dropdownColor: AppTheme.bgElevated,
                  style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
                  items: _sortedStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() { _selectedState = val; _selectedCity = null; }),
                )),
              ),
              const SizedBox(height: 12),

              // City dropdown
              AnimatedOpacity(
                opacity: _selectedState != null ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedCity != null
                          ? AppTheme.accent.withOpacity(0.4)
                          : AppTheme.bgMuted)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    isExpanded: true, value: _selectedCity,
                    hint: Text(
                      _selectedState != null ? 'Select City' : 'Select State first',
                      style: const TextStyle(fontFamily: 'SpaceGrotesk',
                        color: AppTheme.textFaint, fontSize: 14)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                    dropdownColor: AppTheme.bgElevated,
                    style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
                    items: _citiesForState
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: _selectedState == null
                        ? null
                        : (val) => setState(() => _selectedCity = val),
                  )),
                ),
              ),

              if (_locationDisplay.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded, size: 15, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_locationDisplay, style: const TextStyle(
                      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
                      fontSize: 13, color: AppTheme.accent))),
                  ]),
                ),
              ],
              const SizedBox(height: 36),

              BrutalButton(
                label: 'SAVE & CONTINUE',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                width: double.infinity),
            ]),
          ),
        ),
      ),
    );
  }
}