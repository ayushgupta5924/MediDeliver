import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class OtpScreen extends HookConsumerWidget {
  const OtpScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = useTextEditingController();
    final remaining = useState(60);
    final auth = ref.watch(authProvider);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (remaining.value > 0) remaining.value--;
      });
      return timer.cancel;
    }, const []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: auth.isLoading
              ? null
              : () {
                  ref.read(authProvider.notifier).resetOtp();
                  context.go('/login');
                },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Enter the code sent to ${auth.pendingEmail ?? "your email"}',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                enabled: !auth.isLoading,
                maxLength: 6,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                ),
              ),
              if (auth.error != null)
                Text(auth.error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: auth.isLoading
                    ? null
                    : () => ref
                          .read(authProvider.notifier)
                          .verifyOtp(otp: code.text),
                child: Text(
                  auth.isLoading ? 'Verifying…' : 'Verify & continue',
                ),
              ),
              TextButton(
                onPressed:
                    remaining.value > 0 ||
                        auth.isLoading ||
                        auth.pendingEmail == null
                    ? null
                    : () async {
                        remaining.value = 60;
                        await ref
                            .read(authProvider.notifier)
                            .sendOtp(email: auth.pendingEmail!);
                      },
                child: Text(
                  remaining.value > 0
                      ? 'Resend in ${remaining.value}s'
                      : 'Resend code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
