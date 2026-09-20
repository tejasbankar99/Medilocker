import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_insight.dart';

class AiInsightProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Cache: documentId → AiInsight
  final Map<String, AiInsight> _insights = {};
  final Map<String, bool> _loading = {};

  AiInsight? getInsight(String documentId) => _insights[documentId];
  bool isLoading(String documentId) => _loading[documentId] ?? false;

  /// Fetch existing insight for a document (called when opening detail screen)
  Future<void> fetchInsight(String documentId) async {
    _loading[documentId] = true;
    notifyListeners();
    try {
      final data = await _supabase
          .from('ai_insights')
          .select()
          .eq('document_id', documentId)
          .maybeSingle();

      if (data != null) {
        _insights[documentId] =
            AiInsight.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {}
    _loading[documentId] = false;
    notifyListeners();
  }

  /// Trigger the Edge Function to analyze a document (called after upload)
  /// Non-blocking — returns immediately, analysis happens in background
  Future<void> triggerAnalysis(String documentId) async {
    // Optimistically create a 'pending' record
    try {
      await _supabase.functions.invoke(
        'analyze-document',
        body: {'document_id': documentId},
      );
      // Re-fetch after invocation completes
      await fetchInsight(documentId);
    } catch (e) {
      // Non-blocking — don't fail the upload
      debugPrint('AI analysis trigger failed: $e');
    }
  }

  /// Poll for completion (called from detail screen when status is 'processing')
  Future<void> pollInsight(String documentId) async {
    int attempts = 0;
    while (attempts < 20) {
      await Future.delayed(const Duration(seconds: 3));
      await fetchInsight(documentId);
      final insight = _insights[documentId];
      if (insight != null && insight.isCompleted) break;
      if (insight != null && insight.hasFailed) break;
      attempts++;
    }
  }

  void clear() {
    _insights.clear();
    _loading.clear();
    notifyListeners();
  }
}
