import 'package:equatable/equatable.dart';

// ============================================================
// AuthState – login/regisztráció form állapota
// ============================================================

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {}

class AuthRequiresConfirmation extends AuthState {
  final String message;
  const AuthRequiresConfirmation(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthResetSuccess extends AuthState {
  final String message;
  const AuthResetSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}
