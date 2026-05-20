class DitoNotificationOptions {
  final int? accentColor;
  final int? largeIconResId;
  final int? smallIconResId;
  final String? soundResourceName;

  const DitoNotificationOptions({
    this.accentColor,
    this.largeIconResId,
    this.smallIconResId,
    this.soundResourceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'accentColor': accentColor,
      'largeIconResId': largeIconResId,
      'smallIconResId': smallIconResId,
      'soundResourceName': soundResourceName,
    };
  }
}
