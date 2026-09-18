import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/medical_document.dart';
import '../../providers/ai_insight_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_insight_card.dart';

class DocumentDetailScreen extends StatefulWidget {
  final MedicalDocument document;
  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndPoll());
  }

  Future<void> _loadAndPoll() async {
    final provider = context.read<AiInsightProvider>();
    await provider.fetchInsight(widget.document.id);
    final insight = provider.getInsight(widget.document.id);
    // If still processing, start polling
    if (insight == null || insight.isProcessing) {
      provider.pollInsight(widget.document.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColor(widget.document.category);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withOpacity(0.3), AppTheme.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: catColor.withOpacity(0.5), width: 2),
                        ),
                        child: Icon(
                          widget.document.isPdf
                              ? Icons.picture_as_pdf_rounded
                              : widget.document.isImage
                                  ? Icons.image_rounded
                                  : Icons.insert_drive_file_rounded,
                          color: catColor,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: catColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      widget.document.category,
                      style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    widget.document.title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Uploaded ${DateFormat('MMM dd, yyyy').format(widget.document.createdAt)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),

                  if (widget.document.description != null && widget.document.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Description',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(widget.document.description!,
                        style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ],

                  const SizedBox(height: 24),
                  const Text('Details',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  _DetailCard(children: [
                    if (widget.document.doctorName != null)
                      _DetailRow(
                        icon: Icons.medical_services_outlined,
                        label: 'Doctor',
                        value: widget.document.doctorName!,
                      ),
                    if (widget.document.hospitalName != null)
                      _DetailRow(
                        icon: Icons.local_hospital_outlined,
                        label: 'Hospital',
                        value: widget.document.hospitalName!,
                      ),
                    if (widget.document.documentDate != null)
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Document Date',
                        value: DateFormat('MMMM dd, yyyy').format(widget.document.documentDate!),
                      ),
                    if (widget.document.fileName != null)
                      _DetailRow(
                        icon: Icons.insert_drive_file_outlined,
                        label: 'File',
                        value: '${widget.document.fileName} • ${widget.document.fileSizeFormatted}',
                      ),
                  ]),

                  if (widget.document.fileUrl != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _openFile(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('View / Download File'),
                      ),
                    ),
                  ],

                  // ── AI Insights ──────────────────────────────────────────
                  const SizedBox(height: 32),
                  Consumer<AiInsightProvider>(
                    builder: (context, aiProvider, _) => AiInsightCard(
                      insight: aiProvider.getInsight(widget.document.id),
                      isLoading: aiProvider.isLoading(widget.document.id),
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File: ${widget.document.fileUrl}'),
        action: SnackBarAction(label: 'Copy', onPressed: () {}),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Delete Document',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${widget.document.title}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final docs = context.read<DocumentProvider>();
              final ok = await docs.deleteDocument(widget.document);
              if (context.mounted) {
                if (ok) {
                  context.go('/documents');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document deleted.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(docs.error ?? 'Delete failed.')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
