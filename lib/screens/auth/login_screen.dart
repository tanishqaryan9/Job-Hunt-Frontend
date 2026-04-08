import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../widgets/brutal_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  late AnimationController _slideCtrl;
  late AnimationController _floatCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn));
    _floatAnim = Tween<double>(begin: -10, end: 10)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() { _slideCtrl.dispose(); _floatCtrl.dispose(); _usernameCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? 'Login failed'),
        backgroundColor: AppTheme.rose, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        // Ambient glow
        Positioned(top: -120, left: -80,
          child: Container(width: 360, height: 360,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppTheme.accent.withOpacity(0.14), Colors.transparent])))),
        Positioned(bottom: -80, right: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppTheme.teal.withOpacity(0.09), Colors.transparent])))),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 48),
              // Floating icon
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppTheme.accentShadow(),
                    ),
                    child: const Icon(Icons.work_rounded, size: 36, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Welcome\nback.', style: TextStyle(
                      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                      fontSize: 42, height: 1.05, letterSpacing: -2, color: AppTheme.text,
                    )),
                    const SizedBox(height: 8),
                    const Text('Sign in to continue your journey', style: TextStyle(
                      fontFamily: 'SpaceGrotesk', fontSize: 15, color: AppTheme.textMuted,
                    )),
                    const SizedBox(height: 40),
                    Form(key: _formKey, child: Column(children: [
                      BrutalTextField(label: 'Username', controller: _usernameCtrl,
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (v) => v!.isEmpty ? 'Enter username' : null),
                      const SizedBox(height: 16),
                      BrutalTextField(label: 'Password', controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter password' : null),
                      const SizedBox(height: 28),
                      BrutalButton(label: 'SIGN IN', onPressed: _login,
                        isLoading: auth.isLoading, width: double.infinity),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(child: Divider(color: AppTheme.bgMuted)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(fontFamily: 'SpaceGrotesk',
                            fontSize: 13, color: AppTheme.textFaint))),
                        Expanded(child: Divider(color: AppTheme.bgMuted)),
                      ]),
                      const SizedBox(height: 20),
                      _OAuthButton(
                        label: 'Continue with Google',
                        color: const Color(0xFF1E2333),
                        icon: _GoogleIcon(),
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _OAuthButton(
                        label: 'Continue with GitHub',
                        color: const Color(0xFF1E2333),
                        icon: const Icon(Icons.code_rounded, size: 20, color: Colors.white),
                        onTap: () {},
                      ),
                      const SizedBox(height: 36),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text("Don't have an account? ", style: TextStyle(
                          fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                          child: const Text('Sign Up', style: TextStyle(
                            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                            fontSize: 14, color: AppTheme.accent)),
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ])),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final Color color;
  final Widget icon;
  final VoidCallback onTap;
  const _OAuthButton({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.bgMuted, width: 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 20, height: 20, child: icon),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.text)),
      ]),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 20,
    decoration: BoxDecoration(color: const Color(0xFF4285F4), borderRadius: BorderRadius.circular(4)),
    child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
  );
}
