import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class PhoneEntryScreen extends HookConsumerWidget {
  const PhoneEntryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = useTextEditingController();
    final auth = ref.watch(authProvider);
    ref.listen(authProvider, (previous, next) {
      if (next.otpSent && !(previous?.otpSent ?? false)) context.go('/otp');
    });
    return Scaffold(
      appBar: AppBar(title: const Text('MediDeliver')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Sign in with email',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'We will email you a six-digit verification code. Pharmacy and delivery accounts require approval.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: email,
                enabled: !auth.isLoading,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isLoading
                    ? null
                    : () => ref
                          .read(authProvider.notifier)
                          .sendOtp(email: email.text),
                child: Text(auth.isLoading ? 'Sending…' : 'Send code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
