import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

// ── User Role ──────────────────────────────────────

enum UserRole {
  customer,
  pharmacyOwner,
  deliveryPartner,
  admin;

  static UserRole fromString(String value) {
    switch (value) {
      case 'pharmacy_owner':
        return UserRole.pharmacyOwner;
      case 'delivery_partner':
        return UserRole.deliveryPartner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }

  String get value {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.pharmacyOwner:
        return 'pharmacy_owner';
      case UserRole.deliveryPartner:
        return 'delivery_partner';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.pharmacyOwner:
        return 'Pharmacist';
      case UserRole.deliveryPartner:
        return 'Delivery Partner';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

// ── App User ───────────────────────────────────────

class AppUser {
  final String id;
  final String email;
  final String? fullName;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String?,
      role: UserRole.fromString(map['role'] as String? ?? 'customer'),
    );
  }
}

// ── Auth State ─────────────────────────────────────

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;
  final bool otpSent;
  final String? pendingEmail;
  final UserRole? pendingRole;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.otpSent = false,
    this.pendingEmail,
    this.pendingRole,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool? otpSent,
    String? pendingEmail,
    UserRole? pendingRole,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      otpSent: otpSent ?? this.otpSent,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingRole: pendingRole ?? this.pendingRole,
    );
  }
}

// ── Auth Notifier ──────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkSession();
    return const AuthState(isLoading: true);
  }

  Future<void> _checkSession() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      state = const AuthState();
      return;
    }
    try {
      final profile =
          await supabase
              .from('profiles')
              .select()
              .eq('id', session.user.id)
              .single();
      state = AuthState(user: AppUser.fromMap(profile));
    } catch (_) {
      state = const AuthState();
    }
  }

  // ── Send OTP to email ──────────────────────────────

  Future<void> sendOtp({required String email, required UserRole role}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await supabase.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        // Pass role so the trigger creates profile correctly
        emailRedirectTo: null,
        data: {'role': role.value},
        shouldCreateUser: true,
      );

      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        pendingEmail: email.trim().toLowerCase(),
        pendingRole: role,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send OTP. Check your email address.',
      );
    }
  }

  // ── Verify OTP ─────────────────────────────────────

  Future<void> verifyOtp({required String otp}) async {
    if (state.pendingEmail == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase.auth.verifyOTP(
        email: state.pendingEmail!,
        token: otp,
        type: OtpType.email,
      );

      if (response.user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Verification failed. Please try again.',
        );
        return;
      }

      // Wait briefly for the trigger to create the profile
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch or create profile
      Map<String, dynamic>? profile;
      try {
        profile =
            await supabase
                .from('profiles')
                .select()
                .eq('id', response.user!.id)
                .single();
      } catch (_) {
        // Profile not created by trigger yet — create manually
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'email': state.pendingEmail,
          'role': state.pendingRole?.value ?? 'customer',
        });
        profile =
            await supabase
                .from('profiles')
                .select()
                .eq('id', response.user!.id)
                .single();
      }

      state = AuthState(user: AppUser.fromMap(profile));
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Incorrect OTP. Please try again.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  // ── Logout ─────────────────────────────────────────

  Future<void> logout() async {
    await supabase.auth.signOut();
    state = const AuthState();
  }

  void resetOtp() {
    state = state.copyWith(
      otpSent: false,
      pendingEmail: null,
      pendingRole: null,
      error: null,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
