import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/auth/presentation/role_selector_screen.dart';
import '../../features/patient/presentation/patient_upload_screen.dart';
import '../../features/pharmacist/presentation/pharmacist_dashboard_screen.dart';
import '../../features/rider/presentation/rider_dashboard_screen.dart';
import '../services/auth_service.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Still loading — don't redirect
      if (authState.isLoading) return null;

      final isAuthenticated = authState.isAuthenticated;
      final isOnAuthRoute =
          state.matchedLocation == '/' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp';

      // Not authenticated → send to login
      if (!isAuthenticated && !isOnAuthRoute) return '/login';

      // Authenticated but on auth route → send to role home
      if (isAuthenticated && isOnAuthRoute) {
        return _homeForRole(authState.user!.role);
      }

      return null;
    },
    routes: [
      // Role selector (shown before login in dev mode)
      GoRoute(
        path: '/',
        builder: (context, state) => const RoleSelectorScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),

      // Role home routes
      GoRoute(
        path: '/patient',
        builder: (context, state) => const PatientUploadScreen(),
      ),
      GoRoute(
        path: '/pharmacist',
        builder: (context, state) => const PharmacistDashboardScreen(),
      ),
      GoRoute(
        path: '/rider',
        builder: (context, state) => const RiderDashboardScreen(),
      ),
    ],
  );
}

String _homeForRole(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return '/patient';
    case UserRole.pharmacyOwner:
      return '/pharmacist';
    case UserRole.deliveryPartner:
      return '/rider';
    case UserRole.admin:
      return '/patient';
  }
}
