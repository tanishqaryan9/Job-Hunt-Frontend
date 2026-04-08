import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _currentUser;
  int? _currentUserId;   // User-profile ID (User table) used in /users/{id} endpoints
  int? _appUserId;       // AppUser ID (login account), stored for reference
  String? _error;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserProfile? get currentUser => _currentUser;
  int? get currentUserId => _currentUserId;   // used everywhere: feed, notifications, profile
  int? get appUserId => _appUserId;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuthStatus() async {
    final token = await apiService.getAccessToken();
    if (token != null) {
      _status = AuthStatus.authenticated;
      // Restore stored profileId so screens work after app restart
      _currentUserId = await apiService.getProfileId();
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
      _error = _parseError(e);
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
      // api_service.signup() registers then immediately logs in, returning full AuthResponse
      final auth = await apiService.signup(req);
      _applyAuthResponse(auth);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
    _currentUserId = auth.profileId;  // profileId is the User table PK used across the API
  }

  String _parseError(dynamic e) {
    final s = e.toString();
    if (s.contains('401')) return 'Invalid credentials';
    if (s.contains('409')) return 'Username already exists';
    if (s.contains('SocketException')) return 'No internet connection';
    return 'Something went wrong. Please try again.';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
