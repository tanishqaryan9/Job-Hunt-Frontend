import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class ApiService {

  // Production backend (Render.com – has cold-start delays up to ~30s)
  static const String _prodUrl = 'https://job-posting-u2lr.onrender.com';

  static const _storage = FlutterSecureStorage();

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _prodUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
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
        if (e.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            e.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(e.requestOptions);
            handler.resolve(response);
            return;
          }
        }
        handler.next(e);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post('/auth/refresh',
          data: {'refreshToken': refreshToken});
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
      await _storage.write(key: 'app_user_id', value: auth.appUserId.toString());
    }
  }

  /// Saves tokens obtained externally (e.g. via OAuth2 redirect) without a POST call.
  Future<void> saveTokensDirectly(AuthResponse auth) => _saveTokens(auth);

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

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

  /// Backend /auth/signup returns SignupResponseDto (no tokens).
  /// We automatically log the user in after successful signup so the
  /// Flutter app receives tokens and the session starts immediately.
  Future<AuthResponse> signup(SignupRequest req) async {
    // 1. Register the account
    await _dio.post('/auth/signup', data: req.toJson());
    // 2. Log in with the same credentials to obtain tokens
    final auth = await login(LoginRequest(
      username: req.username,
      password: req.password,
    ));
    return auth;
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
    await clearTokens();
  }

  // ── USERS ─────────────────────────────────────────────
  Future<PageResponse<UserProfile>> getUsers({int page = 0, int size = 10}) async {
    final res = await _dio.get('/users', queryParameters: {'page': page, 'size': size});
    final data = res.data;
    return PageResponse<UserProfile>(
      content: (data['content'] as List).map((j) => UserProfile.fromJson(j)).toList(),
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

  Future<UserProfile> updateUser(int id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/users/$id', data: updates);
    return UserProfile.fromJson(res.data);
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
    final res = await _dio.patch('/users/$userId', data: formData,
        options: Options(contentType: 'multipart/form-data'));
    return UserProfile.fromJson(res.data);
  }

  // ── JOB SKILLS ────────────────────────────────────────
  Future<Job> addSkillToJob(int jobId, int skillId) async {
    final res = await _dio.post('/jobs/$jobId/skills/$skillId');
    return Job.fromJson(res.data);
  }

  Future<void> removeSkillFromJob(int jobId, int skillId) async {
    await _dio.delete('/jobs/$jobId/skills/$skillId');
  }

  // ── JOBS ──────────────────────────────────────────────
  Future<PageResponse<Job>> getJobs({int page = 0, int size = 10}) async {
    final res = await _dio.get('/jobs', queryParameters: {'page': page, 'size': size});
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

  Future<Job> createJob(Map<String, dynamic> job) async {
    // Remap Flutter camelCase keys to the backend snake_case field names that
    // AddJobRequestDto expects, and inject the mandatory createdByUserId.
    final payload = Map<String, dynamic>.from(job);

    // jobType → job_type  (backend field is snake_case)
    if (payload.containsKey('jobType') && !payload.containsKey('job_type')) {
      payload['job_type'] = payload.remove('jobType');
    }

    // Inject the logged-in user's profile ID if not already supplied.
    // The backend requires @NotNull createdByUserId — omitting it causes a
    // 400 "Validation failed: {createdByUserId=User ID cannot be null}" error.
    if (!payload.containsKey('createdByUserId') || payload['createdByUserId'] == null) {
      final profileId = await getProfileId();
      if (profileId != null) {
        payload['createdByUserId'] = profileId;
      }
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

  // ── APPLICATIONS ──────────────────────────────────────
  Future<List<JobApplication>> getApplications({int page = 0, int size = 20}) async {
    final res = await _dio.get('/application', queryParameters: {'page': page, 'size': size});
    final data = res.data;
    final content = data['content'] ?? data;
    return (content as List).map((j) => JobApplication.fromJson(j)).toList();
  }

  Future<JobApplication> createApplication(int jobId, int userId, {String? coverLetter}) async {
    final res = await _dio.post('/application', data: {
      'jobId': jobId,
      'userId': userId,
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
    final res = await _dio.get('/feed/$userId/nearest', queryParameters: {'k': k});
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getJobsBySalary(double min, double max) async {
    final res = await _dio.get('/feed/salary', queryParameters: {'min': min, 'max': max});
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getSkillMatchJobs(int userId) async {
    final res = await _dio.get('/feed/$userId/skill-match');
    return (res.data as List).map((j) => Job.fromJson(j)).toList();
  }

  Future<List<Job>> getCombinedFeed(int userId, {double maxDistanceKm = 50, int page = 0, int size = 10}) async {
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