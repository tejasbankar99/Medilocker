import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/profile_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/consent_provider.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    context.read<ProfileProvider>().fetchProfile(user.id);
    context.read<DocumentProvider>().fetchDocuments(user.id);
    context.read<ConsentProvider>().fetchAll(user.id).then((_) {
      // Start realtime after initial data load
      if (mounted) {
        context.read<ConsentProvider>().subscribeToRequests(user.id);
      }
    });
  }

  @override
  void dispose() {
    context.read<ConsentProvider>().unsubscribeRealtime();
    super.dispose();
  }

  int _locationToIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/documents')) return 1;
    if (location.startsWith('/timeline')) return 2;
    if (location.startsWith('/consent')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/documents'); break;
      case 2: context.go('/timeline'); break;
      case 3: context.go('/consent'); break;
      case 4: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _locationToIndex(context);
    final pendingCount = context.watch<ConsentProvider>().pendingCount;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF122036),
          border: Border(
            top: BorderSide(color: const Color(0xFF263B56), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.dashboard_rounded, label: 'Home', selected: index == 0, onTap: () => _onItemTapped(0, context)),
                _NavItem(icon: Icons.folder_rounded, label: 'Records', selected: index == 1, onTap: () => _onItemTapped(1, context)),
                _NavItem(icon: Icons.timeline_rounded, label: 'Timeline', selected: index == 2, onTap: () => _onItemTapped(2, context)),
                // Consent tab with live badge
                _NavItem(
                  icon: Icons.health_and_safety_rounded,
                  label: 'Access',
                  selected: index == 3,
                  onTap: () => _onItemTapped(3, context),
                  badge: pendingCount > 0 ? pendingCount : null,
                ),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: index == 4, onTap: () => _onItemTapped(4, context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00C9A7).withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: selected ? const Color(0xFF00C9A7) : const Color(0xFF8BA0B8),
                  size: 24,
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge! > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF00C9A7) : const Color(0xFF8BA0B8),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
