// ============================================================
// AdminStats – dashboard statisztikák modellje
// ============================================================

class AdminStats {
  final int totalUsers;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int totalItems;
  final int activeItems;

  const AdminStats({
    required this.totalUsers,
    required this.newUsersToday,
    required this.newUsersThisWeek,
    required this.totalItems,
    required this.activeItems,
  });

  static const AdminStats empty = AdminStats(
    totalUsers: 0,
    newUsersToday: 0,
    newUsersThisWeek: 0,
    totalItems: 0,
    activeItems: 0,
  );
}
