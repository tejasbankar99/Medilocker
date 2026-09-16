class ConsentRequest {
  final String id;
  final String doctorId;
  final String patientId;
  final String purpose;
  final String scope; // 'all' | 'category' | 'specific'
  final String? scopeValue;
  final int durationDays;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String? doctorMessage;
  final String? patientNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined doctor info (from doctor_profiles)
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorHospital;

  const ConsentRequest({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.purpose,
    required this.scope,
    this.scopeValue,
    required this.durationDays,
    required this.status,
    this.doctorMessage,
    this.patientNote,
    required this.createdAt,
    required this.updatedAt,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorHospital,
  });

  String get scopeLabel {
    switch (scope) {
      case 'all': return 'All Medical Records';
      case 'category': return 'Category: ${scopeValue ?? ''}';
      case 'specific': return 'Specific Documents';
      default: return scope;
    }
  }

  factory ConsentRequest.fromJson(Map<String, dynamic> json) {
    final doctorProfile = json['doctor_profiles'] as Map<String, dynamic>?;
    return ConsentRequest(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      patientId: json['patient_id'] as String,
      purpose: json['purpose'] as String,
      scope: json['scope'] as String,
      scopeValue: json['scope_value'] as String?,
      durationDays: json['duration_days'] as int,
      status: json['status'] as String,
      doctorMessage: json['doctor_message'] as String?,
      patientNote: json['patient_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      doctorName: doctorProfile?['full_name'] as String?,
      doctorSpecialty: doctorProfile?['specialty'] as String?,
      doctorHospital: doctorProfile?['hospital'] as String?,
    );
  }
}
