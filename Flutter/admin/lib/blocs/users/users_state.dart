import 'package:equatable/equatable.dart';
import '../../models/user_profile.dart';
import '../../models/admin_stats.dart';

// ============================================================
// UsersState – admin felhasználó-lista és statisztika állapota
// ============================================================

abstract class UsersState extends Equatable {
  const UsersState();
  @override
  List<Object?> get props => [];
}

class UsersInitial extends UsersState {}

class UsersLoading extends UsersState {}

class UsersLoaded extends UsersState {
  final List<UserProfile> users;
  final AdminStats stats;
  final String searchQuery;

  const UsersLoaded({
    required this.users,
    required this.stats,
    this.searchQuery = '',
  });

  List<UserProfile> get filtered {
    if (searchQuery.isEmpty) return users;
    final q = searchQuery.toLowerCase();
    return users.where((u) =>
      u.email.toLowerCase().contains(q) ||
      (u.displayName?.toLowerCase().contains(q) ?? false)).toList();
  }

  UsersLoaded copyWith({
    List<UserProfile>? users,
    AdminStats? stats,
    String? searchQuery,
  }) => UsersLoaded(
    users:       users       ?? this.users,
    stats:       stats       ?? this.stats,
    searchQuery: searchQuery ?? this.searchQuery,
  );

  @override
  List<Object?> get props => [users, stats, searchQuery];
}

class UsersError extends UsersState {
  final String message;
  const UsersError(this.message);
  @override
  List<Object?> get props => [message];
}

class UsersUpdating extends UsersLoaded {
  const UsersUpdating({required super.users, required super.stats, super.searchQuery});
}
