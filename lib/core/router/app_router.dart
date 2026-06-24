import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/role_selector_screen.dart';
import '../../features/patient/presentation/patient_upload_screen.dart';
import '../../features/pharmacist/presentation/pharmacist_dashboard_screen.dart';
import '../../features/rider/presentation/rider_dashboard_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RoleSelectorScreen(),
      ),
      GoRoute(
        path: '/pharmacist',
        builder: (context, state) => const PharmacistDashboardScreen(),
      ),
      GoRoute(
        path: '/patient',
        builder: (context, state) => const PatientUploadScreen(),
      ),
      GoRoute(
        path: '/rider',
        builder: (context, state) => const RiderDashboardScreen(),
      ),
    ],
  );
}
