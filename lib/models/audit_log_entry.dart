class AuditLogEntry {
  final String id;
  final String? actorId;
  final String? actorRole;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? patientId;
  final String? doctorId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    this.actorId,
    this.actorRole,
    required this.action,
    this.targetType,
    this.targetId,
    this.patientId,
    this.doctorId,
    required this.metadata,
    required this.createdAt,
  });

  String get actionLabel {
    switch (action) {
      case 'consent_requested': return 'Access Requested';
      case 'consent_approved': return 'Access Approved';
      case 'consent_rejected': return 'Access Rejected';
      case 'consent_revoked': return 'Access Revoked';
      case 'document_viewed': return 'Document Viewed';
      case 'document_uploaded': return 'Document Uploaded';
      case 'document_deleted': return 'Document Deleted';
      case 'otp_generated': return 'OTP Generated';
      case 'otp_verified': return 'OTP Verified';
      default: return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      actorId: json['actor_id'] as String?,
      actorRole: json['actor_role'] as String?,
      action: json['action'] as String,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      patientId: json['patient_id'] as String?,
      doctorId: json['doctor_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
