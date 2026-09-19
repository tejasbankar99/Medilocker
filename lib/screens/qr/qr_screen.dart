import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/profile_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';

class QrScreen extends StatelessWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final docs = context.watch<DocumentProvider>();

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primary),
          ),
        ),
      );
    }

    final qrData = jsonEncode({
      'app': 'MediLocker',
      'name': profile.fullName,
      'blood_type': profile.bloodType ?? 'Unknown',
      'allergies': profile.allergies,
      'emergency_contact': profile.emergencyContactName ?? 'N/A',
      'emergency_phone': profile.emergencyContactPhone ?? 'N/A',
      'total_records': docs.documents.length,
      'generated_at': DateTime.now().toIso8601String(),
    });

    return Scaffold(
      appBar: AppBar(title: const Text('QR Health Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Info banner ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Share this QR with a doctor for instant access to your basic health information.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── QR Card ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.health_and_safety_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MediLocker Health Card',
                        style: TextStyle(
                          color: Color(0xFF0A1628),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 220,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0A1628),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: Color(0xFF0A1628),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (profile.bloodType != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Blood Type: ${profile.bloodType}',
                      style: const TextStyle(color: Color(0xFF8BA0B8), fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Encoded data preview ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Encoded Information',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _QrInfoRow(icon: Icons.person_outline, label: 'Name', value: profile.fullName),
                  _QrInfoRow(
                    icon: Icons.bloodtype_outlined,
                    label: 'Blood Type',
                    value: profile.bloodType ?? 'Not set',
                  ),
                  _QrInfoRow(
                    icon: Icons.warning_amber_outlined,
                    label: 'Allergies',
                    value: profile.allergies.isEmpty ? 'None' : profile.allergies.join(', '),
                  ),
                  _QrInfoRow(
                    icon: Icons.emergency_outlined,
                    label: 'Emergency Contact',
                    value: profile.emergencyContactName ?? 'Not set',
                  ),
                  _QrInfoRow(
                    icon: Icons.folder_rounded,
                    label: 'Total Records',
                    value: '${docs.documents.length} documents',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Copy raw data
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: qrData));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR data copied to clipboard.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy QR Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _QrInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QrInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
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
