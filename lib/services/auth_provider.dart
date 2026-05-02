import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _currentUser;
  int? _currentUserId;
  int? _appUserId;
  String? _username;
  String? _error;
  bool _isLoading = false;
  String? _oauthName;

  AuthStatus get status => _status;
  UserProfile? get currentUser => _currentUser;
  int? get currentUserId => _currentUserId;
  int? get appUserId => _appUserId;
  String? get username => _username;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get oauthName => _oauthName;

  /// Called by OAuthCompleteProfileScreen after POST /users/oauth-profile succeeds.
  /// Persists the new profile_id to secure storage so session restore works.
  Future<void> markProfileCompleted(UserProfile profile) async {
    _currentUser   = profile;
    _currentUserId = profile.id;
    await apiService.persistProfileId(profile.id);
    notifyListeners();
  }

  bool get needsProfileCompletion =>
      _status == AuthStatus.authenticated && _currentUserId == null;

  UserProfile? get userProfile => _currentUser;

  /// Restores a previous session from secure storage on app launch.
  ///
  /// Three cases are handled:
  ///   1. Full session (token + profile_id) → authenticated, load profile.
  ///   2. Partial OAuth session (token + app_user_id, no profile_id) → authenticated
  ///      but [needsProfileCompletion] is true.  The [_RootRouter] will route
  ///      to [OAuthCompleteProfileScreen] so the user can finish registration.
  ///      We must NOT clear the tokens here — doing so wipes the app_user_id
  ///      and causes "No app user ID — please log in again" on Save.
  ///   3. Token only (no profile_id, no app_user_id) → truly broken session,
  ///      clear tokens and send back to login.
  Future<void> tryRestoreSession() async {
    _isLoading = true;
    notifyListeners();

    final token = await apiService.getAccessToken();
    if (token != null) {
      final profileId = await apiService.getProfileId();
      final appUserId = await apiService.getAppUserId();

      if (profileId != null) {
        // Case 1 — happy path: full session is intact.
        _currentUserId = profileId;
        _appUserId = appUserId;
        _username = await apiService.getUsername();
        _status = AuthStatus.authenticated;
        _registerFcmToken(profileId);
        // Eagerly load the full UserProfile in the background.
        try {
          _currentUser = await apiService.getUserById(profileId);
        } catch (_) {
          // Non-fatal: screens will reload the profile independently if needed.
        }
      } else if (appUserId != null) {
        // Case 2 — OAuth user who was killed before completing their profile.
        // Keep the tokens so OAuthCompleteProfileScreen can call the backend.
        _appUserId = appUserId;
        _status = AuthStatus.authenticated;
        // _currentUserId stays null → needsProfileCompletion == true.
      } else {
        // Case 3 — token exists but neither profile_id nor app_user_id is
        // stored.  This is a genuinely broken session (e.g. old app version).
        await apiService.clearTokens();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final token = await apiService.getAccessToken();
    if (token != null) {
      _status = AuthStatus.authenticated;
      _currentUserId = await apiService.getProfileId();
      _appUserId = await apiService.getAppUserId();
      _username = await apiService.getUsername();
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = await apiService
          .login(LoginRequest(username: username, password: password));
      _applyAuthResponse(auth);
      if (_currentUserId != null) {
        try {
          _currentUser = await apiService.getUserById(_currentUserId!);
        } catch (_) {}
        _registerFcmToken(_currentUserId!);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e, isLogin: true);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(SignupRequest req) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = await apiService.signup(req);
      _applyAuthResponse(auth);
      if (_currentUserId != null) {
        try {
          _currentUser = await apiService.getUserById(_currentUserId!);
        } catch (_) {}
        _registerFcmToken(_currentUserId!);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e, isLogin: false);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithOAuthTokens(
    String accessToken,
    String refreshToken, {
    int? profileId,
    int? appUserId,
    String? oauthName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = AuthResponse.fromTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        profileId: profileId,
        appUserId: appUserId,
        oauthName: oauthName,
      );
      await apiService.saveTokensDirectly(auth);
      _applyAuthResponse(auth);
      if (_currentUserId == null) {
        await _fetchAndSetUserId();
      }
      
      if (_currentUserId != null) {
        try {
          _currentUser = await apiService.getUserById(_currentUserId!);
        } catch (_) {}
        _registerFcmToken(_currentUserId!);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'OAuth login failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetchAndSetUserId() async {
    try {
      final profileId = await apiService.getProfileId();
      if (profileId != null) {
        _currentUserId = profileId;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await apiService.logout();
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _currentUserId = null;
    _appUserId = null;
    _username = null;
    _oauthName = null;
    _isLoading = false;
    notifyListeners();
  }

  /// FIX: Force logout — clears tokens and resets state without calling the
  /// backend. Used when a 401 is received on a protected endpoint after a
  /// failed token refresh, so the user is sent back to the login screen
  /// immediately rather than seeing a raw error.
  Future<void> forceLogout() async {
    await apiService.clearTokens();
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _currentUserId = null;
    _appUserId = null;
    _oauthName = null;
    notifyListeners();
  }

  void setCurrentUser(UserProfile user) {
    _currentUser = user;
    _currentUserId = user.id;
    notifyListeners();
  }

  Future<void> refreshUserProfile() async {
    try {
      final profile = await apiService.getCurrentUser();
      _currentUser = profile;
      _currentUserId = profile.id;
      notifyListeners();
    } catch (_) {
      if (_currentUserId != null) {
        try {
          final profile = await apiService.getUserById(_currentUserId!);
          _currentUser = profile;
          notifyListeners();
        } catch (__) {}
      }
    }
  }

  void _applyAuthResponse(AuthResponse auth) {
    _status = AuthStatus.authenticated;
    _appUserId = auth.appUserId;
    _currentUserId = auth.profileId;
    _username = auth.username;
    _oauthName = auth.oauthName;
  }

  void _registerFcmToken(int userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) {
        await apiService.registerFcmToken(userId, token);
      }
      messaging.onTokenRefresh.listen((newToken) {
        apiService.registerFcmToken(userId, newToken);
      });
    } catch (_) {
      // FCM failure must never crash auth
    }
  }

  String _parseError(dynamic e, {bool isLogin = true}) {
    final s = e.toString();

    try {
      final dynamic response = (e as dynamic).response?.data;
      final int? statusCode = (e as dynamic).response?.statusCode;

      if (response != null) {
        // Backend APIError DTO uses 'error' key, not 'message'. Check both.
        final msg = response['error']?.toString() ??
            response['message']?.toString() ??
            response['detail']?.toString();

        if (msg != null && msg.isNotEmpty) {
          if (msg.contains('Validation failed') || msg.contains('validation')) {
            final match = RegExp(r'\{(.+?)\}').firstMatch(msg);
            if (match != null) {
              final inner = match.group(1) ?? '';
              final fieldMsg = inner.split('=').last.trim();
              return fieldMsg.isNotEmpty
                  ? fieldMsg
                  : 'Please check your inputs and try again.';
            }
            return 'Please check your inputs and try again.';
          }

          if (msg.toLowerCase().contains('already exists') ||
              msg.toLowerCase().contains('already taken')) {
            return 'That username is already taken. Try a different one.';
          }

          if (statusCode == 404 ||
              msg.toLowerCase().contains('not found') ||
              msg.toLowerCase().contains('no user') ||
              msg.toLowerCase().contains('user not found')) {
            return isLogin
                ? 'Account not found. Check your username or sign up.'
                : 'Could not find your account. Please try again.';
          }

          if (statusCode == 401 ||
              msg.toLowerCase().contains('bad credentials') ||
              msg.toLowerCase().contains('invalid credentials') ||
              msg.toLowerCase().contains('unauthorized')) {
            return 'Incorrect username or password. Please try again.';
          }

          return msg;
        }

        if (statusCode == 404) {
          return isLogin
              ? 'Account not found. Check your username or sign up.'
              : 'Registration failed — please try a different username.';
        }
        if (statusCode == 401) return 'Incorrect username or password.';
        if (statusCode == 409) return 'That username is already taken.';
        if (statusCode == 400) return 'Please check your inputs and try again.';
        if (statusCode == 500) {
          return 'Server error — please try again shortly.';
        }
      }
    } catch (_) {}

    if (s.contains('404')) {
      return isLogin
          ? 'Account not found. Check your username or sign up.'
          : 'Registration failed — user not found after signup.';
    }
    if (s.contains('401')) return 'Incorrect username or password.';
    if (s.contains('409')) return 'That username is already taken.';
    if (s.contains('400')) return 'Please check your inputs and try again.';
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable')) {
      return 'Cannot connect to server. Check your internet connection.';
    }
    if (s.contains('timeout') ||
        s.contains('TimeoutException') ||
        s.contains('DioException')) {
      return 'Server is waking up — please wait a moment and try again.\n'
          '(Free servers sleep after inactivity)';
    }
    return 'Something went wrong. Please try again.';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}