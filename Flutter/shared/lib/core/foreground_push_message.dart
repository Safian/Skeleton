/// A foreground FCM message with parsed fields for the overlay.
class ForegroundPushMessage {
  final String title;
  final String body;
  final Map<String, dynamic> data;

  const ForegroundPushMessage({
    required this.title,
    required this.body,
    required this.data,
  });
}

/// Callback type: user tapped the overlay banner.
typedef ForegroundPushTapCallback = void Function(ForegroundPushMessage message);
