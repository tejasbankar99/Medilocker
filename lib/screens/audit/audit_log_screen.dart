import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/audit_log_entry.dart';
import '../../providers/audit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.id;
      if (uid != null) context.read<AuditProvider>().fetchLogs(uid);
    });
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'consent_requested': return Icons.mark_email_unread_rounded;
      case 'consent_approved': return Icons.check_circle_rounded;
      case 'consent_rejected': return Icons.cancel_rounded;
      case 'consent_revoked': return Icons.block_rounded;
      case 'document_viewed': return Icons.visibility_rounded;
      case 'document_uploaded': return Icons.upload_file_rounded;
      case 'document_deleted': return Icons.delete_rounded;
      case 'otp_generated': return Icons.pin_rounded;
      case 'otp_verified': return Icons.verified_rounded;
      default: return Icons.history_rounded;
    }
  }

  Color _colorFor(String action) {
    if (action.contains('approved') || action.contains('verified')) return AppTheme.primary;
    if (action.contains('rejected') || action.contains('revoked') || action.contains('deleted')) return AppTheme.error;
    if (action.contains('requested') || action.contains('otp')) return AppTheme.warning;
    return AppTheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final audit = context.watch<AuditProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Access History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final uid = context.read<AuthProvider>().user?.id;
              if (uid != null) context.read<AuditProvider>().fetchLogs(uid);
            },
          ),
        ],
      ),
      body: audit.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary)))
          : audit.logs.isEmpty
              ? _EmptyAudit()
              : Column(
                  children: [
                    // Header info
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${audit.logs.length} events recorded. All access to your records is logged here.',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount: audit.logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _AuditCard(
                              entry: audit.logs[i],
                              icon: _iconFor(audit.logs[i].action),
                              color: _colorFor(audit.logs[i].action),
                            ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditLogEntry entry;
  final IconData icon;
  final Color color;

  const _AuditCard({
    required this.entry,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final meta = entry.metadata;
    final doctorName = meta['doctor_name'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.actionLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                if (doctorName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Dr. $doctorName',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
                if (meta['scope'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Scope: ${meta['scope']}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatTime(entry.createdAt),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }
}

class _EmptyAudit extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                color: AppTheme.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No Activity Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Doctor access events will\nappear here.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
