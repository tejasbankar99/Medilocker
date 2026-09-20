import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consent_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emergencyNameCtrl;
  late TextEditingController _emergencyPhoneCtrl;
  late TextEditingController _allergyCtrl;
  String? _selectedBloodType;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _nameCtrl = TextEditingController(text: profile?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phoneNumber ?? '');
    _addressCtrl = TextEditingController(text: profile?.address ?? '');
    _emergencyNameCtrl = TextEditingController(text: profile?.emergencyContactName ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: profile?.emergencyContactPhone ?? '');
    _allergyCtrl = TextEditingController();
    _selectedBloodType = profile?.bloodType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _allergyCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() => setState(() => _isEditing = !_isEditing);

  Future<void> _save() async {
    final pp = context.read<ProfileProvider>();
    if (pp.profile == null) return;
    final updated = pp.profile!.copyWith(
      fullName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.isEmpty ? null : _addressCtrl.text.trim(),
      emergencyContactName: _emergencyNameCtrl.text.isEmpty ? null : _emergencyNameCtrl.text.trim(),
      emergencyContactPhone: _emergencyPhoneCtrl.text.isEmpty ? null : _emergencyPhoneCtrl.text.trim(),
      bloodType: _selectedBloodType,
    );
    final ok = await pp.updateProfile(updated);
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Profile updated!' : pp.error ?? 'Update failed.')),
      );
    }
  }

  void _signOut(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<DocumentProvider>().clearDocuments();
              context.read<ProfileProvider>().clearProfile();
              await context.read<AuthProvider>().signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final auth = context.watch<AuthProvider>();
    final docs = context.watch<DocumentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: _toggleEdit,
              child: const Text('Edit', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            )
          else ...[
            TextButton(
              onPressed: _toggleEdit,
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar & header ───────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (profile?.fullName.isNotEmpty == true ? profile!.fullName[0].toUpperCase() : '?'),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.fullName ?? auth.user?.email ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.email ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Stats
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${docs.documents.length} medical records',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Personal info ────────────────────────────────────────────
            _SectionHeader(title: 'Personal Information'),
            const SizedBox(height: 12),
            _isEditing
                ? Column(children: [
                    _EditField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _EditField(controller: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, type: TextInputType.phone),
                    const SizedBox(height: 12),
                    _EditField(controller: _addressCtrl, label: 'Address', icon: Icons.location_on_outlined),
                  ])
                : _InfoCard(items: [
                    _InfoItem(icon: Icons.person_outline, label: 'Full Name', value: profile?.fullName ?? '—'),
                    _InfoItem(icon: Icons.phone_outlined, label: 'Phone', value: profile?.phoneNumber ?? '—'),
                    _InfoItem(icon: Icons.location_on_outlined, label: 'Address', value: profile?.address ?? '—'),
                  ]),

            const SizedBox(height: 24),

            // ── Medical info ──────────────────────────────────────────────
            _SectionHeader(title: 'Medical Information'),
            const SizedBox(height: 12),
            _isEditing
                ? DropdownButtonFormField<String>(
                    value: _selectedBloodType,
                    dropdownColor: AppTheme.card,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Blood Type',
                      prefixIcon: Icon(Icons.bloodtype_outlined, color: AppTheme.textSecondary),
                    ),
                    items: UserProfile.bloodTypes.map((bt) => DropdownMenuItem(value: bt, child: Text(bt))).toList(),
                    onChanged: (v) => setState(() => _selectedBloodType = v),
                  )
                : _InfoCard(items: [
                    _InfoItem(icon: Icons.bloodtype_outlined, label: 'Blood Type', value: profile?.bloodType ?? '—'),
                    _InfoItem(
                      icon: Icons.warning_amber_outlined,
                      label: 'Allergies',
                      value: profile?.allergies.isEmpty == true ? 'None' : (profile?.allergies.join(', ') ?? '—'),
                    ),
                  ]),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              // Allergy chips
              _AllergyEditor(
                allergies: context.watch<ProfileProvider>().profile?.allergies ?? [],
                controller: _allergyCtrl,
                onAdd: (a) async {
                  final pp = context.read<ProfileProvider>();
                  if (pp.profile == null) return;
                  final updated = pp.profile!.copyWith(
                    allergies: [...pp.profile!.allergies, a],
                  );
                  await pp.updateProfile(updated);
                  setState(() {});
                },
                onRemove: (a) async {
                  final pp = context.read<ProfileProvider>();
                  if (pp.profile == null) return;
                  final updated = pp.profile!.copyWith(
                    allergies: pp.profile!.allergies.where((x) => x != a).toList(),
                  );
                  await pp.updateProfile(updated);
                  setState(() {});
                },
              ),
            ],

            const SizedBox(height: 24),

            // ── Emergency contact ─────────────────────────────────────────
            _SectionHeader(title: 'Emergency Contact'),
            const SizedBox(height: 12),
            _isEditing
                ? Column(children: [
                    _EditField(controller: _emergencyNameCtrl, label: 'Contact Name', icon: Icons.contact_emergency_outlined),
                    const SizedBox(height: 12),
                    _EditField(controller: _emergencyPhoneCtrl, label: 'Contact Phone', icon: Icons.phone_outlined, type: TextInputType.phone),
                  ])
                : _InfoCard(items: [
                    _InfoItem(icon: Icons.contact_emergency_outlined, label: 'Name', value: profile?.emergencyContactName ?? '—'),
                    _InfoItem(icon: Icons.phone_outlined, label: 'Phone', value: profile?.emergencyContactPhone ?? '—'),
                  ]),

            const SizedBox(height: 32),

            // ── Access & Privacy ──────────────────────────────────────────
            _SectionHeader(title: 'Privacy & Access'),
            const SizedBox(height: 12),
            _LinkTile(
              icon: Icons.shield_rounded,
              iconColor: AppTheme.secondary,
              label: 'Doctor Access',
              subtitle: 'Manage who can view your records',
              onTap: () => context.go('/consent'),
              badge: context.watch<ConsentProvider>().pendingCount,
            ),
            const SizedBox(height: 8),
            _LinkTile(
              icon: Icons.history_rounded,
              iconColor: AppTheme.warning,
              label: 'Access History',
              subtitle: 'See who accessed your records',
              onTap: () => context.go('/audit-logs'),
            ),

            const SizedBox(height: 24),

            // ── Sign out ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
                label: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
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

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;
  const _LinkTile({
    required this.icon, required this.iconColor, required this.label,
    required this.subtitle, required this.onTap, this.badge = 0,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
  );
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(e.value.icon, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 12),
                    Text(e.value.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const Spacer(),
                    Text(e.value.value,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? type;
  const _EditField({required this.controller, required this.label, required this.icon, this.type});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white),
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
    ),
  );
}

class _AllergyEditor extends StatelessWidget {
  final List<String> allergies;
  final TextEditingController controller;
  final Function(String) onAdd;
  final Function(String) onRemove;

  const _AllergyEditor({
    required this.allergies,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Allergies', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          if (allergies.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allergies.map((a) => Chip(
                label: Text(a, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppTheme.error.withOpacity(0.2),
                side: BorderSide(color: AppTheme.error.withOpacity(0.4)),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.error),
                onDeleted: () => onRemove(a),
              )).toList(),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add allergy...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    onAdd(controller.text.trim());
                    controller.clear();
                  }
                },
                icon: const Icon(Icons.add_circle_rounded, color: AppTheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
