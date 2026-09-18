import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/medical_document.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_card.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocumentProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/documents/upload'),
            tooltip: 'Upload Record',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category filter ─────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ['All', ...MedicalDocument.categories].length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cats = ['All', ...MedicalDocument.categories];
                final cat = cats[index];
                final selected = docs.selectedCategory == cat;
                final count = docs.categoryCounts[cat] ?? 0;
                return FilterChip(
                  label: Text(count > 0 ? '$cat ($count)' : cat),
                  selected: selected,
                  onSelected: (_) => docs.setCategory(cat),
                  backgroundColor: AppTheme.surface,
                  selectedColor: AppTheme.primary.withOpacity(0.2),
                  checkmarkColor: AppTheme.primary,
                  side: BorderSide(
                    color: selected ? AppTheme.primary : AppTheme.border,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // ── Document list ───────────────────────────────────────────────
          Expanded(
            child: docs.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  )
                : docs.filteredDocuments.isEmpty
                    ? _EmptyCategory(
                        category: docs.selectedCategory,
                        onUpload: () => context.go('/documents/upload'),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.card,
                        onRefresh: () async {
                          if (auth.user != null) {
                            await docs.fetchDocuments(auth.user!.id);
                          }
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: docs.filteredDocuments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs.filteredDocuments[index];
                            return DocumentCard(
                              document: doc,
                              onTap: () =>
                                  context.go('/documents/detail', extra: doc),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/documents/upload'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Upload', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  final String category;
  final VoidCallback onUpload;

  const _EmptyCategory({required this.category, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_rounded, color: AppTheme.textSecondary, size: 56),
          const SizedBox(height: 16),
          Text(
            category == 'All' ? 'No documents yet' : 'No $category documents',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your first medical document.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Upload Record'),
          ),
        ],
      ),
    );
  }
}
