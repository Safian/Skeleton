import 'package:equatable/equatable.dart';

// ============================================================
// AuthState – login/regisztráció form állapota
// ============================================================

/// Lokalizálható auth hibatípusok – a konkrét szöveget a UI fordítja
/// a context.t() + codebaseTranslations rendszerrel, nem a cubit.
enum AuthErrorType {
  invalidCredentials,
  emailNotConfirmed,
  alreadyRegistered,
  rateLimit,
  unknown,
}

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {}

class AuthRequiresConfirmation extends AuthState {
  const AuthRequiresConfirmation();
}

class AuthResetSuccess extends AuthState {
  const AuthResetSuccess();
}

class AuthError extends AuthState {
  final AuthErrorType type;
  /// Csak [AuthErrorType.unknown] esetén – nyers (nem lokalizált) üzenet.
  final String? rawMessage;
  const AuthError(this.type, {this.rawMessage});
  @override
  List<Object?> get props => [type, rawMessage];
}
