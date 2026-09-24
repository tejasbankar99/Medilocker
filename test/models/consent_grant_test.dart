import 'package:flutter_test/flutter_test.dart';
import 'package:medilocker/models/consent_grant.dart';

void main() {
  group('ConsentGrant Model Tests', () {
    test('should identify active vs expired and revoked grants', () {
      final activeGrant = ConsentGrant(
        id: 'grant-1',
        requestId: 'req-1',
        doctorId: 'doc-1',
        patientId: 'pat-1',
        scope: 'all',
        purpose: 'Routine Consultation',
        grantedAt: DateTime.now().subtract(const Duration(hours: 1)),
        expiresAt: DateTime.now().add(const Duration(hours: 23)),
        isRevoked: false,
      );

      expect(activeGrant.isActive, isTrue);
      expect(activeGrant.isExpired, isFalse);
      expect(activeGrant.statusLabel, 'Active');
      expect(activeGrant.scopeLabel, 'All Medical Records');

      final revokedGrant = ConsentGrant(
        id: 'grant-2',
        requestId: 'req-2',
        doctorId: 'doc-1',
        patientId: 'pat-1',
        scope: 'category',
        scopeValue: 'Lab Report',
        purpose: 'Follow-up Check',
        grantedAt: DateTime.now().subtract(const Duration(hours: 2)),
        expiresAt: DateTime.now().add(const Duration(hours: 10)),
        isRevoked: true,
      );

      expect(revokedGrant.isActive, isFalse);
      expect(revokedGrant.statusLabel, 'Revoked');
      expect(revokedGrant.scopeLabel, 'Category: Lab Report');
    });

    test('should parse joined doctor profile details from JSON', () {
      final json = {
        'id': 'grant-100',
        'request_id': 'req-100',
        'doctor_id': 'doc-200',
        'patient_id': 'pat-300',
        'scope': 'specific',
        'purpose': 'Cardiology Review',
        'granted_at': '2026-09-20T10:00:00.000Z',
        'expires_at': '2026-12-31T23:59:59.000Z',
        'is_revoked': false,
        'doctor_profiles': {
          'full_name': 'Dr. Sharma',
          'specialty': 'Cardiology',
          'hospital': 'City Heart Institute',
        },
      };

      final grant = ConsentGrant.fromJson(json);

      expect(grant.doctorName, 'Dr. Sharma');
      expect(grant.doctorSpecialty, 'Cardiology');
      expect(grant.doctorHospital, 'City Heart Institute');
      expect(grant.scopeLabel, 'Specific Documents');
    });
  });
}
