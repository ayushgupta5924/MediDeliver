import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/timeout_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConstants.isConfigured) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'MediDeliver is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      publishableKey: SupabaseConstants.supabaseAnonKey,
      httpClient: TimeoutClient(),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not start MediDeliver. Check your connection and reopen the app.',
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: MediDeliverApp()));
}

class MediDeliverApp extends HookConsumerWidget {
  const MediDeliverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'MediDeliver',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => Column(
        children: [
          if (SupabaseConstants.demoMode)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'DEMO — Fictional pharmacy and orders. No medicines will be delivered. Use sample information only.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
    );
  }
}
