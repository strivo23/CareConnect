import 'package:go_router/go_router.dart';

import '../features/authentication/login/login_screen.dart';
import '../features/authentication/register/register_screen.dart';
import '../features/authentication/otp_verify/otp_verify_screen.dart';
import '../features/authentication/forgot_password/forgot_password_screen.dart';
import '../features/dashboard/dashboard_shell.dart';
import '../features/profile/profile_screen.dart';
import '../features/society/society_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/landing/landing_screen.dart';
import '../features/language/language_screen.dart';
import '../providers/auth_provider.dart';
import '../features/dashboard/sos_detail_screen.dart';
import '../models/notification_model.dart';
import '../features/dashboard/sos_message_screen.dart';
import '../features/dashboard/sos_review_screen.dart';
import '../features/dashboard/sos_success_screen.dart';
import '../features/dashboard/assigned_incident_screen.dart';
import '../features/chat/emergency_chat_screen.dart';

class AppRouter {
  static GoRouter? _router;

  static GoRouter router(AuthProvider authProvider) {
    return _router ??= GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isUnauthenticatedRoute = state.matchedLocation == '/landing' ||
            state.matchedLocation == '/language' ||
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/otp-verify' ||
            state.matchedLocation == '/forgot-password';
        final isSplash = state.matchedLocation == '/splash';

        if (!authProvider.isReady) {
          return isSplash ? null : '/splash';
        }

        if (!authProvider.isAuthenticated && !isUnauthenticatedRoute && !isSplash) {
          return '/landing';
        }

        if (authProvider.isAuthenticated && (state.matchedLocation == '/login' || state.matchedLocation == '/register')) {
          return '/home';
        }

        if (authProvider.isAuthenticated && isSplash) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/landing',
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(
          path: '/language',
          builder: (context, state) => const LanguageScreen(),
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
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/otp-verify',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>;
            return OTPVerificationScreen(
              email: args['email'] as String,
            );
          },
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const DashboardShell(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/society',
          builder: (context, state) => const SocietyScreen(),
        ),
        GoRoute(
          path: '/sos-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is AppNotificationModel) {
              return SOSDetailScreen(notification: extra);
            } else if (extra is Map<String, dynamic>) {
              return SOSDetailScreen(notification: AppNotificationModel.fromJson(extra));
            }
            return SOSDetailScreen(
              notification: AppNotificationModel(
                id: '0',
                title: 'SOS Alert',
                message: 'SOS Details',
                category: 'sos',
                isRead: false,
                createdAt: DateTime.now(),
              ),
            );
          },
        ),
        GoRoute(
          path: '/sos-message',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>;
            return SOSMessageScreen(
              latitude: args['latitude'] as double,
              longitude: args['longitude'] as double,
              address: args['address']?.toString() ?? '',
            );
          },
        ),
        GoRoute(
          path: '/sos-review',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            return SOSReviewScreen(data: data);
          },
        ),
        GoRoute(
          path: '/sos-success',
          builder: (context, state) {
            final incidentData = state.extra as Map<String, dynamic>;
            return SOSSuccessScreen(incidentData: incidentData);
          },
        ),
        GoRoute(
          path: '/assigned-incident',
          builder: (context, state) {
            final incidentData = state.extra as Map<String, dynamic>;
            return AssignedIncidentScreen(incidentData: incidentData);
          },
        ),
        GoRoute(
          path: '/emergency-chat',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>;
            return EmergencyChatScreen(incidentData: args);
          },
        ),
      ],
    );
  }
}
