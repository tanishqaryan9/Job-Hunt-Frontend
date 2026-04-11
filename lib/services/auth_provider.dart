import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _currentUser;
  int? _currentUserId;
  int? _appUserId;
  String? _error;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserProfile? get currentUser => _currentUser;
  int? get currentUserId => _currentUserId;
  int? get appUserId => _appUserId;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> tryRestoreSession() async {
    _isLoading = true;
    notifyListeners();
    final token = await apiService.getAccessToken();
    if (token != null) {
      _currentUserId = await apiService.getProfileId();
      _appUserId = await apiService.getAppUserId();
      _status = AuthStatus.authenticated;
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
      final auth = await apiService.login(
          LoginRequest(username: username, password: password));
      _applyAuthResponse(auth);
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
      );
      await apiService.saveTokensDirectly(auth);
      _applyAuthResponse(auth);
      if (_currentUserId == null) {
        await _fetchAndSetUserId();
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
    _isLoading = false;
    notifyListeners();
  }

  void setCurrentUser(UserProfile user) {
    _currentUser = user;
    _currentUserId = user.id;
    notifyListeners();
  }

  void _applyAuthResponse(AuthResponse auth) {
    _status = AuthStatus.authenticated;
    _appUserId = auth.appUserId;
    _currentUserId = auth.profileId;
  }

  /// Converts Dio/HTTP errors into human-readable messages.
  /// [isLogin] = true for login, false for signup — changes 404/400 wording.
  String _parseError(dynamic e, {bool isLogin = true}) {
    final s = e.toString();

    // ── Try to read the backend JSON error body first ──────────────
    try {
      final dynamic response = (e as dynamic).response?.data;
      final int? statusCode = (e as dynamic).response?.statusCode;

      if (response != null) {
        final msg = response['message']?.toString()
            ?? response['error']?.toString()
            ?? response['detail']?.toString();

        if (msg != null && msg.isNotEmpty) {
          // Validation failed (Spring @Valid errors)
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

          // Already-taken username
          if (msg.toLowerCase().contains('already exists') ||
              msg.toLowerCase().contains('already taken')) {
            return 'That username is already taken. Try a different one.';
          }

          // User not found (404 from backend)
          if (statusCode == 404 ||
              msg.toLowerCase().contains('not found') ||
              msg.toLowerCase().contains('no user') ||
              msg.toLowerCase().contains('user not found')) {
            return isLogin
                ? 'Account not found. Check your username or sign up.'
                : 'Could not find your account. Please try again.';
          }

          // Bad credentials
          if (statusCode == 401 ||
              msg.toLowerCase().contains('bad credentials') ||
              msg.toLowerCase().contains('invalid credentials') ||
              msg.toLowerCase().contains('unauthorized')) {
            return 'Incorrect username or password. Please try again.';
          }

          return msg;
        }

        // No message field — use status code alone
        if (statusCode == 404) {
          return isLogin
              ? 'Account not found. Check your username or sign up.'
              : 'Registration failed — please try a different username.';
        }
        if (statusCode == 401) return 'Incorrect username or password.';
        if (statusCode == 409) return 'That username is already taken.';
        if (statusCode == 400) return 'Please check your inputs and try again.';
        if (statusCode == 500) return 'Server error — please try again shortly.';
      }
    } catch (_) {}

    // ── Fallback: inspect the stringified exception ────────────────
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