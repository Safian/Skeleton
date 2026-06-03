// ============================================================
// BugReport model (Admin) – bug_reports tábla tükre  [M7]
// ============================================================

class BugReport {
  final String id;
  final DateTime createdAt;
  final String? reporterId;
  final String? reporterEmail;

  final String title;
  final String? description;
  final String priority; // 'low' | 'medium' | 'high' | 'critical'
  final String? routeName;
  final Map<String, dynamic> deviceInfo;
  final List<String> logs;
  final String? screenshotUrl;

  final String status; // 'open' | 'in_progress' | 'resolved' | 'wont_fix'
  final String? adminNotes;
  final DateTime? resolvedAt;

  const BugReport({
    required this.id,
    required this.createdAt,
    this.reporterId,
    this.reporterEmail,
    required this.title,
    this.description,
    required this.priority,
    this.routeName,
    required this.deviceInfo,
    required this.logs,
    this.screenshotUrl,
    required this.status,
    this.adminNotes,
    this.resolvedAt,
  });

  factory BugReport.fromJson(Map<String, dynamic> json) {
    return BugReport(
      id:            json['id']         as String,
      createdAt:     DateTime.parse(json['created_at'] as String),
      reporterId:    json['reporter_id']    as String?,
      reporterEmail: json['reporter_email'] as String?,
      title:         json['title']          as String,
      description:   json['description']    as String?,
      priority:      json['priority']       as String? ?? 'medium',
      routeName:     json['route_name']     as String?,
      deviceInfo:    (json['device_info']   as Map<String, dynamic>?) ?? {},
      logs:          (json['logs'] as List<dynamic>?)
                         ?.map((e) => e.toString())
                         .toList() ?? [],
      screenshotUrl: json['screenshot_url'] as String?,
      status:        json['status']         as String? ?? 'open',
      adminNotes:    json['admin_notes']    as String?,
      resolvedAt:    json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  // Megjelenítési segítők
  String get appVersion  => deviceInfo['app_version']  as String? ?? 'N/A';
  String get osName      => deviceInfo['os_name']       as String? ?? 'N/A';
  String get osVersion   => deviceInfo['os_version']    as String? ?? '';
  String get deviceModel => deviceInfo['device_model']  as String? ?? 'N/A';

  bool get isOpen       => status == 'open';
  bool get isResolved   => status == 'resolved' || status == 'wont_fix';

  String get priorityLabel {
    return switch (priority) {
      'critical' => '🔴 Kritikus',
      'high'     => '🟠 Magas',
      'medium'   => '🟡 Közepes',
      'low'      => '🟢 Alacsony',
      _          => priority,
    };
  }

  String get statusLabel {
    return switch (status) {
      'open'        => 'Nyitott',
      'in_progress' => 'Folyamatban',
      'resolved'    => 'Megoldva',
      'wont_fix'    => 'Nem javítandó',
      _             => status,
    };
  }
}
