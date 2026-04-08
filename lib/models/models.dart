// lib/models/models.dart

class LoginRequest {
  final String username;
  final String password;
  LoginRequest({required this.username, required this.password});
  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

class SignupRequest {
  final String username;
  final String password;
  final String name;
  final String number;
  final String location;
  final int experience;
  final double? latitude;
  final double? longitude;

  SignupRequest({
    required this.username,
    required this.password,
    required this.name,
    required this.number,
    required this.location,
    required this.experience,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'name': name,
        'number': number,
        'location': location,
        'experience': experience,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Returned by /auth/login and /auth/refresh.
/// Backend returns: { appUserId, profileId, accessToken, refreshToken }
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int? appUserId;
  final int? profileId; // This is the User (profile) ID used in /users/{id} endpoints

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.appUserId,
    this.profileId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['accessToken'] ?? json['access_token'] ?? '',
        refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
        appUserId: json['appUserId'] as int?,
        profileId: json['profileId'] as int?,
      );
}

class UserProfile {
  final int id;
  final String name;
  final String number;
  final String location;
  final int experience;
  final String? profilePhoto;
  final double? latitude;
  final double? longitude;
  final List<Skill> skills;

  UserProfile({
    required this.id,
    required this.name,
    required this.number,
    required this.location,
    required this.experience,
    this.profilePhoto,
    this.latitude,
    this.longitude,
    this.skills = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        number: json['number'] ?? '',
        location: json['location'] ?? '',
        experience: json['experience'] ?? 0,
        // Backend sends "profile_photo" (snake_case)
        profilePhoto: json['profile_photo'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        skills: (json['skills'] as List<dynamic>?)
                ?.map((s) => Skill.fromJson(s))
                .toList() ??
            [],
      );

  UserProfile copyWith({
    int? id,
    String? name,
    String? number,
    String? location,
    int? experience,
    String? profilePhoto,
    double? latitude,
    double? longitude,
    List<Skill>? skills,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        number: number ?? this.number,
        location: location ?? this.location,
        experience: experience ?? this.experience,
        profilePhoto: profilePhoto ?? this.profilePhoto,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        skills: skills ?? this.skills,
      );
}

class Skill {
  final int id;
  final String name;

  Skill({required this.id, required this.name});

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Job {
  final int id;
  final String title;
  final String description;
  final String location;
  final double salary;
  final String jobType;
  final String? createdByName;
  final double? latitude;
  final double? longitude;
  final List<Skill> skills;
  final String? createdAt;
  double? distanceKm;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.salary,
    required this.jobType,
    this.createdByName,
    this.latitude,
    this.longitude,
    this.skills = const [],
    this.createdAt,
    this.distanceKm,
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        location: json['location'] ?? '',
        salary: (json['salary'] ?? 0).toDouble(),
        // Backend sends "jobType" (via @JsonProperty) — fallback to legacy keys
        jobType: json['jobType'] ?? json['job_type'] ?? 'FULL_TIME',
        createdByName: json['createdBy']?['name'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        // Backend sends "skills" (via @JsonProperty on requiredSkills)
        skills: (json['skills'] as List<dynamic>?)
                ?.map((s) => Skill.fromJson(s))
                .toList() ??
            [],
        // Backend sends "createdAt" (via @JsonProperty) — fallback to snake_case
        createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
        distanceKm: json['distanceKm']?.toDouble(),
      );
}

class JobApplication {
  final int id;
  final int jobId;
  final String jobTitle;
  final String status;
  final String? coverLetter;
  final String? appliedAt;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.status,
    this.coverLetter,
    this.appliedAt,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
        id: json['id'] ?? 0,
        // Backend now sends flat "jobId" and "jobTitle" via @JsonProperty getters
        jobId: json['jobId'] ?? json['job']?['id'] ?? 0,
        jobTitle: json['jobTitle'] ?? json['job']?['title'] ?? 'Unknown Job',
        status: json['status'] ?? 'PENDING',
        coverLetter: json['coverLetter'],
        // Backend sends "appliedAt" (via @JsonProperty) — fallback to snake_case
        appliedAt: json['appliedAt']?.toString() ?? json['applied_at']?.toString(),
      );
}

class AppNotification {
  final int id;
  final String? title;
  final String? body;
  final bool isRead;
  final String? createdAt;

  AppNotification({
    required this.id,
    this.title,
    this.body,
    required this.isRead,
    this.createdAt,
  });

  /// Backward-compatible getter used throughout the UI.
  String get message => body ?? title ?? '';

  /// Convenience alias so legacy `.read` references still compile.
  bool get read => isRead;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] ?? 0,
        title: json['title']?.toString(),
        body: json['body']?.toString() ?? json['message']?.toString(),
        // Backend sends "isRead" (via @JsonProperty) — fallback to Lombok's "read"
        isRead: json['isRead'] as bool? ?? json['read'] as bool? ?? false,
        createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

class PageResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });
}
