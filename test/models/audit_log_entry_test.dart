import 'package:flutter_test/flutter_test.dart';
import 'package:medilocker/models/audit_log_entry.dart';

void main() {
  group('AuditLogEntry Model Tests', () {
    test('should map raw action strings to human-readable labels', () {
      final entry = AuditLogEntry(
        id: 'log-1',
        action: 'consent_approved',
        metadata: const {'scope': 'all'},
        createdAt: DateTime.parse('2026-09-22T14:30:00.000Z'),
      );

      expect(entry.actionLabel, 'Access Approved');

      final uploadEntry = AuditLogEntry(
        id: 'log-2',
        action: 'document_uploaded',
        metadata: const {},
        createdAt: DateTime.parse('2026-09-22T15:00:00.000Z'),
      );

      expect(uploadEntry.actionLabel, 'Document Uploaded');
    });

    test('should parse AuditLogEntry from Supabase JSON payload', () {
      final json = {
        'id': 'audit-99',
        'actor_id': 'user-11',
        'actor_role': 'doctor',
        'action': 'document_viewed',
        'target_type': 'medical_document',
        'target_id': 'doc-55',
        'patient_id': 'pat-22',
        'doctor_id': 'doc-11',
        'metadata': {'ip': '192.168.1.1'},
        'created_at': '2026-09-23T09:15:00.000Z',
      };

      final log = AuditLogEntry.fromJson(json);

      expect(log.id, 'audit-99');
      expect(log.actorRole, 'doctor');
      expect(log.actionLabel, 'Document Viewed');
      expect(log.metadata['ip'], '192.168.1.1');
    });
  });
}
