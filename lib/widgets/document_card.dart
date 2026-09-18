import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medical_document.dart';
import '../theme/app_theme.dart';

class DocumentCard extends StatelessWidget {
  final MedicalDocument document;
  final VoidCallback onTap;

  const DocumentCard({super.key, required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColor(document.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            // ── Color bar + icon ───────────────────────────────────────────
            Container(
              width: 72,
              height: 80,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    document.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : document.isImage
                            ? Icons.image_rounded
                            : Icons.insert_drive_file_rounded,
                    color: catColor,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: catColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            document.category,
                            style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('dd MMM').format(document.createdAt),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      document.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (document.doctorName != null || document.hospitalName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [document.doctorName, document.hospitalName]
                            .where((s) => s != null)
                            .join(' • '),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (document.fileSizeFormatted.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        document.fileSizeFormatted,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
