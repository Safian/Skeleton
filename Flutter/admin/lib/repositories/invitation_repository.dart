import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_invitation.dart';

// ============================================================
// InvitationRepository – admin_invitations CRUD + edge function hívás
// ============================================================

class InvitationRepository {
  final SupabaseClient _db;

  InvitationRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  // ── Meghívók listázása ────────────────────────────────────────
  Future<List<AdminInvitation>> getInvitations() async {
    final res = await _db
        .from('admin_invitations')
        .select()
        .order('created_at', ascending: false)
        .limit(200) as List<dynamic>;

    return res
        .map((e) => AdminInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Meghívó küldése (edge function) ──────────────────────────
  Future<Map<String, dynamic>> sendInvitation({
    required String email,
    String role = 'admin',
    String? note,
  }) async {
    final response = await _db.functions.invoke(
      'admin-invite',
      body: {
        'email': email,
        if (role != 'admin') 'role': role,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );

    if (response.status != 200 && response.status != 201) {
      final data = response.data as Map<String, dynamic>?;
      throw Exception(data?['error'] ?? 'Meghívó küldési hiba (${response.status})');
    }

    return response.data as Map<String, dynamic>;
  }

  // ── Meghívó törlése (lejárt vagy egyéb) ──────────────────────
  Future<void> deleteInvitation(String id) async {
    await _db.from('admin_invitations').delete().eq('id', id);
  }

  // ── Meghívó érvénytelenítése (is_used = true) ────────────────
  Future<void> revokeInvitation(String id) async {
    await _db.from('admin_invitations').update({'is_used': true}).eq('id', id);
  }
}
