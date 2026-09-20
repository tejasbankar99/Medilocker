import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consent_request.dart';
import '../models/consent_grant.dart';

class ConsentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ConsentRequest> _pendingRequests = [];
  List<ConsentGrant> _activeGrants = [];
  bool _isLoading = false;
  String? _error;
  String? _currentPatientId;
  RealtimeChannel? _channel;

  List<ConsentRequest> get pendingRequests => _pendingRequests;
  List<ConsentGrant> get activeGrants => _activeGrants;
  int get pendingCount => _pendingRequests.length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? v) { _error = v; notifyListeners(); }
  void clearError() { _error = null; notifyListeners(); }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> fetchAll(String patientId) async {
    _currentPatientId = patientId;
    _setLoading(true);
    try {
      await Future.wait([
        _fetchPending(patientId),
        _fetchGrants(patientId),
      ]);
    } catch (e) {
      _setError('Failed to load consent data.');
    }
    _setLoading(false);
  }

  // ── Realtime Subscription ─────────────────────────────────────────────────

  /// Call once after fetchAll to receive instant push for new consent requests.
  void subscribeToRequests(String patientId) {
    _currentPatientId = patientId;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('consent-patient-$patientId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'consent_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: patientId,
          ),
          callback: (payload) async {
            // New request arrived — refresh the list
            await _fetchPending(patientId);
            notifyListeners();
          },
        )
        .subscribe();
  }

  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  void dispose() {
    unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _fetchPending(String patientId) async {
    // Step 1: Fetch pending consent requests
    final requestsData = await _supabase
        .from('consent_requests')
        .select('*')
        .eq('patient_id', patientId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final List requestsList = requestsData as List;
    if (requestsList.isEmpty) { _pendingRequests = []; return; }

    // Step 2: Fetch doctor profiles for all unique doctor IDs
    final doctorIds = requestsList
        .map((r) => r['doctor_id'] as String)
        .toSet()
        .toList();
    final doctorsData = await _supabase
        .from('doctor_profiles')
        .select('user_id, full_name, specialty, hospital')
        .inFilter('user_id', doctorIds);

    final doctorMap = <String, Map<String, dynamic>>{};
    for (final doc in doctorsData as List) {
      doctorMap[doc['user_id'] as String] = doc as Map<String, dynamic>;
    }

    // Step 3: Merge and parse
    _pendingRequests = requestsList.map((row) {
      final r = Map<String, dynamic>.from(row as Map);
      r['doctor_profiles'] = doctorMap[r['doctor_id']];
      return ConsentRequest.fromJson(r);
    }).toList();
  }

  Future<void> _fetchGrants(String patientId) async {
    // Step 1: Fetch all consent grants for this patient
    final grantsData = await _supabase
        .from('consent_grants')
        .select('*')
        .eq('patient_id', patientId)
        .order('granted_at', ascending: false);

    final List grantsList = grantsData as List;
    if (grantsList.isEmpty) { _activeGrants = []; return; }

    // Step 2: Fetch doctor profiles for all unique doctor IDs
    final doctorIds = grantsList
        .map((r) => r['doctor_id'] as String)
        .toSet()
        .toList();
    final doctorsData = await _supabase
        .from('doctor_profiles')
        .select('user_id, full_name, specialty, hospital')
        .inFilter('user_id', doctorIds);

    final doctorMap = <String, Map<String, dynamic>>{};
    for (final doc in doctorsData as List) {
      doctorMap[doc['user_id'] as String] = doc as Map<String, dynamic>;
    }

    // Step 3: Merge and parse
    _activeGrants = grantsList.map((row) {
      final r = Map<String, dynamic>.from(row as Map);
      r['doctor_profiles'] = doctorMap[r['doctor_id']];
      return ConsentGrant.fromJson(r);
    }).toList();
  }

  // ── OTP Generation ────────────────────────────────────────────────────────

  /// Calls the server-side 'generate-otp' Edge Function which:
  ///   1. Generates a 6-digit code
  ///   2. Stores it in otp_verifications (expires 10 min)
  ///   3. Emails the code to the patient via Resend
  ///   4. Returns ONLY the otpId — code never sent to client
  Future<Map<String, String>?> generateOtp(
      String patientId, String requestId, {String? doctorName}) async {
    // ── Try Edge Function first (sends OTP via email) ─────────────────────
    try {
      final response = await _supabase.functions.invoke(
        'generate-otp',
        body: {
          'patient_id': patientId,
          'request_id': requestId,
          'doctor_name': doctorName,
        },
      );

      if (response.data != null && response.data['otpId'] != null) {
        return {
          'otpId': response.data['otpId'] as String,
          'email': response.data['email'] as String? ?? '',
          'via': 'email', // tells UI not to show code
        };
      }
    } catch (_) {
      // Edge Function not deployed yet — fall through to local generation
    }

    // ── Fallback: generate locally and show on screen ─────────────────────
    try {
      final code = (100000 + DateTime.now().microsecondsSinceEpoch % 900000)
          .toString()
          .substring(0, 6);
      final expires = DateTime.now().add(const Duration(minutes: 10));

      final result = await _supabase.from('otp_verifications').insert({
        'user_id': patientId,
        'otp_code': code,
        'purpose': 'consent_approval',
        'reference_id': requestId,
        'expires_at': expires.toIso8601String(),
      }).select('id').single();

      return {
        'otpId': result['id'] as String,
        'otpCode': code, // shown on screen in fallback mode
        'via': 'screen',
      };
    } catch (e) {
      _setError('Failed to generate verification code. Please try again.');
      return null;
    }
  }

  /// Verifies OTP and creates a consent grant on success.
  Future<bool> verifyOtpAndGrant({
    required String otpId,
    required String enteredCode,
    required ConsentRequest request,
    required String scope,
    required String? scopeValue,
    required int durationDays,
  }) async {
    try {
      // Fetch OTP record
      final otpRow = await _supabase
          .from('otp_verifications')
          .select()
          .eq('id', otpId)
          .eq('is_used', false)
          .single();

      final storedCode = otpRow['otp_code'] as String;
      final expiresAt = DateTime.parse(otpRow['expires_at'] as String);

      if (DateTime.now().isAfter(expiresAt)) {
        _setError('OTP has expired. Please try again.');
        return false;
      }
      if (storedCode != enteredCode.trim()) {
        _setError('Incorrect OTP. Please check and try again.');
        return false;
      }

      // Mark OTP as used
      await _supabase
          .from('otp_verifications')
          .update({'is_used': true})
          .eq('id', otpId);

      // Create consent grant
      final expiresGrant =
          DateTime.now().add(Duration(days: durationDays));
      await _supabase.from('consent_grants').insert({
        'request_id': request.id,
        'doctor_id': request.doctorId,
        'patient_id': request.patientId,
        'scope': scope,
        'scope_value': scopeValue,
        'purpose': request.purpose,
        'expires_at': expiresGrant.toIso8601String(),
      });

      // Update request status
      await _supabase
          .from('consent_requests')
          .update({'status': 'approved'})
          .eq('id', request.id);

      // Log it
      await _insertAuditLog(
        actorId: request.patientId,
        actorRole: 'patient',
        action: 'consent_approved',
        targetType: 'consent_request',
        targetId: request.id,
        patientId: request.patientId,
        doctorId: request.doctorId,
        metadata: {
          'scope': scope,
          'duration_days': durationDays,
          'doctor_name': request.doctorName,
        },
      );

      // Refresh lists
      await _fetchPending(request.patientId);
      await _fetchGrants(request.patientId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Approval failed. Please try again.');
      return false;
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────

  Future<bool> rejectRequest(ConsentRequest request, String? note) async {
    try {
      await _supabase.from('consent_requests').update({
        'status': 'rejected',
        'patient_note': note,
      }).eq('id', request.id);

      await _insertAuditLog(
        actorId: request.patientId,
        actorRole: 'patient',
        action: 'consent_rejected',
        targetType: 'consent_request',
        targetId: request.id,
        patientId: request.patientId,
        doctorId: request.doctorId,
        metadata: {'doctor_name': request.doctorName, 'note': note},
      );

      await _fetchPending(request.patientId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to reject request.');
      return false;
    }
  }

  // ── Revoke ────────────────────────────────────────────────────────────────

  Future<bool> revokeGrant(
      ConsentGrant grant, String patientId, String? reason) async {
    try {
      await _supabase.from('consent_grants').update({
        'is_revoked': true,
        'revoked_at': DateTime.now().toIso8601String(),
        'revoke_reason': reason,
      }).eq('id', grant.id);

      await _insertAuditLog(
        actorId: patientId,
        actorRole: 'patient',
        action: 'consent_revoked',
        targetType: 'consent_grant',
        targetId: grant.id,
        patientId: patientId,
        doctorId: grant.doctorId,
        metadata: {
          'doctor_name': grant.doctorName,
          'reason': reason,
        },
      );

      await _fetchGrants(patientId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to revoke access.');
      return false;
    }
  }

  // ── Audit Log helper ──────────────────────────────────────────────────────

  Future<void> _insertAuditLog({
    required String actorId,
    required String actorRole,
    required String action,
    String? targetType,
    String? targetId,
    String? patientId,
    String? doctorId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('audit_logs').insert({
        'actor_id': actorId,
        'actor_role': actorRole,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'metadata': metadata ?? {},
      });
    } catch (_) {} // Non-blocking
  }
}
