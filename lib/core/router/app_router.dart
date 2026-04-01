import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/screens/user_home_screen.dart';
import '../../features/services/screens/service_listing_screen.dart';
import '../../features/services/screens/provider_profile_screen.dart';
import '../../features/booking/screens/booking_screen.dart';
import '../../features/booking/screens/booking_confirmation_screen.dart';
import '../../features/booking/screens/booking_detail_screen.dart';
import '../../features/provider_dashboard/screens/provider_home_screen.dart';
import '../../features/provider_dashboard/screens/provider_onboarding_screen.dart';
import '../../features/maps/screens/map_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/user_dashboard/screens/user_dashboard_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import 'shell_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const userHome = '/home';
  static const serviceListing = '/services';
  static const providerProfile = '/provider/:providerId';
  static const booking = '/booking/:providerId';
  static const bookingConfirmation = '/booking-confirmation/:bookingId';
  static const bookingDetail = '/booking-detail/:bookingId';
  static const providerDashboard = '/dashboard';
  static const providerOnboarding = '/provider-onboarding';
  static const map = '/map';
  static const notifications = '/notifications';
  static const userDashboard = '/account';
  static const chat = '/chat/:otherUserId';
  static const adminDashboard = '/admin';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isOnAuth = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.splash;
      if (!isLoggedIn && !isOnAuth) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (c, s) => const SignupScreen()),
      GoRoute(path: AppRoutes.providerOnboarding, builder: (c, s) => const ProviderOnboardingScreen()),
      GoRoute(path: AppRoutes.providerDashboard, builder: (c, s) => const ProviderHomeScreen()),
      GoRoute(path: AppRoutes.notifications, builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: AppRoutes.adminDashboard, builder: (c, s) => const AdminDashboardScreen()),
      GoRoute(
        path: AppRoutes.providerProfile,
        builder: (c, s) => ProviderProfileScreen(providerId: s.pathParameters['providerId']!),
      ),
      GoRoute(
        path: AppRoutes.booking,
        builder: (c, s) => BookingScreen(providerId: s.pathParameters['providerId']!),
      ),
      GoRoute(
        path: AppRoutes.bookingConfirmation,
        builder: (c, s) => BookingConfirmationScreen(bookingId: s.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: AppRoutes.bookingDetail,
        builder: (c, s) => BookingDetailScreen(bookingId: s.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (c, s) => ChatScreen(
          otherUserId: s.pathParameters['otherUserId']!,
          otherUserName: s.uri.queryParameters['name'] ?? 'User',
        ),
      ),
      ShellRoute(
        builder: (c, s, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: AppRoutes.userHome, builder: (c, s) => const UserHomeScreen()),
          GoRoute(
            path: AppRoutes.serviceListing,
            builder: (c, s) => ServiceListingScreen(category: s.uri.queryParameters['category'] ?? ''),
          ),
          GoRoute(path: AppRoutes.map, builder: (c, s) => const MapScreen()),
          GoRoute(path: AppRoutes.userDashboard, builder: (c, s) => const UserDashboardScreen()),
        ],
      ),
    ],
    errorBuilder: (c, s) => Scaffold(body: Center(child: Text('Page not found: ${s.error}'))),
  );
});
