import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _resending = false;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Poll for email confirmation every 3 seconds
    _startPolling();
  }

  void _startPolling() async {
    final auth = context.read<AuthProvider>();
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) break;
      final confirmed = await auth.checkEmailConfirmed();
      if (confirmed && mounted) {
        context.go('/home');
        break;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _resent = false; });
    final ok = await context.read<AuthProvider>().resendConfirmationEmail(widget.email);
    setState(() { _resending = false; _resent = ok; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated envelope icon
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mark_email_unread_rounded,
                      color: AppTheme.primary, size: 48),
                ),
              ),
              const SizedBox(height: 36),

              const Text(
                'Verify Your Email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
                  children: [
                    const TextSpan(text: 'We sent a confirmation link to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Click the link in your email to confirm your account. This page will automatically redirect you once confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 12),

              // Auto-checking indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Checking automatically...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Resend button
              if (_resent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Email sent! Check your inbox.',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _resending ? null : _resend,
                    icon: _resending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(_resending ? 'Sending...' : 'Resend Confirmation Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: () {
                  context.read<AuthProvider>().signOut();
                  context.go('/login');
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.textSecondary),
                label: const Text('Back to Sign In',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
