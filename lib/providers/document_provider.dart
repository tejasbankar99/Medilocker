import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../models/medical_document.dart';

class DocumentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  List<MedicalDocument> _documents = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  String _selectedCategory = 'All';

  List<MedicalDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  List<MedicalDocument> get filteredDocuments {
    if (_selectedCategory == 'All') return _documents;
    return _documents
        .where((d) => d.category == _selectedCategory)
        .toList();
  }

  Map<String, int> get categoryCounts {
    final counts = <String, int>{'All': _documents.length};
    for (final cat in MedicalDocument.categories) {
      counts[cat] = _documents.where((d) => d.category == cat).length;
    }
    return counts;
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> fetchDocuments(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _supabase
          .from('medical_documents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _documents = (data as List)
          .map((d) => MedicalDocument.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load documents.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> uploadDocument({
    required String userId,
    required String title,
    required String category,
    required Uint8List fileBytes,
    required String fileName,
    String? description,
    String? doctorName,
    String? hospitalName,
    DateTime? documentDate,
  }) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final fileId = _uuid.v4();
      final ext = fileName.split('.').last.toLowerCase();
      final storagePath = '$userId/$fileId.$ext';
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

      // Store just the storage path (not public URL — bucket is private)
      await _supabase.storage
          .from('medical-documents')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      // Store the storage path in file_url field
      final fileUrl = storagePath;

      // Save metadata to DB
      final doc = await _supabase.from('medical_documents').insert({
        'user_id': userId,
        'title': title,
        'category': category,
        'description': description,
        'file_url': fileUrl,
        'file_type': mimeType,
        'file_name': fileName,
        'file_size': fileBytes.length,
        'doctor_name': doctorName,
        'hospital_name': hospitalName,
        'document_date': documentDate?.toIso8601String().split('T').first,
      }).select().single();

      _documents.insert(0, MedicalDocument.fromJson(doc as Map<String, dynamic>));

      // Trigger AI analysis in background (non-blocking)
      final docId = (doc as Map<String, dynamic>)['id'] as String;
      _supabase.functions.invoke(
        'analyze-document',
        body: {'document_id': docId},
      ).catchError((_) {}); // ignore errors — analysis is optional

      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Upload failed: ${e.toString()}';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDocument(MedicalDocument doc) async {
    try {
      // Delete file from storage
      if (doc.fileUrl != null) {
        final uri = Uri.parse(doc.fileUrl!);
        final parts = uri.pathSegments;
        final bucketIdx = parts.indexOf('medical-documents');
        if (bucketIdx != -1 && bucketIdx + 1 < parts.length) {
          final storagePath = parts.sublist(bucketIdx + 1).join('/');
          await _supabase.storage
              .from('medical-documents')
              .remove([storagePath]);
        }
      }
      // Delete from DB
      await _supabase
          .from('medical_documents')
          .delete()
          .eq('id', doc.id);

      _documents.removeWhere((d) => d.id == doc.id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete document.';
      notifyListeners();
      return false;
    }
  }

  void clearDocuments() {
    _documents = [];
    _selectedCategory = 'All';
    notifyListeners();
  }

  /// Returns a signed URL valid for 1 hour.
  /// Handles both old public URLs (extracts path) and new storage paths.
  Future<String?> getSignedUrl(String fileUrlOrPath) async {
    try {
      String storagePath = fileUrlOrPath;
      // Old format: full URL containing 'medical-documents/'
      if (fileUrlOrPath.startsWith('http')) {
        final uri = Uri.parse(fileUrlOrPath);
        final parts = uri.pathSegments;
        final bucketIdx = parts.indexOf('medical-documents');
        if (bucketIdx != -1 && bucketIdx + 1 < parts.length) {
          storagePath = parts.sublist(bucketIdx + 1).join('/');
        } else {
          return fileUrlOrPath; // fallback
        }
      }
      final response = await _supabase.storage
          .from('medical-documents')
          .createSignedUrl(storagePath, 3600); // 1 hour
      return response;
    } catch (_) {
      return null;
    }
  }
}
