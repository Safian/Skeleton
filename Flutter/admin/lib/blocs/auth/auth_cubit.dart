import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../repositories/auth_repository.dart';
import 'auth_state.dart';

// ============================================================
// AuthCubit – login / regisztráció / reset logika
// Csak az AuthScreen-hez tartozik, SessionCubit figyeli az
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
      emit(AuthError(_mapAuthError(e.message), rawMessage: e.message));
    } catch (e) {
      emit(AuthError(AuthErrorType.unknown, rawMessage: e.toString()));
    }
  }

  Future<void> registerWithEmailPassword(String email, String password) async {
    emit(AuthLoading());
    try {
      await _repo.registerWithEmailPassword(email, password);
      emit(AuthSuccess());
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message), rawMessage: e.message));
    } catch (e) {
      emit(AuthError(AuthErrorType.unknown, rawMessage: e.toString()));
    }
  }

  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    try {
      await _repo.resetPassword(email);
      emit(const AuthResetSuccess());
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message), rawMessage: e.message));
    } catch (e) {
      emit(AuthError(AuthErrorType.unknown, rawMessage: e.toString()));
    }
  }

  AuthErrorType _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
      return AuthErrorType.invalidCredentials;
    }
    if (m.contains('email not confirmed')) {
      return AuthErrorType.emailNotConfirmed;
    }
    if (m.contains('user already registered') || m.contains('already registered')) {
      return AuthErrorType.alreadyRegistered;
    }
    if (m.contains('rate limit')) {
      return AuthErrorType.rateLimit;
    }
    return AuthErrorType.unknown;
  }
}
