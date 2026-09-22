import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_log_entry.dart';

class AuditProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AuditLogEntry> _logs = [];
  bool _isLoading = false;
  String? _error;

  List<AuditLogEntry> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchLogs(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _supabase
          .from('audit_logs')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(100);
      _logs = (data as List)
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load audit logs.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _logs = [];
    notifyListeners();
  }
}
