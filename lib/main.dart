import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

// Firebase imports — only used if google-services.json is present
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try { await Firebase.initializeApp(); } catch (_) {}
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

bool _firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe Firebase init — won't crash if google-services.json is missing
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'job_posting_channel',
            'Job Alerts',
            channelDescription: 'Notifications for job application updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });
  } catch (e) {
    // google-services.json not yet added — app runs without push notifications
    debugPrint('Firebase not initialized: $e');
  }

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
  bool _initialized = false;

  void _onSplashComplete() {
    context.read<AuthProvider>().tryRestoreSession().then((_) {
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    final auth = context.watch<AuthProvider>();

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

    return auth.isAuthenticated ? const MainShell() : const LoginScreen();
  }
}