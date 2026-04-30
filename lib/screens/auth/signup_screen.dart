import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/brutal_widgets.dart';
import '../../models/models.dart';
import '../../screens/main_shell.dart';
import 'oauth_complete_profile_screen.dart';

const Map<String, List<String>> _indiaCities = {
  'Andhra Pradesh': ['Visakhapatnam','Vijayawada','Guntur','Nellore','Kurnool','Tirupati','Kakinada','Rajahmundry'],
  'Arunachal Pradesh': ['Itanagar','Naharlagun','Pasighat'],
  'Assam': ['Guwahati','Silchar','Dibrugarh','Jorhat','Nagaon'],
  'Bihar': ['Patna','Gaya','Bhagalpur','Muzaffarpur','Darbhanga','Purnia'],
  'Chhattisgarh': ['Raipur','Bhilai','Bilaspur','Korba','Durg'],
  'Delhi': ['New Delhi','Delhi','Dwarka','Rohini','Pitampura','Lajpat Nagar','Saket'],
  'Goa': ['Panaji','Margao','Vasco da Gama','Mapusa'],
  'Gujarat': ['Ahmedabad','Surat','Vadodara','Rajkot','Bhavnagar','Jamnagar','Gandhinagar'],
  'Haryana': ['Faridabad','Gurugram','Panipat','Ambala','Rohtak','Hisar'],
  'Himachal Pradesh': ['Shimla','Dharamsala','Solan','Mandi'],
  'Jharkhand': ['Ranchi','Jamshedpur','Dhanbad','Bokaro'],
  'Karnataka': ['Bengaluru','Mysuru','Mangaluru','Hubballi','Belagavi','Davangere'],
  'Kerala': ['Thiruvananthapuram','Kochi','Kozhikode','Thrissur','Kollam','Kannur'],
  'Madhya Pradesh': ['Indore','Bhopal','Jabalpur','Gwalior','Ujjain'],
  'Maharashtra': ['Mumbai','Pune','Nagpur','Thane','Nashik','Aurangabad','Solapur','Navi Mumbai'],
  'Manipur': ['Imphal','Thoubal'],
  'Meghalaya': ['Shillong','Tura'],
  'Mizoram': ['Aizawl','Lunglei'],
  'Nagaland': ['Kohima','Dimapur'],
  'Odisha': ['Bhubaneswar','Cuttack','Rourkela','Brahmapur','Sambalpur'],
  'Punjab': ['Ludhiana','Amritsar','Jalandhar','Patiala','Bathinda','Mohali'],
  'Rajasthan': ['Jaipur','Jodhpur','Kota','Bikaner','Ajmer','Udaipur'],
  'Sikkim': ['Gangtok','Namchi'],
  'Tamil Nadu': ['Chennai','Coimbatore','Madurai','Tiruchirappalli','Salem','Tiruppur'],
  'Telangana': ['Hyderabad','Warangal','Nizamabad','Karimnagar'],
  'Tripura': ['Agartala'],
  'Uttar Pradesh': ['Lucknow','Kanpur','Varanasi','Agra','Prayagraj','Meerut','Ghaziabad','Noida','Bareilly'],
  'Uttarakhand': ['Dehradun','Haridwar','Roorkee','Haldwani','Rudrapur'],
  'West Bengal': ['Kolkata','Asansol','Siliguri','Durgapur','Bardhaman'],
  'Chandigarh': ['Chandigarh'],
  'Jammu & Kashmir': ['Srinagar','Jammu','Anantnag','Baramulla'],
  'Ladakh': ['Leh','Kargil'],
  'Puducherry': ['Puducherry','Karaikal'],
};

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController(text: '0');

  bool _showPassword = false;
  int _step = 0; // 0=account, 1=profile, 2=location, 3=verify
  bool _showWakeUpHint = false;
  bool _gettingLoc = false;
  bool _oauthLoading = false;

  // OTP state
  bool _emailOtpSent = false;
  bool _emailVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  final _emailOtpCtrl = TextEditingController();
  int _otpResendCountdown = 0;
  Timer? _resendTimer;

  // Location state
  String? _selectedState;
  String? _selectedCity;
  double? _latitude;
  double? _longitude;
  bool _locationAutoFilled = false;

  late AnimationController _stepCtrl;
  late Animation<double> _stepFade;

  List<String> get _sortedStates => _indiaCities.keys.toList()..sort();
  List<String> get _citiesForState => _selectedState != null ? (_indiaCities[_selectedState] ?? []) : [];

  String get _locationDisplay {
    if (_selectedCity != null && _selectedState != null) return '$_selectedCity, $_selectedState';
    if (_selectedState != null) return _selectedState!;
    return '';
  }

  static const String _backendUrl = 'https://job-posting-u2lr.onrender.com';
  static const String _callbackScheme = 'posting';

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
    _resendTimer?.cancel();
    for (final c in [_usernameCtrl, _passwordCtrl, _nameCtrl, _numberCtrl,
        _emailCtrl, _experienceCtrl, _emailOtpCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int step) {
    _stepCtrl.reverse().then((_) { setState(() => _step = step); _stepCtrl.forward(); });
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    // FIX: When advancing from step 2 (location) to step 3 (OTP), create the
    // account first so a JWT exists before OTP send/verify calls are made.
    if (_step == 2) {
      _signupThenVerify();
    } else {
      _goTo(_step + 1);
    }
  }

  /// Registers the user, logs them in (JWT stored), then advances to OTP step.
  Future<void> _signupThenVerify() async {
    if (_locationDisplay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your state and city.'),
        backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
      return;
    }
    final auth = context.read<AuthProvider>();
    
    // If already authenticated (e.g. user went back from step 3 to 2 and clicked NEXT again),
    // skip the signup call to avoid "Username already exists" error.
    if (auth.isAuthenticated) {
      _goTo(3);
      return;
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && auth.isLoading) setState(() => _showWakeUpHint = true);
    });

    final ok = await auth.signup(SignupRequest(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      name: _nameCtrl.text.trim(),
      number: _numberCtrl.text.trim(),
      location: _locationDisplay,
      experience: int.tryParse(_experienceCtrl.text) ?? 0,
      latitude: _latitude,
      longitude: _longitude,
    ));
    if (mounted) setState(() => _showWakeUpHint = false);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? 'Sign up failed'),
        backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4)));
      return;
    }
    // Account created and JWT stored — now enter OTP step
    _goTo(3);
  }

  // ── OTP helpers ────────────────────────────────────────────────────────────
  void _startResendTimer() {
    _otpResendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_otpResendCountdown <= 0) { t.cancel(); return; }
      if (mounted) setState(() => _otpResendCountdown--);
    });
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Please enter an email address first.');
      return;
    }
    
    // Basic email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _sendingOtp = true);
    
    // Show wake-up hint if it takes too long
    final wakeUpTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _sendingOtp) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Server is waking up, please wait...'),
          duration: Duration(seconds: 3),
        ));
      }
    });

    try {
      final un = _usernameCtrl.text.trim();
      await apiService.sendOtp(
        type: 'email', 
        value: email, 
        username: un.isNotEmpty ? un : null
      );
      
      wakeUpTimer.cancel();
      if (mounted) {
        setState(() { _emailOtpSent = true; _sendingOtp = false; });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('OTP sent to $email'),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      wakeUpTimer.cancel();
      if (mounted) {
        setState(() => _sendingOtp = false);
        _showError('Failed to send OTP: ${_shortError(e)}');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _verifyEmailOtp() async {
    final otp = _emailOtpCtrl.text.trim();
    if (otp.length < 4) return;
    setState(() => _verifyingOtp = true);
    try {
      final un = _usernameCtrl.text.trim();
      await apiService.verifyOtp(type: 'email', value: _emailCtrl.text.trim(), otp: otp, username: un.isNotEmpty ? un : null);
      setState(() { _emailVerified = true; _verifyingOtp = false; });
      if (mounted) {
        context.read<AuthProvider>().refreshUserProfile();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Email verified ✓'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingOtp = false);
        _showError('Verification failed: ${_shortError(e)}');
      }
    }
  }

  String _shortError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        // APIError uses 'error' field — also check 'message' as fallback
        final msg = (data['error'] ?? data['message'])?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return 'Please try again.';
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<void> _autoDetectLocation() async {
    setState(() => _gettingLoc = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission denied — please select manually.'),
          backgroundColor: AppTheme.amber, behavior: SnackBarBehavior.floating));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      setState(() { _latitude = pos.latitude; _longitude = pos.longitude; _locationAutoFilled = true; });

      String? detectedState, detectedCity;
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          detectedState = p.administrativeArea;
          detectedCity = p.locality?.isNotEmpty == true ? p.locality : p.subAdministrativeArea;
        }
      } catch (_) {}

      if (detectedState != null) {
        final matched = _sortedStates.firstWhere(
          (s) => s.toLowerCase() == detectedState!.toLowerCase(),
          orElse: () => _sortedStates.firstWhere(
            (s) => s.toLowerCase().contains(detectedState!.toLowerCase()) ||
                   detectedState.toLowerCase().contains(s.toLowerCase()),
            orElse: () => '',
          ),
        );
        if (matched.isNotEmpty) {
          String? matchedCity;
          if (detectedCity != null) {
            final cities = _indiaCities[matched] ?? [];
            final mc = cities.firstWhere(
              (c) => c.toLowerCase() == detectedCity!.toLowerCase(),
              orElse: () => cities.firstWhere(
                (c) => c.toLowerCase().contains(detectedCity!.toLowerCase()) ||
                       detectedCity.toLowerCase().contains(c.toLowerCase()),
                orElse: () => '',
              ),
            );
            if (mc.isNotEmpty) matchedCity = mc;
          }
          setState(() { _selectedState = matched; _selectedCity = matchedCity; });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Location set: ${matchedCity ?? detectedCity ?? 'your area'}, $matched'),
              backgroundColor: AppTheme.teal, behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('GPS captured — please confirm state & city below.'),
        backgroundColor: AppTheme.amber, behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not get GPS — select manually.'),
        backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  // ── OAuth ─────────────────────────────────────────────────────────────────
  Future<void> _oauthSignup(String provider) async {
    setState(() { _oauthLoading = true; });
    try {
      final authUrl = '$_backendUrl/oauth2/authorization/$provider';
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl, callbackUrlScheme: _callbackScheme);

      if (!mounted) return;
      final uri = Uri.parse(result);
      final errorParam = uri.queryParameters['error'];
      if (errorParam != null && errorParam.isNotEmpty) throw Exception(errorParam);

      final accessToken = uri.queryParameters['accessToken'];
      final refreshToken = uri.queryParameters['refreshToken'];
      if (accessToken == null || refreshToken == null) throw Exception('No tokens received');

      final profileId = int.tryParse(uri.queryParameters['profileId'] ?? '');
      final appUserId = int.tryParse(uri.queryParameters['appUserId'] ?? '');

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ok = await auth.loginWithOAuthTokens(
        accessToken, refreshToken, profileId: profileId, appUserId: appUserId);

      if (!mounted) return;
      if (ok) {
        if (auth.needsProfileCompletion) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OAuthCompleteProfileScreen()));
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(auth.error ?? 'OAuth failed'),
          backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('CANCELED') ? 'Sign-in cancelled' : 'OAuth failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  // FIX: By the time the user reaches step 3, _signupThenVerify() has already
  // created the account and stored the JWT. _submit() just navigates home.
  Future<void> _submit() async {
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = auth.isLoading || _oauthLoading || _sendingOtp || _verifyingOtp;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Stack(children: [
        Container(decoration: BoxDecoration(gradient: RadialGradient(
          center: Alignment.topRight, radius: 1.4,
          colors: [AppTheme.teal.withOpacity(0.10), Colors.transparent]))),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: FadeTransition(
              opacity: _stepFade,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Back
                if (_step > 0)
                  GestureDetector(
                    onTap: () => _goTo(_step - 1),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: AppTheme.bgElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.bgMuted)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.textMuted),
                        SizedBox(width: 6),
                        Text('Back', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
                      ]),
                    ),
                  ),

                // Step indicator
                Row(children: List.generate(4, (i) => Expanded(child: Container(
                  height: 3, margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step ? AppTheme.accent : AppTheme.bgMuted,
                    borderRadius: BorderRadius.circular(2)),
                )))),
                const SizedBox(height: 32),

                // ── Step 0: Account + OAuth ────────────────────────────────
                if (_step == 0) ..._buildStep0(busy),

                // ── Step 1: Profile ────────────────────────────────────────
                if (_step == 1) ..._buildStep1(),

                // ── Step 2: Location ───────────────────────────────────────
                if (_step == 2) ..._buildStep2(auth),

                // ── Step 3: Verify ─────────────────────────────────────────
                if (_step == 3) ..._buildStep3(auth, busy),
              ]),
            ),
          ),
        ),
      ])),
    );
  }

  // ── Step builders ──────────────────────────────────────────────────────────

  List<Widget> _buildStep0(bool busy) => [
    const Text('Create Account', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
    const SizedBox(height: 4),
    const Text('Step 1 of 4 · Account details', style: TextStyle(
      fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
    const SizedBox(height: 32),

    BrutalTextField(label: 'Username', controller: _usernameCtrl,
      prefixIcon: const Icon(Icons.person_outline_rounded),
      validator: (v) => v!.trim().length < 3 ? 'At least 3 characters' : null),
    const SizedBox(height: 16),
    BrutalTextField(
      label: 'Password', controller: _passwordCtrl,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      obscureText: !_showPassword,
      suffixIcon: IconButton(
        icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppTheme.textMuted),
        onPressed: () => setState(() => _showPassword = !_showPassword)),
      validator: (v) => v!.length < 8 ? 'At least 8 characters' : null),
    const SizedBox(height: 32),
    BrutalButton(label: 'NEXT', onPressed: busy ? null : _nextStep, width: double.infinity),
    const SizedBox(height: 20),

    const Row(children: [
      Expanded(child: Divider(color: AppTheme.bgMuted)),
      Padding(padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('or sign up with', style: TextStyle(
          fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint))),
      Expanded(child: Divider(color: AppTheme.bgMuted)),
    ]),
    const SizedBox(height: 20),

    _OAuthBtn(
      label: 'Continue with Google',
      icon: _GoogleIcon(),
      loading: _oauthLoading,
      onTap: busy ? null : () => _oauthSignup('google'),
    ),
    const SizedBox(height: 12),
    _OAuthBtn(
      label: 'Continue with GitHub',
      icon: const Icon(Icons.code_rounded, size: 20, color: Colors.white),
      loading: _oauthLoading,
      onTap: busy ? null : () => _oauthSignup('github'),
    ),
    const SizedBox(height: 24),

    Center(child: GestureDetector(
      onTap: () => Navigator.pop(context),
      child: RichText(text: const TextSpan(style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13), children: [
        TextSpan(text: 'Already have an account? ', style: TextStyle(color: AppTheme.textMuted)),
        TextSpan(text: 'Sign In', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
      ])),
    )),
  ];

  List<Widget> _buildStep1() => [
    const Text('Your Profile', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
    const SizedBox(height: 4),
    const Text('Step 2 of 4 · Personal details', style: TextStyle(
      fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
    const SizedBox(height: 32),
    BrutalTextField(label: 'Full Name', controller: _nameCtrl,
      prefixIcon: const Icon(Icons.badge_outlined),
      validator: (v) => v!.trim().isEmpty ? 'Enter your name' : null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Phone Number', controller: _numberCtrl,
      prefixIcon: const Icon(Icons.phone_outlined),
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
      validator: (v) => v!.trim().length < 10 ? 'Enter a valid 10-digit number' : null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Email (optional, for verification)', controller: _emailCtrl,
      prefixIcon: const Icon(Icons.email_outlined),
      keyboardType: TextInputType.emailAddress,
      validator: (_) => null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Years of Experience', controller: _experienceCtrl,
      prefixIcon: const Icon(Icons.work_outline_rounded),
      keyboardType: TextInputType.number,
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return (n == null || n < 0) ? 'Enter a valid number' : null;
      }),
    const SizedBox(height: 32),
    BrutalButton(label: 'NEXT', onPressed: _nextStep, width: double.infinity),
  ];

  List<Widget> _buildStep2(AuthProvider auth) => [
    const Text('Your Location', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
    const SizedBox(height: 4),
    const Text('Step 3 of 4 · Helps find nearby jobs', style: TextStyle(
      fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
    const SizedBox(height: 24),

    // Auto-detect
    GestureDetector(
      onTap: _gettingLoc ? null : _autoDetectLocation,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _locationAutoFilled ? LinearGradient(colors: [
            AppTheme.teal.withOpacity(0.15), AppTheme.teal.withOpacity(0.05)]) : null,
          color: _locationAutoFilled ? null : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _locationAutoFilled
              ? AppTheme.teal.withOpacity(0.5) : AppTheme.bgMuted,
              width: _locationAutoFilled ? 1.5 : 1)),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: _locationAutoFilled ? AppTheme.teal.withOpacity(0.15) : AppTheme.bgMuted,
              borderRadius: BorderRadius.circular(12)),
            child: _gettingLoc
                ? const Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.teal)))
                : Icon(_locationAutoFilled ? Icons.location_on_rounded : Icons.my_location_rounded,
                    color: _locationAutoFilled ? AppTheme.teal : AppTheme.textMuted, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_locationAutoFilled ? 'Location Detected' : 'Get My Location',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                fontSize: 14, color: _locationAutoFilled ? AppTheme.teal : AppTheme.text)),
            Text(_locationAutoFilled && _locationDisplay.isNotEmpty
                ? _locationDisplay : 'Tap to auto-fill your state & city',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 11,
                color: _locationAutoFilled ? AppTheme.teal.withOpacity(0.8) : AppTheme.textFaint)),
          ])),
          if (_locationAutoFilled) const Icon(Icons.check_circle_rounded, color: AppTheme.teal, size: 20),
        ]),
      ),
    ),
    const SizedBox(height: 16),

    const Row(children: [
      Expanded(child: Divider(color: AppTheme.bgMuted)),
      Padding(padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('OR SELECT MANUALLY', style: TextStyle(fontFamily: 'SpaceGrotesk',
          fontSize: 10, color: AppTheme.textFaint, letterSpacing: 1))),
      Expanded(child: Divider(color: AppTheme.bgMuted)),
    ]),
    const SizedBox(height: 16),

    // State dropdown
    AbsorbPointer(
      absorbing: _locationAutoFilled,
      child: Opacity(
        opacity: _locationAutoFilled ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.bgMuted)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            isExpanded: true, value: _selectedState,
            hint: const Text('Select State', style: TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14)),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
            dropdownColor: AppTheme.bgElevated,
            style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
            items: _sortedStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) => setState(() { _selectedState = val; _selectedCity = null; _locationAutoFilled = false; }),
          )),
        ),
      ),
    ),
    const SizedBox(height: 12),

    // City dropdown
    AbsorbPointer(
      absorbing: _locationAutoFilled,
      child: AnimatedOpacity(
        opacity: _locationAutoFilled ? 0.6 : (_selectedState != null ? 1.0 : 0.4),
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _selectedCity != null ? AppTheme.accent.withOpacity(0.4) : AppTheme.bgMuted)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            isExpanded: true, value: _selectedCity,
            hint: Text(_selectedState != null ? 'Select City in $_selectedState' : 'Select State first',
              style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.textFaint, fontSize: 14)),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
            dropdownColor: AppTheme.bgElevated,
            style: const TextStyle(fontFamily: 'SpaceGrotesk', color: AppTheme.text, fontSize: 14),
            items: _citiesForState.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: _selectedState == null ? null : (val) => setState(() => _selectedCity = val),
          )),
        ),
      ),
    ),

    if (_locationDisplay.isNotEmpty) ...[
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(_locationDisplay, style: const TextStyle(
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accent))),
          if (_latitude != null) const Icon(Icons.gps_fixed_rounded, size: 13, color: AppTheme.teal),
        ]),
      ),
    ],
    const SizedBox(height: 32),
    BrutalButton(
      label: 'NEXT',
      // FIX: show loading while _signupThenVerify() runs
      onPressed: auth.isLoading ? null : _nextStep,
      isLoading: auth.isLoading,
      width: double.infinity),
  ];

  List<Widget> _buildStep3(AuthProvider auth, bool busy) => [
    const Text('Verify Identity', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -1, color: AppTheme.text)),
    const SizedBox(height: 4),
    const Text('Step 4 of 4 · OTP verification (optional)', style: TextStyle(
      fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textMuted)),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal.withOpacity(0.2))),
      child: const Text(
        'Verifying your email builds trust with employers. You can skip and verify later.',
        style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.teal)),
    ),
    const SizedBox(height: 28),



    // ── Email OTP ──────────────────────────────────────────────────────────
    if (_emailCtrl.text.isNotEmpty)
      _VerifyCard(
        title: 'Email',
        subtitle: _emailCtrl.text,
        icon: Icons.email_rounded,
        verified: _emailVerified,
        otpSent: _emailOtpSent,
        otpCtrl: _emailOtpCtrl,
        sendingOtp: _sendingOtp,
        verifyingOtp: _verifyingOtp,
        resendCountdown: _otpResendCountdown,
        onSend: _sendEmailOtp,
        onVerify: _verifyEmailOtp,
      ),

    if (_showWakeUpHint) ...[
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.amber.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.amber.withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.amber),
          SizedBox(width: 10),
          Expanded(child: Text('Server is waking up — may take up to 30s.',
            style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.amber))),
        ]),
      ),
    ],
    const SizedBox(height: 32),

    BrutalButton(
      // FIX: account is already created; this button just navigates home
      label: 'CONTINUE',
      onPressed: busy ? null : _submit,
      isLoading: auth.isLoading,
      width: double.infinity),
    const SizedBox(height: 12),
    Center(child: GestureDetector(
      onTap: busy ? null : _submit,
      child: const Text('Skip verification & continue',
        style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13,
          color: AppTheme.textMuted, decoration: TextDecoration.underline)),
    )),
  ];
}

