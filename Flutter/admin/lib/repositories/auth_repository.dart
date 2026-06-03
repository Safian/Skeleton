import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

// ============================================================
// AuthRepository – Supabase auth + user_profiles CRUD
// ============================================================

class AuthRepository {
  final SupabaseClient _db;

  AuthRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  // ── Auth state ───────────────────────────────────────────
  Stream<AuthState> get authStateChanges => _db.auth.onAuthStateChange;
  User? get currentUser => _db.auth.currentUser;

  // ── Sign in / up / out ───────────────────────────────────
  Future<void> signInWithEmailPassword(String email, String password) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> registerWithEmailPassword(String email, String password) async {
    await _db.auth.signUp(email: email, password: password);
  }

  Future<void> resetPassword(String email) async {
    await _db.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
  }

  // ── Profile ──────────────────────────────────────────────
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final res = await _db
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserProfile.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null)   'avatar_url':   avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _db.from('user_profiles').update(updates).eq('id', userId);
  }

  // ── Health check (maintenance mode detection) ─────────────
  Future<bool> isInMaintenance() async {
    try {
      // app_config anon-olvasható – nem kell hozzá bejelentkezés.
      // Maintenance esetén a DB 503-at ad vissza.
      await _db.from('app_config').select('key').limit(1);
      return false;
    } on PostgrestException catch (e) {
      return e.code == '503';
    } catch (e) {
      return e.toString().contains('503');
    }
  }
}
