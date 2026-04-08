import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posting/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const PostingApp());
}

class PostingApp extends StatelessWidget {
  const PostingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Posting — Job Board',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () async {
          // Check auth status after splash
          await context.read<AuthProvider>().checkAuthStatus();
          if (mounted) setState(() => _showSplash = false);
        },
      );
    }

    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              backgroundColor: AppTheme.white,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            );
          case AuthStatus.authenticated:
            return const MainShell();
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}
