/// Date formatting helpers shared across data sources and UI.
class AppDateUtils {
  AppDateUtils._();

  /// Returns a date string in `YYYY-MM-DD` format for Supabase queries.
  static String dateOnly(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  /// Relative time label for timestamps (e.g. "2m ago", "3h ago", "Yesterday").
  static String relativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateOnly(timestamp);
  }
}
