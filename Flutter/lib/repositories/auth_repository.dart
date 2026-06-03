import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

// ============================================================
// AuthRepository – Supabase auth + user_profiles CRUD
// Social login: Google OAuth + Apple (Supabase beépített flow)
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

  // ── Első admin regisztráció ──────────────────────────────────
  /// Visszaadja, hogy ez az első indítás-e (nincs még egyetlen user sem).
  Future<bool> isFirstSetup() async {
    try {
      final result = await _db.rpc('is_first_setup');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Létrehozza az első admint email-jóváhagyás nélkül,
  /// majd automatikusan bejelentkezteti.
  Future<void> registerFirstAdmin(String email, String password) async {
    final response = await _db.functions.invoke(
      'register-first-admin',
      body: {'email': email, 'password': password},
    );

    if (response.status != 200) {
      final data = response.data as Map?;
      throw Exception(data?['error'] ?? 'Ismeretlen hiba');
    }

    final data = response.data as Map?;
    final session = data?['session'] as Map?;
    if (session == null) throw Exception('Nem érkezett session');

    await _db.auth.setSession(session['refresh_token'] as String);
  }

  Future<void> resetPassword(String email) async {
    await _db.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
  }

  // ── Social Login ─────────────────────────────────────────
  //
  // ELŐFELTÉTELEK:
  // 1. Supabase Dashboard → Authentication → Providers → Google/Apple bekapcsolva
  // 2. Google: Client ID + Secret a Supabase dashboardon
  // 3. Apple: Service ID + Team ID + Key ID + Private Key a Supabase dashboardon
  // 4. pubspec.yaml: (csak ha natív flow kell – Supabase OAuth web flow-val nem kell extra csomag)
  //    - google_sign_in: ^6.x (Android/iOS natív)
  //    - sign_in_with_apple: ^6.x (iOS/macOS natív)
  //
  // Jelenleg Supabase OAuth redirect flow-t használunk (platform-agnosztikus):
  // Az auth-callback deep link a supabase_flutter-ben automatikusan kezelve van,
  // ha az AndroidManifest.xml / Info.plist megfelelően van konfigurálva.

  /// Google OAuth – Supabase redirect flow
  Future<void> signInWithGoogle() async {
    await _db.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.platformDefault,
    );
  }

  /// Apple OAuth – Supabase redirect flow
  Future<void> signInWithApple() async {
    await _db.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.platformDefault,
    );
  }

  /// Deep link redirect URL – egyezzen a Supabase és az app konfigurációjával.
  /// Format: io.supabase.<your_app>://login-callback/
  /// Állítsd be a .env fájlban: OAUTH_REDIRECT_URL=...
  String get _oauthRedirectUrl {
    // Android: intent-filter + iOS: CFBundleURLSchemes
    // Példa: 'io.supabase.skeleton://login-callback/'
    return const String.fromEnvironment(
      'OAUTH_REDIRECT_URL',
      defaultValue: 'io.supabase.skeleton://login-callback/',
    );
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
      await _db.from('user_profiles').select('id').limit(1);
      return false;
    } on PostgrestException catch (e) {
      return e.code == '503';
    } catch (e) {
      return e.toString().contains('503');
    }
  }
}
