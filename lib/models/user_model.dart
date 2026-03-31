import 'package:rangeguard_vn/core/constants/app_constants.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String employeeId;
  final String unit;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final String? stationId;
  final bool isActive;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.employeeId,
    required this.unit,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.stationId,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isLeader => role == AppConstants.roleLeader || isAdmin;
  bool get canEdit => role != AppConstants.roleViewer;

  String get roleLabel {
    switch (role) {
      case AppConstants.roleAdmin:
        return 'Quản trị viên';
      case AppConstants.roleLeader:
        return 'Trưởng đội tuần tra';
      case AppConstants.roleRanger:
        return 'Tuần tra viên';
      case AppConstants.roleViewer:
        return 'Xem báo cáo';
      default:
        return role;
    }
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        email: map['email'] as String? ?? '',
        fullName: map['full_name'] as String? ?? '',
        employeeId: map['employee_id'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        phone: map['phone'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        role: map['role'] as String? ?? AppConstants.roleViewer,
        stationId: map['station_id'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(
            map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'employee_id': employeeId,
        'unit': unit,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role,
        'station_id': stationId,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  UserProfile copyWith({
    String? fullName,
    String? employeeId,
    String? unit,
    String? phone,
    String? avatarUrl,
    String? role,
    String? stationId,
    bool? isActive,
  }) =>
      UserProfile(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        employeeId: employeeId ?? this.employeeId,
        unit: unit ?? this.unit,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        stationId: stationId ?? this.stationId,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
