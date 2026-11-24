/// Utility to translate standard 5-field cron expressions into human-readable strings.
/// When an expression cannot be reliably translated, falls back cleanly to the raw string.
class CronTranslator {
  const CronTranslator._();

  static const Map<String, String> _daysOfWeek = {
    '0': 'Sunday',
    '1': 'Monday',
    '2': 'Tuesday',
    '3': 'Wednesday',
    '4': 'Thursday',
    '5': 'Friday',
    '6': 'Saturday',
    '7': 'Sunday',
  };

  /// Translates a 5-part cron expression into human-readable text.
  /// E.g. "0 9 * * *" -> "Every day at 09:00"
  /// "0 9 * * 1-5" -> "Every weekday at 09:00"
  /// "*/15 * * * *" -> "Every 15 minutes"
  /// "0 */2 * * *" -> "Every 2 hours"
  /// Fallback: returns [expr] trimmed.
  static String translate(String? expr) {
    if (expr == null) return '';
    final trimmed = expr.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length != 5) {
      return trimmed;
    }

    final min = parts[0];
    final hour = parts[1];
    final dom = parts[2];
    final mon = parts[3];
    final dow = parts[4];

    // Case 1: Every X minutes: "*/X * * * *"
    if (min.startsWith('*/') && hour == '*' && dom == '*' && mon == '*' && dow == '*') {
      final interval = min.substring(2);
      if (int.tryParse(interval) != null) {
        return 'Every $interval minutes';
      }
    }

    // Case 2: Every hour at minute 0: "0 * * * *"
    if (min == '0' && hour == '*' && dom == '*' && mon == '*' && dow == '*') {
      return 'Every hour';
    }

    // Case 3: Every X hours at minute 0: "0 */X * * *"
    if (min == '0' && hour.startsWith('*/') && dom == '*' && mon == '*' && dow == '*') {
      final interval = hour.substring(2);
      if (int.tryParse(interval) != null) {
        return 'Every $interval hours';
      }
    }

    // Format time if both minute and hour are fixed numbers
    final parsedMin = int.tryParse(min);
    final parsedHour = int.tryParse(hour);
    final hasFixedTime = parsedMin != null &&
        parsedHour != null &&
        parsedMin >= 0 &&
        parsedMin < 60 &&
        parsedHour >= 0 &&
        parsedHour < 24;

    if (hasFixedTime && dom == '*' && mon == '*') {
      final timeStr =
          '${parsedHour.toString().padLeft(2, '0')}:${parsedMin.toString().padLeft(2, '0')}';

      // Every day: "0 9 * * *"
      if (dow == '*') {
        return 'Every day at $timeStr';
      }

      // Weekdays: "0 9 * * 1-5"
      if (dow == '1-5') {
        return 'Every weekday at $timeStr';
      }

      // Weekends: "0 9 * * 0,6" or "0 9 * * 6,0" or "0 9 * * 6-7"
      if (dow == '0,6' || dow == '6,0' || dow == '6-7') {
        return 'Every weekend at $timeStr';
      }

      // Single day of week: "0 10 * * 1" -> "Every Monday at 10:00"
      if (_daysOfWeek.containsKey(dow)) {
        return 'Every ${_daysOfWeek[dow]} at $timeStr';
      }
    }

    // Unrecognized or complex expression -> return raw expr
    return trimmed;
  }
}
