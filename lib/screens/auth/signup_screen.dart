import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../widgets/brutal_widgets.dart';
import '../../models/models.dart';

// ── India State → Cities data ─────────────────────────────────
const Map<String, List<String>> _indiaCities = {
  'Andhra Pradesh': ['Visakhapatnam','Vijayawada','Guntur','Nellore','Kurnool','Tirupati','Kakinada','Rajahmundry','Kadapa','Anantapur'],
  'Arunachal Pradesh': ['Itanagar','Naharlagun','Pasighat','Tezpur','Bomdila'],
  'Assam': ['Guwahati','Silchar','Dibrugarh','Jorhat','Nagaon','Tinsukia','Tezpur','Bongaigaon','Dhubri'],
  'Bihar': ['Patna','Gaya','Bhagalpur','Muzaffarpur','Darbhanga','Purnia','Arrah','Begusarai','Katihar','Munger'],
  'Chhattisgarh': ['Raipur','Bhilai','Bilaspur','Korba','Durg','Rajnandgaon','Jagdalpur','Raigarh','Ambikapur'],
  'Delhi': ['New Delhi','Delhi','Dwarka','Rohini','Pitampura','Lajpat Nagar','Saket','Janakpuri','Preet Vihar'],
  'Goa': ['Panaji','Margao','Vasco da Gama','Mapusa','Ponda','Bicholim','Curchorem'],
  'Gujarat': ['Ahmedabad','Surat','Vadodara','Rajkot','Bhavnagar','Jamnagar','Junagadh','Gandhinagar','Anand','Nadiad'],
  'Haryana': ['Faridabad','Gurugram','Panipat','Ambala','Yamunanagar','Rohtak','Hisar','Karnal','Sonipat','Panchkula'],
  'Himachal Pradesh': ['Shimla','Dharamsala','Solan','Mandi','Kangra','Kullu','Hamirpur','Baddi'],
  'Jharkhand': ['Ranchi','Jamshedpur','Dhanbad','Bokaro','Deoghar','Phusro','Hazaribagh','Giridih','Ramgarh'],
  'Karnataka': ['Bengaluru','Mysuru','Mangaluru','Hubballi','Belagavi','Kalaburagi','Davangere','Ballari','Vijayapura','Shivamogga'],
  'Kerala': ['Thiruvananthapuram','Kochi','Kozhikode','Thrissur','Kollam','Kannur','Alappuzha','Malappuram','Palakkad','Kottayam'],
  'Madhya Pradesh': ['Indore','Bhopal','Jabalpur','Gwalior','Ujjain','Sagar','Dewas','Satna','Ratlam','Rewa'],
  'Maharashtra': ['Mumbai','Pune','Nagpur','Thane','Nashik','Aurangabad','Solapur','Kolhapur','Navi Mumbai','Amravati','Malegaon'],
  'Manipur': ['Imphal','Thoubal','Bishnupur','Churachandpur','Senapati'],
  'Meghalaya': ['Shillong','Tura','Jowai','Nongstoin','Baghmara'],
  'Mizoram': ['Aizawl','Lunglei','Champhai','Serchhip','Kolasib'],
  'Nagaland': ['Kohima','Dimapur','Mokokchung','Tuensang','Wokha'],
  'Odisha': ['Bhubaneswar','Cuttack','Rourkela','Brahmapur','Sambalpur','Puri','Balasore','Bhadrak','Baripada','Jharsuguda'],
  'Punjab': ['Ludhiana','Amritsar','Jalandhar','Patiala','Bathinda','Mohali','Firozpur','Hoshiarpur','Batala','Moga'],
  'Rajasthan': ['Jaipur','Jodhpur','Kota','Bikaner','Ajmer','Udaipur','Bhilwara','Alwar','Bharatpur','Sikar'],
  'Sikkim': ['Gangtok','Namchi','Gyalshing','Mangan','Rangpo'],
  'Tamil Nadu': ['Chennai','Coimbatore','Madurai','Tiruchirappalli','Salem','Tirunelveli','Tiruppur','Vellore','Erode','Thoothukudi'],
  'Telangana': ['Hyderabad','Warangal','Nizamabad','Karimnagar','Khammam','Ramagundam','Mahbubnagar','Nalgonda','Adilabad','Suryapet'],
  'Tripura': ['Agartala','Dharmanagar','Udaipur','Kailasahar','Belonia'],
  'Uttar Pradesh': ['Lucknow','Kanpur','Varanasi','Agra','Prayagraj','Meerut','Ghaziabad','Noida','Bareilly','Aligarh','Moradabad','Hapur'],
  'Uttarakhand': ['Dehradun','Haridwar','Roorkee','Haldwani','Rudrapur','Kashipur','Rishikesh','Kotdwar'],
  'West Bengal': ['Kolkata','Asansol','Siliguri','Durgapur','Bardhaman','Malda','Baharampur','Habra','Kharagpur','Shantipur'],
  'Andaman and Nicobar Islands': ['Port Blair','Diglipur','Rangat'],
  'Chandigarh': ['Chandigarh'],
  'Dadra and Nagar Haveli and Daman and Diu': ['Daman','Diu','Silvassa'],
  'Jammu & Kashmir': ['Srinagar','Jammu','Anantnag','Baramulla','Udhampur','Sopore'],
  'Ladakh': ['Leh','Kargil'],
  'Lakshadweep': ['Kavaratti','Andrott','Amini'],
  'Puducherry': ['Puducherry','Karaikal','Yanam','Mahé'],
};

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _usernameCtrl   = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _nameCtrl       = TextEditingController();
  final _numberCtrl     = TextEditingController();
  final _experienceCtrl = TextEditingController(text: '0');

  bool    _showPassword  = false;
  int     _step          = 0;
  bool    _showWakeUpHint = false;
  bool    _gettingLoc    = false;

  // Location state
  String?  _selectedState;
  String?  _selectedCity;
  double?  _latitude;
  double?  _longitude;
  bool     _locationAutoFilled = false; // true when GPS was used

  late AnimationController _stepCtrl;
  late Animation<double>   _stepFade;

  List<String> get _sortedStates => _indiaCities.keys.toList()..sort();
  List<String> get _citiesForState => _selectedState != null ? (_indiaCities[_selectedState] ?? []) : [];

  String get _locationDisplay {
    if (_selectedCity != null && _selectedState != null) return '$_selectedCity, $_selectedState';
    if (_selectedState != null) return _selectedState!;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _stepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _stepFade = Tween<double>(begin: 0, end: 1).animate(_stepCtrl);
    _stepCtrl.forward();
  }

  @override
  void dispose() {
    _stepCtrl.dispose();
    for (final c in [_usernameCtrl, _passwordCtrl, _nameCtrl, _numberCtrl, _experienceCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    _stepCtrl.reverse().then((_) { setState(() => _step++); _stepCtrl.forward(); });
  }

  // ── GPS auto-detect ─────────────────────────────────────────
  Future<void> _autoDetectLocation() async {
    setState(() => _gettingLoc = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied — please select state & city manually.'), backgroundColor: AppTheme.amber, behavior: SnackBarBehavior.floating));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      setState(() {
        _latitude  = pos.latitude;
        _longitude = pos.longitude;
        _locationAutoFilled = true;
      });
      // Rough GPS → state mapping for common coords (covers most of India)
      final (state, city) = _guessStateCity(pos.latitude, pos.longitude);
      if (state != null) {
        setState(() {
          _selectedState = state;
          _selectedCity  = city;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_selectedCity != null ? 'Location: $_selectedCity, $_selectedState' : 'GPS captured — please confirm your city below.'),
        backgroundColor: AppTheme.teal, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3),
      ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get GPS — select manually.'), backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  /// Rough bounding-box lookup — returns (state, city?) for common metro regions.
  (String?, String?) _guessStateCity(double lat, double lon) {
    if (lat >= 28.4 && lat <= 28.9 && lon >= 76.8 && lon <= 77.4) return ('Delhi', 'New Delhi');
    if (lat >= 18.8 && lat <= 19.3 && lon >= 72.7 && lon <= 73.1) return ('Maharashtra', 'Mumbai');
    if (lat >= 12.8 && lat <= 13.2 && lon >= 77.4 && lon <= 77.8) return ('Karnataka', 'Bengaluru');
    if (lat >= 22.4 && lat <= 22.8 && lon >= 88.2 && lon <= 88.6) return ('West Bengal', 'Kolkata');
    if (lat >= 17.2 && lat <= 17.6 && lon >= 78.3 && lon <= 78.7) return ('Telangana', 'Hyderabad');
    if (lat >= 12.9 && lat <= 13.2 && lon >= 80.1 && lon <= 80.4) return ('Tamil Nadu', 'Chennai');
    if (lat >= 22.9 && lat <= 23.2 && lon >= 72.5 && lon <= 72.8) return ('Gujarat', 'Ahmedabad');
    if (lat >= 18.4 && lat <= 18.7 && lon >= 73.7 && lon <= 74.0) return ('Maharashtra', 'Pune');
    if (lat >= 26.7 && lat <= 27.0 && lon >= 80.8 && lon <= 81.1) return ('Uttar Pradesh', 'Lucknow');
    if (lat >= 26.8 && lat <= 27.2 && lon >= 75.7 && lon <= 76.0) return ('Rajasthan', 'Jaipur');
    if (lat >= 30.6 && lat <= 30.9 && lon >= 76.6 && lon <= 76.9) return ('Chandigarh', 'Chandigarh');
    if (lat >= 23.1 && lat <= 23.4 && lon >= 77.3 && lon <= 77.6) return ('Madhya Pradesh', 'Bhopal');
    if (lat >= 21.1 && lat <= 21.4 && lon >= 81.5 && lon <= 81.8) return ('Chhattisgarh', 'Raipur');
    // State-level fallbacks
    if (lat >= 8.0  && lat <= 12.0 && lon >= 77.0 && lon <= 78.5) return ('Tamil Nadu', null);
    if (lat >= 12.0 && lat <= 15.0 && lon >= 74.0 && lon <= 78.5) return ('Karnataka', null);
    if (lat >= 15.0 && lat <= 20.0 && lon >= 73.0 && lon <= 80.0) return ('Maharashtra', null);
    if (lat >= 20.0 && lat <= 25.0 && lon >= 72.0 && lon <= 75.0) return ('Gujarat', null);
    if (lat >= 25.0 && lat <= 30.0 && lon >= 70.0 && lon <= 78.0) return ('Rajasthan', null);
    if (lat >= 27.0 && lat <= 30.0 && lon >= 78.0 && lon <= 84.0) return ('Uttar Pradesh', null);
    if (lat >= 20.0 && lat <= 24.0 && lon >= 80.0 && lon <= 84.0) return ('Madhya Pradesh', null);
    if (lat >= 17.0 && lat <= 20.0 && lon >= 78.0 && lon <= 82.0) return ('Telangana', null);
    return (null, null);
  }

  // ── Submit ──────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationDisplay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your state and city.'), backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
      return;
    }
    final auth = context.read<AuthProvider>();
    Future.delayed(const Duration(seconds: 5), () { if (mounted && auth.isLoading) setState(() => _showWakeUpHint = true); });

    final signupReq = SignupRequest(
      username:   _usernameCtrl.text.trim(),
      password:   _passwordCtrl.text,
      name:       _nameCtrl.text.trim(),
      number:     _numberCtrl.text.trim(),
      location:   _locationDisplay,
      experience: int.tryParse(_experienceCtrl.text) ?? 0,
      latitude:   _latitude,
      longitude:  _longitude,
    );
    final ok = await auth.signup(signupReq);
    if (mounted) setState(() => _showWakeUpHint = false);
    if (ok && mounted) { Navigator.of(context).popUntil((route) => route.isFirst); return; }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Sign up failed'), backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Stack(children: [
        Container(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.topRight, radius: 1.4, colors: [AppTheme.teal.withOpacity(0.10), Colors.transparent]))),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(key: _formKey, child: FadeTransition(opacity: _stepFade, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Back button
            if (_step > 0)
              GestureDetector(
                onTap: () { _stepCtrl.reverse().then((_) { setState(() => _step--); _stepCtrl.forward(); }); },
                child: Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.bgMuted)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.textMuted), SizedBox(width: 6), Text('Back', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted))])),
              ),

            // Step indicator
            Row(children: List.generate(3, (i) => Expanded(child: Container(
              height: 3, margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(color: i <= _step ? AppTheme.accent : AppTheme.bgMuted, borderRadius: BorderRadius.circular(2)),
            )))),
            const SizedBox(height: 32),

            // Step 0 — Account
            if (_step == 0) ...[
              const Text('Create Account', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
              const SizedBox(height: 4),
              const Text('Step 1 of 3 · Account details', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 32),
              BrutalTextField(label: 'Username', controller: _usernameCtrl, prefixIcon: const Icon(Icons.person_outline_rounded), validator: (v) => v!.trim().length < 3 ? 'Username must be at least 3 characters' : null),
              const SizedBox(height: 16),
              BrutalTextField(
                label: 'Password', controller: _passwordCtrl,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                obscureText: !_showPassword,
                suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.textMuted), onPressed: () => setState(() => _showPassword = !_showPassword)),
                validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 32),
              BrutalButton(label: 'NEXT', onPressed: _nextStep, width: double.infinity),
            ],

            // Step 1 — Profile
            if (_step == 1) ...[
              const Text('Your Profile', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
              const SizedBox(height: 4),
              const Text('Step 2 of 3 · Personal details', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 32),
              BrutalTextField(label: 'Full Name', controller: _nameCtrl, prefixIcon: const Icon(Icons.badge_outlined), validator: (v) => v!.trim().isEmpty ? 'Enter your name' : null),
              const SizedBox(height: 16),
              BrutalTextField(
                label: 'Phone Number', controller: _numberCtrl,
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.trim().length < 10 ? 'Enter a valid phone number' : null,
              ),
              const SizedBox(height: 16),
              BrutalTextField(
                label: 'Years of Experience', controller: _experienceCtrl,
                prefixIcon: const Icon(Icons.work_outline_rounded),
                keyboardType: TextInputType.number,
                validator: (v) { final n = int.tryParse(v ?? ''); return (n == null || n < 0) ? 'Enter a valid number' : null; },
              ),
              const SizedBox(height: 32),
              BrutalButton(label: 'NEXT', onPressed: _nextStep, width: double.infinity),
            ],

            // Step 2 — Location
            if (_step == 2) ...[
              const Text('Your Location', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
              const SizedBox(height: 4),
              const Text('Step 3 of 3 · Helps find nearby jobs', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 24),

              // Auto-detect button
              GestureDetector(
                onTap: _gettingLoc ? null : _autoDetectLocation,
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: _locationAutoFilled ? LinearGradient(colors: [AppTheme.teal.withOpacity(0.15), AppTheme.teal.withOpacity(0.05)]) : null,
                    color: _locationAutoFilled ? null : AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _locationAutoFilled ? AppTheme.teal.withOpacity(0.5) : AppTheme.bgMuted, width: _locationAutoFilled ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: _locationAutoFilled ? AppTheme.teal.withOpacity(0.15) : AppTheme.bgMuted, borderRadius: BorderRadius.circular(12)),
                      child: _gettingLoc
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.teal)))
                        : Icon(_locationAutoFilled ? Icons.location_on_rounded : Icons.my_location_rounded, color: _locationAutoFilled ? AppTheme.teal : AppTheme.textMuted, size: 22)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_locationAutoFilled ? 'Location Detected' : 'Auto-detect Location', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 14, color: _locationAutoFilled ? AppTheme.teal : AppTheme.text)),
                      Text(
                        _locationAutoFilled && _latitude != null
                            ? '${_latitude!.toStringAsFixed(4)}°N, ${_longitude!.toStringAsFixed(4)}°E'
                            : 'Uses GPS to find your city automatically',
                        style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 11, color: _locationAutoFilled ? AppTheme.teal.withOpacity(0.8) : AppTheme.textFaint),
                      ),
                    ])),
                    if (_locationAutoFilled) const Icon(Icons.check_circle_rounded, color: AppTheme.teal, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Row(children: [
                Expanded(child: Container(height: 1, color: AppTheme.bgMuted)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR SELECT MANUALLY', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 10, color: AppTheme.textFaint, letterSpacing: 1))),
                Expanded(child: Container(height: 1, color: AppTheme.bgMuted)),
              ]),
              const SizedBox(height: 16),

              // State dropdown
              Container(
                decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.bgMuted)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedState,
                  hint: const Text('Select State', style: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                  dropdownColor: AppTheme.bgElevated,
                  style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
                  items: _sortedStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() { _selectedState = val; _selectedCity = null; _locationAutoFilled = false; }),
                )),
              ),
              const SizedBox(height: 12),

              // City dropdown
              AnimatedOpacity(
                opacity: _selectedState != null ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: _selectedCity != null ? AppTheme.accent.withOpacity(0.4) : AppTheme.bgMuted)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCity,
                    hint: Text(_selectedState != null ? 'Select City in $_selectedState' : 'Select State first', style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                    dropdownColor: AppTheme.bgElevated,
                    style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
                    items: _citiesForState.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: _selectedState == null ? null : (val) => setState(() => _selectedCity = val),
                  )),
                ),
              ),

              // Selected location preview
              if (_locationDisplay.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_locationDisplay, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accent))),
                    if (_latitude != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.gps_fixed_rounded, size: 13, color: AppTheme.teal),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 32),

              // Wake-up hint
              if (_showWakeUpHint) ...[
                Container(
                  padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.amber.withOpacity(0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.amber.withOpacity(0.3))),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.amber), SizedBox(width: 10),
                    Expanded(child: Text('Server is waking up — this may take up to 30s on first request.', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.amber))),
                  ]),
                ),
              ],

              BrutalButton(label: 'CREATE ACCOUNT', onPressed: auth.isLoading ? null : _submit, isLoading: auth.isLoading, width: double.infinity),
              const SizedBox(height: 16),
              Center(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(text: const TextSpan(style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13), children: [
                  TextSpan(text: 'Already have an account? ', style: TextStyle(color: AppTheme.textMuted)),
                  TextSpan(text: 'Sign In', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
                ])),
              )),
            ],
          ]))),
        ),
      ])),
    );
  }
}