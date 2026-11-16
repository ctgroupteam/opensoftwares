class CrmProfile {
  final String id;
  final String mobileNumber;
  final String name;
  final String role; // 'admin_founder' | 'founder' | 'channel_partner'
  final String team; // 'Gulbarga' | 'Solapur' | 'Both'
  final Map<String, dynamic> permissions;
  final bool isDisabled;
  final bool firstLoginChangeRequired;
  final DateTime? createdAt;

  CrmProfile({
    required this.id,
    required this.mobileNumber,
    required this.name,
    required this.role,
    required this.team,
    this.permissions = const {},
    this.isDisabled = false,
    this.firstLoginChangeRequired = false,
    this.createdAt,
  });

  bool get isAdminFounder => role == 'admin_founder';
  bool get isFounder => role == 'founder';
  bool get isChannelPartner => role == 'channel_partner';

  bool canCreate(String module) =>
      isAdminFounder ||
      isFounder ||
      (permissions['modules']?[module]?['create'] ?? false);

  bool canEdit(String module) =>
      isAdminFounder ||
      isFounder ||
      (permissions['modules']?[module]?['edit'] ?? false);

  bool canDelete(String module) =>
      isAdminFounder ||
      isFounder ||
      (permissions['modules']?[module]?['delete'] ?? false);

  factory CrmProfile.fromJson(Map<String, dynamic> json) {
    return CrmProfile(
      id: json['id'] as String,
      mobileNumber: json['mobile_number'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      role: json['role'] as String? ?? 'founder',
      team: json['team'] as String? ?? 'Gulbarga',
      permissions: json['permissions'] as Map<String, dynamic>? ?? {},
      isDisabled: json['is_disabled'] as bool? ?? false,
      firstLoginChangeRequired:
          json['first_login_change_required'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile_number': mobileNumber,
      'name': name,
      'role': role,
      'team': team,
      'permissions': permissions,
      'is_disabled': isDisabled,
      'first_login_change_required': firstLoginChangeRequired,
    };
  }
}

