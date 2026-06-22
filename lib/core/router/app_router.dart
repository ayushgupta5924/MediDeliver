// import 'package:go_router/go_router.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';

// import '../../features/patient/presentation/patient_upload_screen.dart'; // Add this import
// import '../../features/pharmacist/presentation/pharmacist_dashboard_screen.dart';
// import '../../main.dart';

// part 'app_router.g.dart';

// @riverpod
// GoRouter goRouter(GoRouterRef ref) {
//   return GoRouter(
//     initialLocation: '/',
//     routes: [
//       GoRoute(
//         path: '/',
//         builder: (context, state) => const RoleSelectorScreen(),
//       ),
//       GoRoute(
//         path: '/pharmacist',
//         builder: (context, state) => const PharmacistDashboardScreen(),
//       ),
//       // Add this new route for the patient screen
//       GoRoute(
//         path: '/patient',
//         builder: (context, state) => const PatientUploadScreen(),
//       ),
//     ],
//   );
// }
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/role_selector_screen.dart';
import '../../features/patient/presentation/patient_upload_screen.dart';
import '../../features/pharmacist/presentation/pharmacist_dashboard_screen.dart';

// import '../../main.dart';

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
    ],
  );
}
