import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/consent_request.dart';
import '../../models/medical_document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consent_provider.dart';
import '../../theme/app_theme.dart';

class ApproveConsentScreen extends StatefulWidget {
  final ConsentRequest request;
  const ApproveConsentScreen({super.key, required this.request});

  @override
  State<ApproveConsentScreen> createState() => _ApproveConsentScreenState();
}

class _ApproveConsentScreenState extends State<ApproveConsentScreen> {
  // Step 1: Configure, Step 2: OTP
  int _step = 1;

  String _scope = 'all';
  String? _scopeValue;
  int _durationDays = 7;

  // OTP state
  String? _otpId;
  String? _patientEmail;   // shown when via == 'email'
  String? _screenOtp;      // shown when Edge Function not deployed (fallback)
  String _otpVia = 'email'; // 'email' | 'screen'
  final _otpCtrl = TextEditingController();
  bool _isWorking = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateOtp() async {
    setState(() => _isWorking = true);
    final uid = context.read<AuthProvider>().user?.id ?? '';
    final result = await context.read<ConsentProvider>().generateOtp(
      uid,
      widget.request.id,
      doctorName: widget.request.doctorName,
    );
    setState(() => _isWorking = false);

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send code. Check your connection.')),
        );
      }
      return;
    }

    setState(() {
      _otpId    = result['otpId'];
      _otpVia   = result['via'] ?? 'email';
      _patientEmail = result['email'];
      _screenOtp    = result['otpCode']; // only set in fallback mode
      _step = 2;
    });
  }

  Future<void> _verifyAndApprove() async {
    if (_otpId == null) return;
    setState(() => _isWorking = true);
    final consent = context.read<ConsentProvider>();
    final ok = await consent.verifyOtpAndGrant(
      otpId: _otpId!,
      enteredCode: _otpCtrl.text,
      request: widget.request,
      scope: _scope,
      scopeValue: _scopeValue,
      durationDays: _durationDays,
    );
    setState(() => _isWorking = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Access granted to ${widget.request.doctorName ?? "Doctor"} for $_durationDays days.'),
          backgroundColor: AppTheme.primary,
        ),
      );
      context.go('/consent');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(consent.error ?? 'Verification failed.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  /// Masks email: john@gmail.com → j***n@gmail.com
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Access Request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _step == 2
              ? () => setState(() => _step = 1)
              : () => context.go('/consent'),
        ),
      ),
      body: _step == 1 ? _buildConfigure() : _buildOtpStep(),
    );
  }

  Widget _buildConfigure() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppTheme.secondary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      color: AppTheme.secondary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.doctorName ?? 'Unknown Doctor',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      Text(
                        [
                          widget.request.doctorSpecialty,
                          widget.request.doctorHospital
                        ].where((s) => s != null).join(' · '),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purpose: ${widget.request.purpose}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const _SectionLabel('What can this doctor access?'),
          const SizedBox(height: 12),

          // Scope selector
          _ScopeOption(
            title: 'All Records',
            subtitle: 'Doctor can see all your medical documents',
            icon: Icons.folder_open_rounded,
            selected: _scope == 'all',
            onTap: () => setState(() {
              _scope = 'all';
              _scopeValue = null;
            }),
          ),
          const SizedBox(height: 8),
          _ScopeOption(
            title: 'By Category',
            subtitle: 'Limit to a specific document type',
            icon: Icons.category_rounded,
            selected: _scope == 'category',
            onTap: () => setState(() {
              _scope = 'category';
              _scopeValue = MedicalDocument.categories.first;
            }),
          ),
          if (_scope == 'category') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _scopeValue ?? MedicalDocument.categories.first,
              dropdownColor: AppTheme.card,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Select Category',
                isDense: true,
                prefixIcon: Icon(Icons.category_rounded,
                    color: AppTheme.textSecondary, size: 18),
              ),
              items: MedicalDocument.categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _scopeValue = v),
            ),
          ],

          const SizedBox(height: 24),
          const _SectionLabel('How long can they access?'),
          const SizedBox(height: 12),

          // Duration chips
          Wrap(
            spacing: 10,
            children: [1, 3, 7, 14, 30, 90].map((d) {
              final selected = _durationDays == d;
              return ChoiceChip(
                label: Text('$d day${d == 1 ? '' : 's'}'),
                selected: selected,
                selectedColor: AppTheme.primary.withOpacity(0.2),
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.border,
                ),
                onSelected: (_) => setState(() => _durationDays = d),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Security notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: const [
                Icon(Icons.security_rounded,
                    color: AppTheme.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You will need to verify with an OTP code in the next step. Access can be revoked anytime.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isWorking ? null : _generateOtp,
              child: _isWorking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Continue to Verify'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verify Your Approval',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Enter the verification code below to confirm access approval.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),

          const SizedBox(height: 28),

          // ── Email mode: code sent via Resend ──────────────────────────
          if (_otpVia == 'email')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mark_email_read_rounded,
                      color: AppTheme.primary, size: 40),
                  const SizedBox(height: 12),
                  const Text('Code Sent to Your Email',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    _patientEmail != null && _patientEmail!.isNotEmpty
                        ? _maskEmail(_patientEmail!)
                        : 'your registered email',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your inbox for a 6-digit code.\nValid for 10 minutes.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── Fallback mode: show code on screen ───────────────────────────
          if (_otpVia == 'screen' && _screenOtp != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      color: AppTheme.warning, size: 36),
                  const SizedBox(height: 10),
                  const Text('Your Verification Code',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    _screenOtp!,
                    style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Valid for 10 minutes.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // OTP input
          TextField(
            controller: _otpCtrl,
            onChanged: (_) => setState(() {}), // re-evaluate button state
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 8),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.4),
                  letterSpacing: 8),
            ),
          ),

          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Enter the 6-digit code above',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isWorking || _otpCtrl.text.length < 6
                  ? null
                  : _verifyAndApprove,
              child: _isWorking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Confirm Approval'),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: _isWorking ? null : _generateOtp,
              child: const Text('Resend Code',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.08)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected ? AppTheme.primary : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primary, size: 20),
          ],
        ),
      ),
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
            fontSize: 13,
            fontWeight: FontWeight.w600),
      );
}
