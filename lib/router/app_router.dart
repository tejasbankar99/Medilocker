import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/timeline/timeline_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/documents/upload_document_screen.dart';
import '../screens/documents/document_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/consent/consent_screen.dart';
import '../screens/consent/approve_consent_screen.dart';
import '../screens/audit/audit_log_screen.dart';
import '../models/consent_request.dart';
import '../models/medical_document.dart';

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isEmailConfirmed = authProvider.isEmailConfirmed;
        final loc = state.matchedLocation;

        final isSplash = loc == '/';
        final isAuthRoute = loc == '/login' || loc == '/register';
        final isVerifyRoute = loc == '/verify-email';

        if (isSplash) return null;

        // Not logged in at all → send to login
        if (!isAuthenticated && !isAuthRoute && !isVerifyRoute) return '/login';

        // Logged in but email NOT confirmed → block home, go to verify screen
        if (isAuthenticated && !isEmailConfirmed && !isVerifyRoute) {
          return '/verify-email';
        }

        // Fully authenticated & confirmed → skip auth/verify screens
        if (isAuthenticated && isEmailConfirmed && (isAuthRoute || isVerifyRoute)) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return VerifyEmailScreen(email: email);
          },
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsScreen(),
              routes: [
                GoRoute(
                  path: 'upload',
                  builder: (context, state) => const UploadDocumentScreen(),
                ),
                GoRoute(
                  path: 'detail',
                  builder: (context, state) {
                    final doc = state.extra as MedicalDocument;
                    return DocumentDetailScreen(document: doc);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/timeline',
              builder: (context, state) => const TimelineScreen(),
            ),
            GoRoute(
              path: '/consent',
              builder: (context, state) => const ConsentScreen(),
            ),
            GoRoute(
              path: '/consent/approve',
              builder: (context, state) {
                final req = state.extra as ConsentRequest;
                return ApproveConsentScreen(request: req);
              },
            ),
            GoRoute(
              path: '/audit-logs',
              builder: (context, state) => const AuditLogScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Page not found: ${state.error}')),
      ),
    );
  }
}
