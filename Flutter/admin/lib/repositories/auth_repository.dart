import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/secure_storage_service.dart';

// ============================================================
// AuthRepository – Supabase auth + user_profiles CRUD
//
// [M2.1] Token-ek mentése FlutterSecureStorage-ba (iOS Keychain /
//         Android Keystore) login / token-refresh eseményekkor.
// ============================================================

class AuthRepository {
  final SupabaseClient _db;
  final SecureStorageService _secure;

  AuthRepository({SupabaseClient? client})
      : _db     = client ?? Supabase.instance.client,
        _secure = SecureStorageService.instance {
    _db.auth.onAuthStateChange.listen(_handleAuthStateChange);
  }

  void _handleAuthStateChange(AuthState event) {
    final session = event.session;
    if (session != null &&
        (event.event == AuthChangeEvent.signedIn ||
         event.event == AuthChangeEvent.tokenRefreshed ||
         event.event == AuthChangeEvent.userUpdated)) {
      _secure.saveTokens(
        accessToken:  session.accessToken,
        refreshToken: session.refreshToken ?? '',
        userId:       session.user.id,
        email:        session.user.email,
      ).catchError((_) {});
    } else if (event.event == AuthChangeEvent.signedOut) {
      _secure.clearTokens().catchError((_) {});
    }
  }

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
    await _secure.clearTokens().catchError((_) {});
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

  // ── Legal documents ──────────────────────────────────────────────
  /// Returns active legal documents not yet accepted by [userId].
  Future<List<LegalDocument>> getPendingLegalDocuments(String userId) async {
    try {
      final docs = await _db
          .from('legal_documents')
          .select()
          .eq('is_active', true);
      if (docs.isEmpty) return [];

      final accepted = await _db
          .from('legal_document_acceptances')
          .select('document_id, version')
          .eq('user_id', userId);

      final acceptedKeys = <String>{
        for (final a in (accepted as List))
          '${a['document_id']}:${a['version']}'
      };

      return (docs as List)
          .map((d) => LegalDocument.fromJson(d as Map<String, dynamic>))
          .where((doc) => !acceptedKeys.contains('${doc.id}:${doc.version}'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Records acceptance of a legal document version.
  Future<void> acceptLegalDocument(
    String userId,
    String documentId,
    String version,
  ) async {
    await _db.from('legal_document_acceptances').upsert({
      'user_id': userId,
      'document_id': documentId,
      'version': version,
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ── Health check (maintenance mode detection) ─────────────
  Future<bool> isInMaintenance() async {
    try {
      await _db.from('app_config').select('key').limit(1);
      return false;
    } on PostgrestException catch (e) {
      return e.code == '503';
    } catch (e) {
      return e.toString().contains('503');
    }
  }
}
