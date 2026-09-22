import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/consent_provider.dart';
import '../../models/medical_document.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final docs = context.watch<DocumentProvider>();
    final profile = context.watch<ProfileProvider>();
    final consent = context.watch<ConsentProvider>();
    final greeting = _greeting();
    final name = profile.profile?.fullName.split(' ').first ?? 'there';
    final pendingConsent = consent.pendingCount;

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.card,
        onRefresh: () async {
          if (auth.user != null) {
            await docs.fetchDocuments(auth.user!.id);
          }
        },
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.bg,
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroHeader(greeting: greeting, name: name, docs: docs),
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.go('/consent'),
                    ),
                    if (pendingConsent > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$pendingConsent',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Stats Row ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _StatsRow(docs: docs, profile: profile),
              ),
            ),

            // ── Quick Actions ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Actions',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.upload_file_rounded,
                            label: 'Upload\nRecord',
                            color: AppTheme.primary,
                            onTap: () => context.go('/documents/upload'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.qr_code_rounded,
                            label: 'Share\nvia QR',
                            color: AppTheme.secondary,
                            onTap: () => context.go('/qr'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.folder_open_rounded,
                            label: 'All\nRecords',
                            color: const Color(0xFFCE93D8),
                            onTap: () => context.go('/documents'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.person_outline_rounded,
                            label: 'My\nProfile',
                            color: const Color(0xFFFFB74D),
                            onTap: () => context.go('/profile'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Recent Records ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    const Text('Recent Records',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/documents'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            if (docs.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
                ),
              )
            else if (docs.documents.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(
                  onUpload: () => context.go('/documents/upload'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = docs.documents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DocumentCard(
                          document: doc,
                          onTap: () => context.go('/documents/detail', extra: doc),
                        ),
                      );
                    },
                    childCount: docs.documents.take(5).length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _HeroHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final DocumentProvider docs;

  const _HeroHeader({required this.greeting, required this.name, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF122036)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${docs.documents.length} records',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DocumentProvider docs;
  final ProfileProvider profile;

  const _StatsRow({required this.docs, required this.profile});

  @override
  Widget build(BuildContext context) {
    final cats = docs.categoryCounts;
    final topCat = MedicalDocument.categories
        .map((c) => MapEntry(c, cats[c] ?? 0))
        .reduce((a, b) => a.value > b.value ? a : b);

    return Row(
      children: [
        Expanded(child: _StatCard(
          value: '${docs.documents.length}',
          label: 'Total Records',
          icon: Icons.folder_rounded,
          color: AppTheme.primary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          value: topCat.value > 0 ? topCat.key.split(' ').first : '—',
          label: 'Top Category',
          icon: Icons.star_rounded,
          color: AppTheme.secondary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          value: profile.profile?.bloodType ?? '—',
          label: 'Blood Type',
          icon: Icons.bloodtype_rounded,
          color: const Color(0xFFFF6B6B),
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('No records yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Upload your first medical document\nto get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
