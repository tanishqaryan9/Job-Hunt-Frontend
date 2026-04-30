import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String _prodUrl = 'https://job-posting-u2lr.onrender.com';
  static const _storage = FlutterSecureStorage();

  // FIX: saved-jobs backed by SharedPreferences — survives app restarts
  final Map<int, Job> _savedJobsMap = {};
  bool _savedJobsLoaded = false;

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _prodUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        final statusCode = e.response?.statusCode;

        // ── 403 Forbidden — unverified account ────────────────────────────────
        // Backend throws AccessDeniedException → 403 when an unverified user
        // tries to apply for a job. We re-throw with a structured error so the
        // UI can detect it and show the verification flow instead of a generic
        // error dialog.
        if (statusCode == 403) {
          final message = e.response?.data?['message'] as String? ?? '';
          final isVerificationError = message.toLowerCase().contains('verify') ||
              message.toLowerCase().contains('verified');
          if (isVerificationError) {
            handler.next(DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: DioExceptionType.badResponse,
              error: 'ACCOUNT_NOT_VERIFIED',
            ));
            return;
          }
        }

        // ── 401 Unauthorized — attempt token refresh ───────────────────────────
        if (statusCode == 401) {
          // Only attempt refresh for authenticated API calls, not for
          // auth endpoints themselves (login/refresh) — those 401s are
          // legitimate and should not trigger an infinite retry loop.
          final path = e.requestOptions.path;
          // OTP paths are public but we still exclude them from the refresh-and-retry
          // loop — if they fail with 401, it means the backend rejected an expired token
          // on a public endpoint (handled by the JWTAuthFilter fix). Retrying with a fresh
          // token is correct here, but since the backend fix makes the endpoint token-optional,
          // we still exclude /auth/otp from the retry to avoid an infinite loop if the
          // backend is on an older version.
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/signup') ||
              path.contains('/auth/otp/');

          if (!isAuthEndpoint) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final token = await _storage.read(key: 'access_token');
              e.requestOptions.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(e.requestOptions);
                handler.resolve(response);
                return;
              } catch (retryError) {
                handler.next(e);
                return;
              }
            }
            // Refresh failed — clear stale tokens so the app re-routes to login.
            await clearTokens();
          }
        }

        handler.next(e);
      },
    ));

    // Pre-load saved jobs from disk so isJobSaved() is accurate immediately
    _loadSavedJobsFromPrefs();
  }

  // ── Saved jobs persistence ────────────────────────────────────
  static const _savedJobsPrefKey = 'saved_jobs_v1';

  Future<void> _loadSavedJobsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedJobsPrefKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        for (final item in decoded) {
          final job = Job.fromJson(item as Map<String, dynamic>);
          _savedJobsMap[job.id] = job;
        }
      }
    } catch (_) {}
    _savedJobsLoaded = true;
  }

  Future<void> _persistSavedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _savedJobsMap.values
          .map((j) => <String, dynamic>{
                'id': j.id,
                'title': j.title,
                'description': j.description,
                'location': j.location,
                'salary': j.salary,
                'salaryPeriod': j.salaryPeriod,
                'jobType': j.jobType,
                'createdByName': j.createdByName,
                'createdById': j.createdById,
                'latitude': j.latitude,
                'longitude': j.longitude,
                'createdAt': j.createdAt,
                'skills': j.skills.map((s) => s.toJson()).toList(),
              })
          .toList();
      await prefs.setString(_savedJobsPrefKey, jsonEncode(list));
    } catch (_) {}
  }

  bool isJobSaved(int jobId) => _savedJobsMap.containsKey(jobId);

  void saveJob(Job job) {
    _savedJobsMap[job.id] = job;
    _persistSavedJobs();
  }

  void unsaveJob(int jobId) {
    _savedJobsMap.remove(jobId);
    _persistSavedJobs();
  }

  void toggleSaveJob(Job job) {
    if (isJobSaved(job.id)) {
      unsaveJob(job.id);
    } else {
      saveJob(job);
    }
  }

  List<Job> getSavedJobs() => List.unmodifiable(_savedJobsMap.values.toList());

  // ── Token helpers ─────────────────────────────────────────────
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      final response = await _dio
          .post('/auth/refresh', data: {'refreshToken': refreshToken});
      final auth = AuthResponse.fromJson(response.data);
      await _saveTokens(auth);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveTokens(AuthResponse auth) async {
    await _storage.write(key: 'access_token', value: auth.accessToken);
    await _storage.write(key: 'refresh_token', value: auth.refreshToken);
    if (auth.profileId != null) {
      await _storage.write(key: 'profile_id', value: auth.profileId.toString());
    }
    if (auth.appUserId != null) {
      await _storage.write(
          key: 'app_user_id', value: auth.appUserId.toString());
    }
    if (auth.username != null) {
      await _storage.write(key: 'username', value: auth.username!);
    }
  }

  Future<void> saveTokensDirectly(AuthResponse auth) => _saveTokens(auth);
  Future<void> clearTokens() async => await _storage.deleteAll();
  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');
  Future<String?> getUsername() => _storage.read(key: 'username');

  Future<void> persistProfileId(int profileId) async {
    await _storage.write(key: 'profile_id', value: profileId.toString());
  }

  Future<int?> getProfileId() async {
    final val = await _storage.read(key: 'profile_id');
    return val != null ? int.tryParse(val) : null;
  }

  Future<int?> getAppUserId() async {
    final val = await _storage.read(key: 'app_user_id');
    return val != null ? int.tryParse(val) : null;
  }

  // ── AUTH ──────────────────────────────────────────────
  Future<AuthResponse> login(LoginRequest req) async {
    final res = await _dio.post('/auth/login', data: req.toJson());
    final auth = AuthResponse.fromJson(res.data);
    await _saveTokens(auth);
    return auth;
  }

  Future<AuthResponse> signup(SignupRequest req) async {
    await _dio.post('/auth/signup', data: req.toJson());
    final auth = await login(
        LoginRequest(username: req.username, password: req.password));
    return auth;
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
    await clearTokens();
  }

  /// Extracts the human-readable error message from an API error response.
  /// The backend's APIError DTO serialises the message under the key "error",
  /// not "message". This helper checks both keys so callers get a useful string.
  static String extractApiError(DioException e, {String fallback = 'Something went wrong'}) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['error']?.toString() ??
                  data['message']?.toString() ??
                  data['detail']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    // Dio's own message as last resort (e.g. "Http status error [500]")
    return e.message ?? fallback;
  }

  Future<void> sendOtp({required String type, required String value, String? username}) async {
    final data = <String, dynamic>{'type': type, 'value': value};
    if (username != null && username.isNotEmpty) {
      data['username'] = username;
    }
    // Use a shorter timeout for OTP — the free Render server can be slow to wake,
    // but 60 s feels completely broken to users staring at a spinner.
    // 20 s is long enough for a cold start while still giving quick feedback.
    await _dio.post('/auth/otp/send', data: data);
  }

  Future<void> verifyOtp({
    required String type,
    required String value,
    required String otp,
    String? username,
  }) async {
    final data = <String, dynamic>{
      'type': type,
      'value': value,
      'otp': otp,
    };
    if (username != null && username.isNotEmpty) {
      data['username'] = username;
    }
    await _dio.post('/auth/otp/verify', data: data);
  }

  // ── USERS ─────────────────────────────────────────────
  Future<PageResponse<UserProfile>> getUsers(
      {int page = 0, int size = 10}) async {
    final res =
        await _dio.get('/users', queryParameters: {'page': page, 'size': size});
    final data = res.data;
    return PageResponse<UserProfile>(
      content: (data['content'] as List)
          .map((j) => UserProfile.fromJson(j))
          .toList(),
      page: data['number'] ?? 0,
      size: data['size'] ?? size,
      totalElements: data['totalElements'] ?? 0,
      totalPages: data['totalPages'] ?? 0,
    );
  }

  Future<UserProfile> getUserById(int id) async {
    final res = await _dio.get('/users/$id');
    return UserProfile.fromJson(res.data);
  }

  Future<UserProfile> getCurrentUser() async {
    final res = await _dio.get('/users/me');
    return UserProfile.fromJson(res.data);
  }


  Future<UserProfile> updateUser(int id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/users/$id', data: updates);
    return UserProfile.fromJson(res.data);
  }

  /// POST /users/oauth-profile/{appUserId}
  Future<UserProfile> createOAuthProfile(int appUserId, Map<String, dynamic> profileData) async {
    final res = await _dio.post('/users/oauth-profile/$appUserId', data: profileData);
    return UserProfile.fromJson(res.data);
  }

  Future<UserProfile> updateUserLocation(
      int userId, double latitude, double longitude) async {
    final res = await _dio.patch('/users/$userId', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
    return UserProfile.fromJson(res.data);
  }

  Future<void> registerFcmToken(int userId, String fcmToken) async {
    try {
      await _dio.patch('/users/$userId', data: {'fcmToken': fcmToken});
    } catch (_) {}
  }

  Future<UserProfile> addSkillToUser(int userId, int skillId) async {
    final res = await _dio.post('/users/$userId/skills/$skillId');
    return UserProfile.fromJson(res.data);
  }

  Future<void> removeSkillFromUser(int userId, int skillId) async {
    await _dio.delete('/users/$userId/skills/$skillId');
  }

  Future<List<Skill>> getUserSkills(int userId) async {
    final res = await _dio.get('/users/$userId/skills');
    return (res.data as List).map((s) => Skill.fromJson(s)).toList();
  }

  // ── PROFILE PHOTO ─────────────────────────────────────
  Future<UserProfile> uploadProfilePhoto(int userId, File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path,
          filename: 'profile_$userId.jpg'),
    });
    final res = await _dio.patch('/users/$userId',
        data: formData, options: Options(contentType: 'multipart/form-data'));
    return UserProfile.fromJson(res.data);
  }

  // ── JOBS ──────────────────────────────────────────────
  Future<PageResponse<Job>> getJobs({int page = 0, int size = 10}) async {
    final res =
        await _dio.get('/jobs', queryParameters: {'page': page, 'size': size});
    final data = res.data;
    return PageResponse<Job>(
      content: (data['content'] as List).map((j) => Job.fromJson(j)).toList(),
      page: data['number'] ?? 0,
      size: data['size'] ?? size,
      totalElements: data['totalElements'] ?? 0,
      totalPages: data['totalPages'] ?? 0,
    );
  }

  Future<Job> getJobById(int id) async {
    final res = await _dio.get('/jobs/$id');
    return Job.fromJson(res.data);
  }

  Future<List<Job>> getMyJobs(int userId) async {
    final res = await _dio.get('/jobs/created-by/$userId');
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<Job> createJob(Map<String, dynamic> job) async {
    final payload = Map<String, dynamic>.from(job);
    if (payload.containsKey('jobType') && !payload.containsKey('job_type')) {
      payload['job_type'] = payload.remove('jobType');
    }
    if (!payload.containsKey('createdByUserId') ||
        payload['createdByUserId'] == null) {
      final profileId = await getProfileId();
      if (profileId != null) payload['createdByUserId'] = profileId;
    }
    final res = await _dio.post('/jobs', data: payload);
    return Job.fromJson(res.data);
  }

  Future<Job> updateJob(int id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/jobs/$id', data: updates);
    return Job.fromJson(res.data);
  }

  Future<void> deleteJob(int id) async {
    await _dio.delete('/jobs/$id');
  }

  // ── JOB SKILLS ────────────────────────────────────────
  Future<Job> addSkillToJob(int jobId, int skillId) async {
    final res = await _dio.post('/jobs/$jobId/skills/$skillId');
    return Job.fromJson(res.data);
  }

  Future<void> removeSkillFromJob(int jobId, int skillId) async {
    await _dio.delete('/jobs/$jobId/skills/$skillId');
  }

  // ── APPLICATIONS ──────────────────────────────────────
  Future<List<JobApplication>> getApplications(
      {int page = 0, int size = 20}) async {
    final res = await _dio
        .get('/application', queryParameters: {'page': page, 'size': size});
    final data = res.data;
    final content = data['content'] ?? data;
    return (content as List).map((j) => JobApplication.fromJson(j)).toList();
  }

  Future<List<JobApplication>> getMyApplications(int userId) async {
    final res = await _dio.get('/application/by-user/$userId');
    final list =
        (res.data as List).map((j) => JobApplication.fromJson(j)).toList();
    final seen = <int>{};
    return list.where((a) => seen.add(a.id)).toList();
  }

  Future<List<JobApplication>> getApplicationsByJob(int jobId) async {
    final res = await _dio.get('/application/by-job/$jobId');
    return (res.data as List).map((j) => JobApplication.fromJson(j)).toList();
  }

  Future<JobApplication> createApplication(int jobId, int userId,
      {String? coverLetter}) async {
    final res = await _dio.post('/application', data: {
      'jobId': jobId,
      if (coverLetter != null) 'coverLetter': coverLetter,
    });
    return JobApplication.fromJson(res.data);
  }

  Future<JobApplication> updateApplicationStatus(int id, String status) async {
    final res = await _dio.patch('/application/$id', data: {'status': status});
    return JobApplication.fromJson(res.data);
  }

  Future<void> deleteApplication(int id) async {
    await _dio.delete('/application/$id');
  }

  // ── FEED ──────────────────────────────────────────────
  Future<List<Job>> getNearestJobs(int userId, {int k = 10}) async {
    final res =
        await _dio.get('/feed/$userId/nearest', queryParameters: {'k': k});
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getJobsBySalary(double min, double max,
      {int? userId}) async {
    final params = <String, dynamic>{'min': min, 'max': max};
    if (userId != null) params['userId'] = userId;
    final res = await _dio.get('/feed/salary', queryParameters: params);
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getSkillMatchJobs(int userId) async {
    final res = await _dio.get('/feed/$userId/skill-match');
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getCombinedFeed(int userId,
      {double maxDistanceKm = 50, int page = 0, int size = 10}) async {
    final res = await _dio.get('/feed/$userId', queryParameters: {
      'maxDistanceKm': maxDistanceKm,
      'page': page,
      'size': size,
    });
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getRelatedJobs(int jobId) async {
    final res = await _dio.get('/feed/jobs/$jobId/related');
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  // ── NOTIFICATIONS ─────────────────────────────────────
  Future<List<AppNotification>> getNotifications(int userId) async {
    final res = await _dio.get('/notifications/$userId');
    return (res.data as List).map((n) => AppNotification.fromJson(n)).toList();
  }

  Future<List<AppNotification>> getUnreadNotifications(int userId) async {
    final res = await _dio.get('/notifications/$userId/unread');
    return (res.data as List).map((n) => AppNotification.fromJson(n)).toList();
  }

  Future<int> getUnreadCount(int userId) async {
    final res = await _dio.get('/notifications/$userId/count');
    return res.data ?? 0;
  }

  Future<AppNotification> markNotificationRead(int id) async {
    final res = await _dio.patch('/notifications/$id/read');
    return AppNotification.fromJson(res.data);
  }

  Future<void> markAllRead(int userId) async {
    await _dio.patch('/notifications/$userId/read-all');
  }

  Future<void> deleteNotification(int id) async {
    await _dio.delete('/notifications/$id');
  }

  // ── SKILLS ────────────────────────────────────────────
  Future<List<Skill>> getAllSkills() async {
    final res = await _dio.get('/skills');
    return (res.data as List).map((s) => Skill.fromJson(s)).toList();
  }

  Future<Skill> createSkill(String name) async {
    final res = await _dio.post('/skills', data: {'name': name});
    return Skill.fromJson(res.data);
  }
}

final apiService = ApiService();