import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';
import 'supabase_provider.dart';

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

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.otpSent = false,
    this.pendingEmail,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool? otpSent,
    String? pendingEmail,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      otpSent: otpSent ?? this.otpSent,
      pendingEmail: pendingEmail ?? this.pendingEmail,
    );
  }
}

// ── Auth Notifier ──────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  SupabaseClient get _client => ref.read(supabaseProvider);
  int _revision = 0;

  @override
  AuthState build() {
    final subscription = _client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        _revision++;
        state = const AuthState();
      }
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(_checkSession);
    return const AuthState(isLoading: true);
  }

  Future<void> _checkSession() async {
    final revision = ++_revision;
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      if (ref.mounted) state = const AuthState();
      return;
    }
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .single();
      if (ref.mounted && revision == _revision) {
        state = AuthState(user: AppUser.fromMap(profile));
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = const AuthState(
          error: 'Unable to load your account. Please sign in again.',
        );
      }
    }
  }

  Future<void> sendOtp({required String email}) async {
    if (state.isLoading) return;
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      state = state.copyWith(error: 'Enter a valid email address.');
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      // All signups receive customer access. Staff roles are provisioned by an operator.
      await _client.auth.signInWithOtp(
        email: normalized,
        shouldCreateUser: true,
      );
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          otpSent: true,
          pendingEmail: normalized,
        );
      }
    } on AuthException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, error: e.message);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not send code. Please try again.',
        );
      }
    }
  }

  Future<void> verifyOtp({required String otp}) async {
    if (state.isLoading || state.pendingEmail == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      state = state.copyWith(error: 'Enter the complete six-digit code.');
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final response = await _client.auth.verifyOTP(
        email: state.pendingEmail!,
        token: otp,
        type: OtpType.email,
      );
      if (response.user == null) {
        throw const AuthException('Verification failed');
      }
      // Profile creation is an atomic database trigger, never a client role upsert.
      await _checkSession();
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Code expired or incorrect. Try again or request a new code.',
        );
      }
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _revision++;
    if (ref.mounted) state = const AuthState();
  }

  void resetOtp() {
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
