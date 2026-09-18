import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../models/medical_document.dart';
import '../../theme/app_theme.dart';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();

  String _selectedCategory = MedicalDocument.categories.first;
  Uint8List? _fileBytes;
  String? _fileName;
  DateTime? _documentDate;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _doctorCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _fileBytes = result.files.first.bytes;
        _fileName = result.files.first.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _documentDate = picked);
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final docs = context.read<DocumentProvider>();

    final success = await docs.uploadDocument(
      userId: auth.user!.id,
      title: _titleCtrl.text.trim(),
      category: _selectedCategory,
      fileBytes: _fileBytes!,
      fileName: _fileName!,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text.trim(),
      doctorName: _doctorCtrl.text.isEmpty ? null : _doctorCtrl.text.trim(),
      hospitalName: _hospitalCtrl.text.isEmpty ? null : _hospitalCtrl.text.trim(),
      documentDate: _documentDate,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!')),
        );
        context.go('/documents');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(docs.error ?? 'Upload failed. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = context.watch<DocumentProvider>().isUploading;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Record')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── File picker ───────────────────────────────────────────────
              const Text('Document File', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _fileBytes != null ? AppTheme.primary : AppTheme.border,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _fileBytes == null
                      ? Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 40),
                            const SizedBox(height: 8),
                            const Text('Tap to select file',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('PDF, JPG, PNG, DOC supported',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.insert_drive_file_rounded, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fileName!,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                  Text('${(_fileBytes!.length / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                              onPressed: () => setState(() { _fileBytes = null; _fileName = null; }),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Document details ──────────────────────────────────────────
              const Text('Document Details', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Document Title *',
                  hintText: 'e.g. Blood Test Report',
                  prefixIcon: Icon(Icons.title_rounded, color: AppTheme.textSecondary),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: AppTheme.card,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded, color: AppTheme.textSecondary),
                ),
                items: MedicalDocument.categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.categoryColor(c),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c),
                    ],
                  ),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 14),

              // Document date
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    style: const TextStyle(color: Colors.white),
                    controller: TextEditingController(
                      text: _documentDate != null
                          ? DateFormat('MMM dd, yyyy').format(_documentDate!)
                          : '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Document Date (optional)',
                      hintText: 'Select date',
                      prefixIcon: Icon(Icons.calendar_today_outlined, color: AppTheme.textSecondary),
                      suffixIcon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Any notes about this document...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes_rounded, color: AppTheme.textSecondary),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              const Text('Healthcare Provider (optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _doctorCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Doctor Name',
                  prefixIcon: Icon(Icons.medical_services_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _hospitalCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Hospital / Clinic',
                  prefixIcon: Icon(Icons.local_hospital_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isUploading ? null : _upload,
                  icon: isUploading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: Text(isUploading ? 'Uploading...' : 'Upload Document'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
