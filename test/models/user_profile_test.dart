import 'package:flutter_test/flutter_test.dart';
import 'package:medilocker/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('should correctly parse UserProfile from JSON', () {
      final json = {
        'id': 'user-123',
        'full_name': 'Tejas Bankar',
        'email': 'tejas@example.com',
        'phone_number': '+91 9876543210',
        'blood_type': 'O+',
        'allergies': ['Penicillin', 'Peanuts'],
        'emergency_contact_name': 'Emergency Contact',
        'emergency_contact_phone': '+91 9876543211',
        'created_at': '2026-09-15T10:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.fullName, 'Tejas Bankar');
      expect(profile.email, 'tejas@example.com');
      expect(profile.bloodType, 'O+');
      expect(profile.allergies.length, 2);
      expect(profile.allergies, contains('Penicillin'));
    });

    test('should serialize UserProfile to JSON accurately', () {
      final profile = UserProfile(
        id: 'user-456',
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        bloodType: 'A+',
        allergies: const ['Aspirin'],
        createdAt: DateTime.parse('2026-09-15T12:00:00.000Z'),
      );

      final json = profile.toJson();

      expect(json['id'], 'user-456');
      expect(json['full_name'], 'Jane Doe');
      expect(json['blood_type'], 'A+');
      expect(json['allergies'], contains('Aspirin'));
    });
  });
}
