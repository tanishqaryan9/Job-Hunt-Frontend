import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const PostingApp(),
    ),
  );
}

class PostingApp extends StatelessWidget {
  const PostingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  // Starts false — splash shows first.
  // Flips to true only AFTER tryRestoreSession() fully completes.
  bool _initialized = false;

  // Called by SplashScreen when its animation finishes.
  // Async work is done here in the State so we fully control
  // when setState fires — avoids the VoidCallback async race condition.
  void _onSplashComplete() {
    context.read<AuthProvider>().tryRestoreSession().then((_) {
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Step 1 — show splash until session restore finishes
    if (!_initialized) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    final auth = context.watch<AuthProvider>();

    // Step 2 — safety spinner (should be nearly instant after step 1)
    if (auth.status == AuthStatus.unknown || auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0F1A),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Step 3 — route based on auth result
    return auth.isAuthenticated ? const MainShell() : const LoginScreen();
  }
}