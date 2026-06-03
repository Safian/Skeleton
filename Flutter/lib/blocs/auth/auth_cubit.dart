import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../repositories/auth_repository.dart';
import 'auth_state.dart';

// ============================================================
// AuthCubit – login / regisztráció / reset / social login
// Csak az AuthScreen-hez tartozik; SessionCubit figyeli az
// eredményt a Supabase auth stream-en keresztül.
// ============================================================

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;

  AuthCubit({AuthRepository? repository})
      : _repo = repository ?? AuthRepository(),
        super(AuthInitial());

  Future<void> signInWithEmailPassword(String email, String password) async {
    emit(AuthLoading());
    try {
      await _repo.signInWithEmailPassword(email, password);
      emit(AuthSuccess());
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message)));
    } catch (e) {
      emit(AuthError('Váratlan hiba: $e'));
    }
  }

  Future<void> registerWithEmailPassword(String email, String password) async {
    emit(AuthLoading());
    try {
      await _repo.registerWithEmailPassword(email, password);
      emit(const AuthRequiresConfirmation(
        'Regisztráció sikeres! Ellenőrizd az email fiókodat a megerősítő linkért.',
      ));
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message)));
    } catch (e) {
      emit(AuthError('Váratlan hiba: $e'));
    }
  }

  // ── Social Login ──────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      await _repo.signInWithGoogle();
      // SessionCubit veszi át a sikerjelzést az auth stream-en
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message)));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('cancel')) {
        emit(AuthInitial());
      } else {
        emit(AuthError('Google bejelentkezés sikertelen: $e'));
      }
    }
  }

  Future<void> signInWithApple() async {
    emit(AuthLoading());
    try {
      await _repo.signInWithApple();
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message)));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('cancel') ||
          msg.contains('AuthorizationErrorCode.canceled')) {
        emit(AuthInitial());
      } else {
        emit(AuthError('Apple bejelentkezés sikertelen: $e'));
      }
    }
  }

  Future<void> registerFirstAdmin(String email, String password) async {
    emit(AuthLoading());
    try {
      await _repo.registerFirstAdmin(email, password);
      emit(AuthSuccess());
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AuthError(msg));
    }
  }

  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    try {
      await _repo.resetPassword(email);
      emit(const AuthResetSuccess(
        'Jelszó-visszaállítási linket küldtünk az email címedre.',
      ));
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message)));
    } catch (e) {
      emit(AuthError('Váratlan hiba: $e'));
    }
  }

  String _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
      return 'Hibás email cím vagy jelszó.';
    }
    if (m.contains('email not confirmed')) {
      return 'Erősítsd meg az email címedet a belépés előtt.';
    }
    if (m.contains('user already registered') || m.contains('already registered')) {
      return 'Ez az email cím már regisztrálva van.';
    }
    if (m.contains('rate limit')) {
      return 'Túl sok próbálkozás. Kérjük, várj egy kicsit.';
    }
    return message;
  }
}
