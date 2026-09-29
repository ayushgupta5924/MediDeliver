import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medideliver/core/services/auth_service.dart';
import 'package:medideliver/features/auth/presentation/phone_entry_screen.dart';
import 'package:medideliver/features/auth/presentation/otp_screen.dart';

class FakeAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(pendingEmail: 'fictional@example.invalid', otpSent: true);
  void fail() => state = state.copyWith(error: 'Try again');
}

void main() {
  testWidgets(
    'email input survives auth state updates and offers no privilege selector',
    (tester) async {
      final auth = FakeAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: PhoneEntryScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'customer@example.invalid',
      );
      auth.fail();
      await tester.pump();
      expect(find.text('customer@example.invalid'), findsOneWidget);
      expect(find.text('Pharmacy'), findsNothing);
      expect(find.text('Rider'), findsNothing);
    },
  );
  testWidgets(
    'OTP remains populated after failed verification and disposes timer',
    (tester) async {
      final auth = FakeAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: OtpScreen()),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      auth.fail();
      await tester.pump();
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
