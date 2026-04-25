import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../../widgets/brutal_widgets.dart';
import '../../screens/main_shell.dart';
import 'signup_screen.dart';
import 'oauth_complete_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _oauthLoading = false;
  bool _showWakeUpHint = false;

  late AnimationController _slideCtrl;
  late AnimationController _floatCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;

  static const String _backendUrl = 'https://job-posting-u2lr.onrender.com';
  static const String _callbackScheme = 'posting';

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn));
    _floatAnim = Tween<double>(begin: -10, end: 10)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _floatCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && auth.isLoading) setState(() => _showWakeUpHint = true);
    });

    final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (mounted) setState(() => _showWakeUpHint = false);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? 'Login failed'),
        backgroundColor: AppTheme.rose,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _oauthLogin(String provider) async {
    setState(() { _oauthLoading = true; _showWakeUpHint = false; });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _oauthLoading) setState(() => _showWakeUpHint = true);
    });

    try {
      final authUrl = '$_backendUrl/oauth2/authorization/$provider';
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: _callbackScheme,
      );

      if (!mounted) return;
      setState(() => _showWakeUpHint = false);

      final uri = Uri.parse(result);
      final errorParam = uri.queryParameters['error'];
      if (errorParam != null && errorParam.isNotEmpty) {
        throw Exception('OAuth error: $errorParam');
      }

      final accessToken = uri.queryParameters['accessToken'];
      final refreshToken = uri.queryParameters['refreshToken'];

      if (accessToken == null || accessToken.isEmpty ||
          refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No tokens received from OAuth2 flow');
      }

      final profileId = int.tryParse(uri.queryParameters['profileId'] ?? '');
      final appUserId  = int.tryParse(uri.queryParameters['appUserId'] ?? '');
      // Backend now sends the provider display name (Google name / GitHub login)
      // so we can pre-fill the name field on the profile-completion screen.
      final oauthName  = uri.queryParameters['oauthName'];

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ok = await auth.loginWithOAuthTokens(
        accessToken, refreshToken,
        profileId: profileId,
        appUserId: appUserId,
        oauthName: oauthName?.isNotEmpty == true ? oauthName : null,
      );

      if (!mounted) return;

      if (ok) {
        // New OAuth user — needs to fill in phone/location/experience
        if (auth.needsProfileCompletion) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OAuthCompleteProfileScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(auth.error ?? 'OAuth login failed'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _showWakeUpHint = false);
      final msg = e.toString().contains('CANCELED') || e.toString().contains('canceled')
          ? 'Sign-in cancelled'
          : e.toString().contains('OAuth error')
              ? e.toString().replaceAll('Exception: OAuth error: ', '')
              : 'OAuth login failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.rose,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() { _oauthLoading = false; _showWakeUpHint = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = auth.isLoading || _oauthLoading;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
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
                      fontSize: 42, height: 1.05, letterSpacing: -2, color: AppTheme.text)),
                    const SizedBox(height: 8),
                    const Text('Sign in to continue your journey', style: TextStyle(
                      fontFamily: 'SpaceGrotesk', fontSize: 15, color: AppTheme.textMuted)),
                    const SizedBox(height: 40),

                    if (_showWakeUpHint) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.teal.withOpacity(0.3), width: 1),
                        ),
                        child: const Row(children: [
                          SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.teal)),
                          SizedBox(width: 10),
                          Expanded(child: Text(
                            'Server is waking up… this may take ~30 seconds on first use.',
                            style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, color: AppTheme.teal),
                          )),
                        ]),
                      ),
                    ],

                    Form(key: _formKey, child: Column(children: [
                      BrutalTextField(
                        label: 'Username', controller: _usernameCtrl,
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (v) => v!.isEmpty ? 'Enter username' : null),
                      const SizedBox(height: 16),
                      BrutalTextField(
                        label: 'Password', controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter password' : null),
                      const SizedBox(height: 28),
                      BrutalButton(
                        label: 'SIGN IN', onPressed: busy ? null : _login,
                        isLoading: auth.isLoading, width: double.infinity),
                      const SizedBox(height: 20),

                      const Row(children: [
                        Expanded(child: Divider(color: AppTheme.bgMuted)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or continue with', style: TextStyle(
                            fontFamily: 'SpaceGrotesk', fontSize: 13, color: AppTheme.textFaint))),
                        Expanded(child: Divider(color: AppTheme.bgMuted)),
                      ]),
                      const SizedBox(height: 20),

                      _OAuthButton(
                        label: 'Continue with Google',
                        icon: _GoogleIcon(),
                        loading: _oauthLoading,
                        onTap: busy ? null : () => _oauthLogin('google'),
                      ),
                      const SizedBox(height: 12),
                      _OAuthButton(
                        label: 'Continue with GitHub',
                        icon: const Icon(Icons.code_rounded, size: 20, color: Colors.white),
                        loading: _oauthLoading,
                        onTap: busy ? null : () => _oauthLogin('github'),
                      ),
                      const SizedBox(height: 36),

                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text("Don't have an account? ", style: TextStyle(
                          fontFamily: 'SpaceGrotesk', fontSize: 14, color: AppTheme.textMuted)),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SignupScreen())),
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
  final Widget icon;
  final VoidCallback? onTap;
  final bool loading;
  const _OAuthButton({required this.label, required this.icon, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onTap == null ? 0.5 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.bgMuted, width: 1),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 20, height: 20, child: icon),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
                  fontSize: 14, color: AppTheme.text)),
              ]),
      ),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 20,
    decoration: BoxDecoration(
      color: const Color(0xFF4285F4),
      borderRadius: BorderRadius.circular(4)),
    child: const Center(child: Text('G',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
  );
}