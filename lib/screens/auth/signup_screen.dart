import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../widgets/brutal_widgets.dart';
import '../../models/models.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl   = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _nameCtrl       = TextEditingController();
  final _numberCtrl     = TextEditingController();
  final _locationCtrl   = TextEditingController();
  final _experienceCtrl = TextEditingController(text: '0');
  bool _showPassword = false;
  int _step = 0;

  late AnimationController _stepCtrl;
  late Animation<double> _stepFade;

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
    for (final c in [_usernameCtrl, _passwordCtrl, _nameCtrl, _numberCtrl, _locationCtrl, _experienceCtrl]) c.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    _stepCtrl.reverse().then((_) { setState(() => _step++); _stepCtrl.forward(); });
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  final auth = context.read<AuthProvider>();
  final signupReq = SignupRequest(
    username: _usernameCtrl.text.trim(),
    password: _passwordCtrl.text,
    name: _nameCtrl.text.trim(),
    number: _numberCtrl.text.trim(),
    location: _locationCtrl.text.trim(),
    experience: int.tryParse(_experienceCtrl.text) ?? 0,
  );
  final ok = await auth.signup(signupReq);
  if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(auth.error ?? 'Sign up failed'),
    backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating));
}

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        Positioned(top: -100, right: -60,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppTheme.teal.withOpacity(0.10), Colors.transparent])))),

        SafeArea(child: Column(children: [
          // Progress bar + back
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textMuted),
                onPressed: () => _step == 0 ? Navigator.pop(context)
                    : _stepCtrl.reverse().then((_) { setState(() => _step--); _stepCtrl.forward(); }),
              ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_step == 0 ? 'Account Setup' : 'Your Details', style: const TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 14, color: AppTheme.text)),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                  value: (_step + 1) / 2,
                  backgroundColor: AppTheme.bgMuted,
                  color: AppTheme.accent,
                  minHeight: 4,
                )),
              ])),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: FadeTransition(
                opacity: _stepFade,
                child: Form(key: _formKey, child: _step == 0 ? _buildStep0() : _buildStep1(auth)),
              ),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _buildStep0() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 56, height: 56,
      decoration: BoxDecoration(gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.accentShadow()),
      child: const Icon(Icons.lock_outline_rounded, size: 28, color: Colors.white)),
    const SizedBox(height: 24),
    const Text('Create\nyour account', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w700, fontSize: 36, height: 1.1, letterSpacing: -1.5, color: AppTheme.text)),
    const SizedBox(height: 8),
    const Text('Start your career journey today', style: TextStyle(
      fontFamily: 'SpaceGrotesk', fontSize: 15, color: AppTheme.textMuted)),
    const SizedBox(height: 40),
    BrutalTextField(label: 'Username', controller: _usernameCtrl,
      prefixIcon: const Icon(Icons.person_outline_rounded),
      validator: (v) => v!.isEmpty ? 'Enter username' : null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Password', controller: _passwordCtrl,
      obscureText: !_showPassword, prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _showPassword = !_showPassword)),
      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null),
    const SizedBox(height: 32),
    BrutalButton(label: 'Continue', onPressed: _nextStep, width: double.infinity,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white)),
    const SizedBox(height: 24),
    Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('Already have an account? ', style: TextStyle(
        fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Text('Sign In', style: TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accent)),
      ),
    ])),
    const SizedBox(height: 32),
  ]);

  Widget _buildStep1(AuthProvider auth) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 56, height: 56,
      decoration: BoxDecoration(
        color: AppTheme.teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.teal.withOpacity(0.3), width: 1),
      ),
      child: const Icon(Icons.person_pin_rounded, size: 28, color: AppTheme.teal)),
    const SizedBox(height: 24),
    const Text('Almost\nthere!', style: TextStyle(fontFamily: 'SpaceGrotesk',
      fontWeight: FontWeight.w700, fontSize: 36, height: 1.1, letterSpacing: -1.5, color: AppTheme.text)),
    const SizedBox(height: 8),
    const Text('Tell us a bit about yourself', style: TextStyle(
      fontFamily: 'SpaceGrotesk', fontSize: 15, color: AppTheme.textMuted)),
    const SizedBox(height: 40),
    BrutalTextField(label: 'Full Name', controller: _nameCtrl,
      prefixIcon: const Icon(Icons.badge_outlined),
      validator: (v) => v!.isEmpty ? 'Enter your name' : null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Phone Number', controller: _numberCtrl,
      keyboardType: TextInputType.phone, prefixIcon: const Icon(Icons.phone_outlined),
      validator: (v) => v!.isEmpty ? 'Enter phone' : null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Location', controller: _locationCtrl,
      prefixIcon: const Icon(Icons.location_on_outlined),
      validator: (v) => v!.isEmpty ? 'Enter location' : null),
    const SizedBox(height: 16),
    BrutalTextField(label: 'Years of Experience', controller: _experienceCtrl,
      keyboardType: TextInputType.number, prefixIcon: const Icon(Icons.work_outline)),
    const SizedBox(height: 32),
    BrutalButton(label: 'Create Account', onPressed: _submit,
      isLoading: auth.isLoading, width: double.infinity),
    const SizedBox(height: 32),
  ]);
}
