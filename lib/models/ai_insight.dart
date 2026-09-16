class AiInsight {
  final String id;
  final String documentId;
  final String userId;
  final String status; // pending | processing | completed | failed
  final String? summary;
  final String? keyFindings;
  final String? comparisonWithPrevious;
  final Map<String, dynamic> parameterChanges;
  final String? healthTrends;
  final String? previousDocumentId;
  final String modelUsed;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiInsight({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.status,
    this.summary,
    this.keyFindings,
    this.comparisonWithPrevious,
    required this.parameterChanges,
    this.healthTrends,
    this.previousDocumentId,
    required this.modelUsed,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isProcessing => status == 'processing' || status == 'pending';
  bool get hasFailed => status == 'failed';
  bool get hasComparison => comparisonWithPrevious != null &&
      comparisonWithPrevious!.isNotEmpty &&
      comparisonWithPrevious != 'null';

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'pending',
      summary: json['summary'] as String?,
      keyFindings: json['key_findings'] as String?,
      comparisonWithPrevious: json['comparison_with_previous'] as String?,
      parameterChanges:
          (json['parameter_changes'] as Map<String, dynamic>?) ?? {},
      healthTrends: json['health_trends'] as String?,
      previousDocumentId: json['previous_document_id'] as String?,
      modelUsed: json['model_used'] as String? ?? 'gemini-3.6-flash',
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
