class ConsentGrant {
  final String id;
  final String requestId;
  final String doctorId;
  final String patientId;
  final String scope;
  final String? scopeValue;
  final String purpose;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final bool isRevoked;
  final DateTime? revokedAt;
  final String? revokeReason;

  // Joined doctor info
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorHospital;

  const ConsentGrant({
    required this.id,
    required this.requestId,
    required this.doctorId,
    required this.patientId,
    required this.scope,
    this.scopeValue,
    required this.purpose,
    required this.grantedAt,
    required this.expiresAt,
    required this.isRevoked,
    this.revokedAt,
    this.revokeReason,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorHospital,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isRevoked && !isExpired;

  String get scopeLabel {
    switch (scope) {
      case 'all': return 'All Medical Records';
      case 'category': return 'Category: ${scopeValue ?? ''}';
      case 'specific': return 'Specific Documents';
      default: return scope;
    }
  }

  String get statusLabel {
    if (isRevoked) return 'Revoked';
    if (isExpired) return 'Expired';
    return 'Active';
  }

  factory ConsentGrant.fromJson(Map<String, dynamic> json) {
    final doctorProfile = json['doctor_profiles'] as Map<String, dynamic>?;
    return ConsentGrant(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      doctorId: json['doctor_id'] as String,
      patientId: json['patient_id'] as String,
      scope: json['scope'] as String,
      scopeValue: json['scope_value'] as String?,
      purpose: json['purpose'] as String,
      grantedAt: DateTime.parse(json['granted_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isRevoked: json['is_revoked'] as bool? ?? false,
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      revokeReason: json['revoke_reason'] as String?,
      doctorName: doctorProfile?['full_name'] as String?,
      doctorSpecialty: doctorProfile?['specialty'] as String?,
      doctorHospital: doctorProfile?['hospital'] as String?,
    );
  }
}
