import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/patient/presentation/patient_upload_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../services/auth_service.dart';

String homeForRole(UserRole role) => switch (role) {
  UserRole.customer => '/patient',
  UserRole.pharmacyOwner => '/pharmacist',
  UserRole.deliveryPartner => '/rider',
  UserRole.admin => '/admin',
};

String? authRedirect(AuthState auth, String path) {
  final authRoute = ['/', '/login', '/otp', '/loading'].contains(path);
  if (auth.isLoading && !auth.isAuthenticated) {
    return authRoute ? null : '/loading';
  }
  if (!auth.isAuthenticated) {
    if (path == '/otp' && auth.pendingEmail == null) return '/login';
    return path == '/login' || path == '/otp' ? null : '/login';
  }
  final home = homeForRole(auth.user!.role);
  if (authRoute) return home;
  final allowed =
      path == home ||
      (auth.user!.role == UserRole.customer && path == '/orders');
  return allowed ? null : home;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (_, state) =>
        authRedirect(ref.read(authProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PhoneEntryScreen()),
      GoRoute(path: '/login', builder: (_, _) => const PhoneEntryScreen()),
      GoRoute(path: '/otp', builder: (_, _) => const OtpScreen()),
      GoRoute(
        path: '/loading',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/patient', builder: (_, _) => const PatientUploadScreen()),
      for (final path in ['/orders', '/pharmacist', '/rider', '/admin'])
        GoRoute(path: path, builder: (_, _) => const OrdersScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
