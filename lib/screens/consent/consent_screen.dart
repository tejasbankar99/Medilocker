import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/consent_grant.dart';
import '../../models/consent_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consent_provider.dart';
import '../../theme/app_theme.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid != null) context.read<ConsentProvider>().fetchAll(uid);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consent = context.watch<ConsentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Access'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (consent.pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${consent.pendingCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Active Access'),
          ],
        ),
      ),
      body: consent.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary)))
          : TabBarView(
              controller: _tabs,
              children: [
                _PendingTab(requests: consent.pendingRequests),
                _ActiveTab(grants: consent.activeGrants),
              ],
            ),
    );
  }
}

// ── Pending Requests Tab ──────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final List<ConsentRequest> requests;
  const _PendingTab({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
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
              child: const Icon(Icons.inbox_rounded,
                  color: AppTheme.primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No Pending Requests',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Access requests from doctors\nwill appear here.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _RequestCard(request: requests[i]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ConsentRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      color: AppTheme.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.doctorName ?? 'Dr. Unknown',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      Text(
                        [
                          request.doctorSpecialty,
                          request.doctorHospital
                        ].where((s) => s != null).join(' · '),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Pending',
                      style: TextStyle(
                          color: AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(Icons.lock_open_rounded, 'Requesting Access To',
                request.scopeLabel),
            const SizedBox(height: 6),
            _InfoRow(Icons.info_outline_rounded, 'Purpose', request.purpose),
            const SizedBox(height: 6),
            _InfoRow(Icons.timer_outlined, 'Duration',
                '${request.durationDays} days'),
            if (request.doctorMessage != null) ...[
              const SizedBox(height: 6),
              _InfoRow(Icons.message_outlined, 'Message',
                  request.doctorMessage!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _showRejectDialog(context, request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.go('/consent/approve', extra: request),
                    child: const Text('Review & Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, ConsentRequest request) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Reject Request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this access request?',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: 'Reason (optional)',
                  isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context
                  .read<ConsentProvider>()
                  .rejectRequest(request, noteCtrl.text.isEmpty ? null : noteCtrl.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Request rejected.' : 'Failed to reject.'),
                ));
              }
            },
            child: const Text('Reject',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Active Grants Tab ─────────────────────────────────────────────────────────

class _ActiveTab extends StatelessWidget {
  final List<ConsentGrant> grants;
  const _ActiveTab({required this.grants});

  @override
  Widget build(BuildContext context) {
    final active = grants.where((g) => g.isActive).toList();
    final past = grants.where((g) => !g.isActive).toList();

    if (grants.isEmpty) {
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
              child: const Icon(Icons.shield_outlined,
                  color: AppTheme.primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No Active Access',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Doctors you\'ve approved\nwill appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (active.isNotEmpty) ...[
          const _SectionLabel('Currently Active'),
          const SizedBox(height: 8),
          ...active.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GrantCard(grant: g),
              )),
          const SizedBox(height: 16),
        ],
        if (past.isNotEmpty) ...[
          const _SectionLabel('Past Access'),
          const SizedBox(height: 8),
          ...past.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GrantCard(grant: g),
              )),
        ],
      ],
    );
  }
}

class _GrantCard extends StatelessWidget {
  final ConsentGrant grant;
  const _GrantCard({required this.grant});

  Color get _statusColor {
    if (grant.isRevoked) return AppTheme.error;
    if (grant.isExpired) return AppTheme.textSecondary;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medical_services_rounded,
                    color: _statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(grant.doctorName ?? 'Dr. Unknown',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if (grant.doctorSpecialty != null)
                      Text(grant.doctorSpecialty!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(grant.statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(Icons.lock_open_rounded, 'Access Scope', grant.scopeLabel),
          const SizedBox(height: 4),
          _InfoRow(Icons.event_rounded, 'Expires',
              DateFormat('dd MMM yyyy').format(grant.expiresAt)),
          if (grant.isActive) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRevokeDialog(context),
                icon: const Icon(Icons.block_rounded, size: 16),
                label: const Text('Revoke Access'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRevokeDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    final uid = context.read<AuthProvider>().user?.id ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Revoke Access',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Remove ${grant.doctorName ?? "this doctor"}\'s access to your records?',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: 'Reason (optional)', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<ConsentProvider>().revokeGrant(
                    grant,
                    uid,
                    reasonCtrl.text.isEmpty ? null : reasonCtrl.text,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Access revoked successfully.'
                      : 'Failed to revoke.'),
                ));
              }
            },
            child: const Text('Revoke',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 14),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      );
}
