import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedBloodType;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Password strength state (0–4)
  int _strength = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Password strength calculator ──────────────────────────────────────────
  int _calcStrength(String p) {
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'))) score++;
    return score;
  }

  String _strengthLabel(int s) =>
      ['', 'Weak', 'Fair', 'Good', 'Strong'][s];

  Color _strengthColor(int s) => [
    Colors.transparent,
    const Color(0xFFFF6B6B),
    const Color(0xFFFFB74D),
    const Color(0xFF4FC3F7),
    const Color(0xFF00C9A7),
  ][s];

  // ── Email regex (7): strict format ────────────────────────────────────────
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final result = await auth.signUpWithResult(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _nameCtrl.text.trim(),
      bloodType: _selectedBloodType,
      phoneNumber: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text.trim(),
    );
    if (!mounted) return;

    switch (result) {
      case SignUpResult.signedIn:
        context.go('/home');
        break;
      case SignUpResult.needsConfirmation:
        context.go('/verify-email?email=${Uri.encodeComponent(_emailCtrl.text.trim())}');
        break;
      case SignUpResult.error:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) => Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Personal Information ───────────────────────────────
                  _SectionLabel('Personal Information'),
                  const SizedBox(height: 16),

                  // Full Name
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Full name is required';
                      if (v.trim().length < 2) return 'Name must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Email — strict regex (change #7)
                  TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!_emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email (e.g. name@gmail.com)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Phone — Indian 10-digit format (change #11)
                  TextFormField(
                    controller: _phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (optional)',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                      prefixText: '+91  ',
                      prefixStyle: TextStyle(color: AppTheme.textSecondary),
                      counterText: '',
                      hintText: '10-digit mobile number',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // optional
                      if (v.length != 10) return 'Enter a valid 10-digit mobile number';
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                        return 'Indian mobile numbers start with 6, 7, 8 or 9';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Medical Information ────────────────────────────────
                  _SectionLabel('Medical Information'),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedBloodType,
                    dropdownColor: AppTheme.card,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Blood Type (optional)',
                      prefixIcon: Icon(Icons.bloodtype_outlined, color: AppTheme.textSecondary),
                    ),
                    items: UserProfile.bloodTypes.map((bt) => DropdownMenuItem(
                      value: bt,
                      child: Text(bt),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedBloodType = v),
                  ),

                  const SizedBox(height: 24),

                  // ── Security ───────────────────────────────────────────
                  _SectionLabel('Security'),
                  const SizedBox(height: 16),

                  // Password field with strength meter (changes #1, 2, 3, 4)
                  TextFormField(
                    controller: _passwordCtrl,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscurePassword,
                    onChanged: (v) => setState(() => _strength = _calcStrength(v)),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Minimum 8 characters required';
                      if (!v.contains(RegExp(r'[A-Z]'))) return 'Must contain at least 1 uppercase letter';
                      if (!v.contains(RegExp(r'[0-9]'))) return 'Must contain at least 1 number';
                      return null;
                    },
                  ),

                  // ── Strength meter ─────────────────────────────────────
                  if (_passwordCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PasswordStrengthBar(strength: _strength, color: _strengthColor(_strength), label: _strengthLabel(_strength)),
                    const SizedBox(height: 8),
                    // Requirements checklist
                    _RequirementRow('At least 8 characters', _passwordCtrl.text.length >= 8),
                    _RequirementRow('At least 1 uppercase letter', _passwordCtrl.text.contains(RegExp(r'[A-Z]'))),
                    _RequirementRow('At least 1 number', _passwordCtrl.text.contains(RegExp(r'[0-9]'))),
                  ],

                  const SizedBox(height: 14),

                  // Confirm password
                  TextFormField(
                    controller: _confirmCtrl,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm your password';
                      if (v != _passwordCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),

                  // Error banner
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.error.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(auth.error!,
                              style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _register,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? ',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600,
    ),
  );
}

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  final Color color;
  final String label;
  const _PasswordStrengthBar({required this.strength, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < strength ? color : AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        if (strength > 0)
          Text(
            'Password strength: $label',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;
  final bool met;
  const _RequirementRow(this.text, this.met);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey(met),
              color: met ? AppTheme.primary : AppTheme.textSecondary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? AppTheme.primary : AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
