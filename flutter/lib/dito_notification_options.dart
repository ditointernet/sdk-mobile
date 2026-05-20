class DitoNotificationOptions {
  final int? accentColor;
  final bool badgeEnabled;
  final int? largeIconResId;
  final int? smallIconResId;
  final String? soundResourceName;

  const DitoNotificationOptions({
    this.accentColor,
    this.badgeEnabled = true,
    this.largeIconResId,
    this.smallIconResId,
    this.soundResourceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'accentColor': accentColor,
      'badgeEnabled': badgeEnabled,
      'largeIconResId': largeIconResId,
      'smallIconResId': smallIconResId,
      'soundResourceName': soundResourceName,
    };
  }
}
