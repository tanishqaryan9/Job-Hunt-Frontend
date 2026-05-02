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

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int? appUserId;
  final int? profileId;
  final String? username;
  final String? oauthName;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.appUserId,
    this.profileId,
    this.username,
    this.oauthName,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['accessToken'] ?? json['access_token'] ?? '',
        refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
        appUserId: json['appUserId'] as int?,
        profileId: json['profileId'] as int?,
        username: json['username'] as String?,
        oauthName: json['oauthName'] as String?,
      );

  factory AuthResponse.fromTokens({
    required String accessToken,
    required String refreshToken,
    int? profileId,
    int? appUserId,
    String? username,
    String? oauthName,
  }) =>
      AuthResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        profileId: profileId,
        appUserId: appUserId,
        username: username,
        oauthName: oauthName,
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
  final bool isVerified;
  final String role;
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
    this.isVerified = false,
    this.role = 'ROLE_USER',
    this.skills = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        number: json['number'] ?? '',
        location: json['location'] ?? '',
        experience: json['experience'] ?? 0,
        profilePhoto: json['profile_photo'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        isVerified: json['isVerified'] ?? json['verified'] ?? false,
        role: json['role'] ?? 'ROLE_USER',
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
    bool? isVerified,
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
        isVerified: isVerified ?? this.isVerified,
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
  /// "hour" | "day" | "month" | "year"
  final String? salaryPeriod;
  final String jobType;
  final String? createdByName;
  final int? createdById;
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
    this.salaryPeriod,
    required this.jobType,
    this.createdByName,
    this.createdById,
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
        salaryPeriod: json['salaryPeriod']?.toString(),
        jobType: json['jobType'] ?? json['job_type'] ?? 'FULL_TIME',
        createdByName: json['createdBy']?['name'],
        createdById: (json['createdBy'] as Map<String, dynamic>?)?['id'] as int?,
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        skills: (json['skills'] as List<dynamic>?)
                ?.map((s) => Skill.fromJson(s))
                .toList() ??
            [],
        createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
        distanceKm: json['distanceKm']?.toDouble(),
      );

  /// FIX: No ₹ prefix — the currency_rupee icon next to this text provides the symbol.
  /// Avoids double-rupee (icon + ₹ in text) everywhere.
  String get salaryDisplay {
    if (salary <= 0) return '0';
    final period = salaryPeriod?.toLowerCase();
    if (period == 'hour')  return '${_fmt(salary)}/hr';
    if (period == 'day')   return '${_fmt(salary)}/day';
    if (period == 'month') return '${_fmt(salary)}/mo';
    if (period == 'year')  return '${_fmt(salary)}/yr';
    // Legacy fallback: infer from magnitude
    if (salary < 1000)     return '${salary.round()}/hr';
    if (salary <= 50000)   return '${_fmt(salary)}/mo';
    return '${_fmt(salary)}/yr';
  }

  String get salaryFull => '₹$salaryDisplay';

  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    return v.round().toString();
  }

  String get salaryChip => salaryDisplay;
}

class JobApplication {
  final int id;
  final int jobId;
  final String jobTitle;
  final String status;
  final String? coverLetter;
  final String? appliedAt;
  final int? applicantId;
  final String? applicantName;
  final String? applicantNumber;
  final String? applicantEmail;
  final String? applicantLocation;
  final int? applicantExperience;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.status,
    this.coverLetter,
    this.appliedAt,
    this.applicantId,
    this.applicantName,
    this.applicantNumber,
    this.applicantEmail,
    this.applicantLocation,
    this.applicantExperience,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
        id: json['id'] ?? 0,
        jobId: json['jobId'] ?? json['job']?['id'] ?? 0,
        jobTitle: json['jobTitle'] ?? json['job']?['title'] ?? 'Unknown Job',
        status: json['status'] ?? 'PENDING',
        coverLetter: json['coverLetter'],
        appliedAt: json['appliedAt']?.toString() ?? json['applied_at']?.toString(),
        applicantId: json['applicantId'] as int?,
        applicantName: json['applicantName']?.toString(),
        applicantNumber: json['applicantNumber']?.toString(),
        applicantEmail: json['applicantEmail']?.toString(),
        applicantLocation: json['applicantLocation']?.toString(),
        applicantExperience: json['applicantExperience'] as int?,
      );

  String get displayName => applicantName?.isNotEmpty == true
      ? applicantName!
      : 'Applicant #$id';
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

  String get message => body ?? title ?? '';
  bool get read => isRead;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] ?? 0,
        title: json['title']?.toString(),
        body: json['body']?.toString() ?? json['message']?.toString(),
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