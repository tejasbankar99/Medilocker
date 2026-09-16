class MedicalDocument {
  final String id;
  final String userId;
  final String title;
  final String category;
  final String? description;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final int? fileSize;
  final String? doctorName;
  final String? hospitalName;
  final DateTime? documentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MedicalDocument({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    this.description,
    this.fileUrl,
    this.fileType,
    this.fileName,
    this.fileSize,
    this.doctorName,
    this.hospitalName,
    this.documentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  static const List<String> categories = [
    'Lab Report',
    'Prescription',
    'Hospital Record',
    'Doctor Note',
    'Vaccination',
    'Radiology',
    'Cardiology',
    'Dental',
    'Insurance',
    'Other',
  ];

  bool get isPdf => fileType?.toLowerCase() == 'application/pdf' ||
      (fileName?.toLowerCase().endsWith('.pdf') ?? false);

  bool get isImage =>
      fileType?.startsWith('image/') == true ||
      (fileName?.toLowerCase().endsWith('.jpg') == true) ||
      (fileName?.toLowerCase().endsWith('.jpeg') == true) ||
      (fileName?.toLowerCase().endsWith('.png') == true);

  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  factory MedicalDocument.fromJson(Map<String, dynamic> json) {
    return MedicalDocument(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String?,
      fileType: json['file_type'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      doctorName: json['doctor_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
      documentDate: json['document_date'] != null
          ? DateTime.tryParse(json['document_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'title': title,
    'category': category,
    'description': description,
    'file_url': fileUrl,
    'file_type': fileType,
    'file_name': fileName,
    'file_size': fileSize,
    'doctor_name': doctorName,
    'hospital_name': hospitalName,
    'document_date': documentDate?.toIso8601String().split('T').first,
  };
}