// ── OTP Verify Card ────────────────────────────────────────────────────────
class _VerifyCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool verified, otpSent, sendingOtp, verifyingOtp;
  final int resendCountdown;
  final TextEditingController otpCtrl;
  final VoidCallback? onSend, onVerify;

  const _VerifyCard({
    required this.title, required this.subtitle, required this.icon,
    required this.verified, required this.otpSent, required this.otpCtrl,
    required this.sendingOtp, required this.verifyingOtp,
    required this.resendCountdown, required this.onSend, required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified ? AppTheme.green.withOpacity(0.06) : AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified ? AppTheme.green.withOpacity(0.3) : AppTheme.bgMuted, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: verified ? AppTheme.green.withOpacity(0.12) : AppTheme.bgMuted,
              borderRadius: BorderRadius.circular(10)),
            child: Icon(verified ? Icons.check_circle_rounded : icon,
              size: 20, color: verified ? AppTheme.green : AppTheme.textMuted)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.text)),
            Text(subtitle, style: const TextStyle(fontFamily: 'SpaceGrotesk',
              fontSize: 12, color: AppTheme.textMuted)),
          ])),
          if (verified)
            const Text('Verified', style: TextStyle(fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.green))
          else if (!otpSent)
            GestureDetector(
              onTap: sendingOtp ? null : onSend,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.accentShadow()),
                child: sendingOtp
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send OTP', style: TextStyle(fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
              ),
            ),
        ]),

        if (otpSent && !verified) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _OtpField(controller: otpCtrl)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: verifyingOtp ? null : onVerify,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.teal.withOpacity(0.3))),
                child: verifyingOtp
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.teal))
                    : const Text('Verify', style: TextStyle(fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.teal)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: (resendCountdown > 0 || sendingOtp) ? null : onSend,
            child: Text(
              resendCountdown > 0 ? 'Resend in ${resendCountdown}s' : 'Resend OTP',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12,
                color: resendCountdown > 0 ? AppTheme.textFaint : AppTheme.accent,
                decoration: resendCountdown > 0 ? null : TextDecoration.underline)),
          ),
        ],
      ]),
    );
  }
}

class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  const _OtpField({required this.controller});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18,
      fontWeight: FontWeight.w700, color: AppTheme.text, letterSpacing: 8),
    decoration: InputDecoration(
      counterText: '',
      hintText: '······',
      hintStyle: TextStyle(color: AppTheme.textFaint.withOpacity(0.4), letterSpacing: 8),
      filled: true, fillColor: AppTheme.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.bgMuted)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.bgMuted)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
  );
}

// Reusable OAuth button
class _OAuthBtn extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool loading;
  const _OAuthBtn({required this.label, required this.icon, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onTap == null ? 0.5 : 1.0,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.bgMuted, width: 1)),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 20, height: 20, child: icon),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.text)),
              ]),
      ),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 20,
    decoration: BoxDecoration(color: const Color(0xFF4285F4), borderRadius: BorderRadius.circular(4)),
    child: const Center(child: Text('G', style: TextStyle(color: Colors.white,
      fontWeight: FontWeight.w700, fontSize: 12))),
  );
}