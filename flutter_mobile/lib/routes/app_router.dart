import 'package:go_router/go_router.dart';

import '../features/authentication/login/login_screen.dart';
import '../features/authentication/register/register_screen.dart';
import '../features/dashboard/dashboard_shell.dart';
import '../features/profile/profile_screen.dart';
import '../features/society/society_screen.dart';
import '../features/splash/splash_screen.dart';
import '../providers/auth_provider.dart';
import '../features/dashboard/sos_detail_screen.dart';
import '../models/notification_model.dart';
import '../features/dashboard/sos_message_screen.dart';
import '../features/dashboard/sos_review_screen.dart';
import '../features/dashboard/sos_success_screen.dart';

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
        final isSplash = state.matchedLocation == '/splash';

        if (!authProvider.isReady) {
          return isSplash ? null : '/splash';
        }

        if (!authProvider.isAuthenticated && !isLoggingIn) {
          return '/login';
        }

        if (authProvider.isAuthenticated && isLoggingIn) {
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
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
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
            final notification = state.extra as AppNotificationModel;
            return SOSDetailScreen(notification: notification);
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
      ],
    );
  }
}

