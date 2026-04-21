final RegExp _teamSlotPlaceholderPattern = RegExp(
  r'^(?:[12][A-L]|3[A-L](?:/[A-L])+|[A-L][123]|[WL][0-9]+|(?:WINNER|RUNNER-UP|RUNNER UP|LOSER|TBD|TO BE DETERMINED)\b)$',
  caseSensitive: false,
);

bool isPlaceholderTeamName(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return false;
  return _teamSlotPlaceholderPattern.hasMatch(normalized);
}

String normalizeTeamDisplayName(String? value) {
  final original = value?.trim() ?? '';
  if (original.isEmpty) return '';

  final upper = original.toUpperCase();

  if (RegExp(r'^[12][A-L]$').hasMatch(upper)) {
    final group = upper.substring(1);
    return upper.startsWith('1')
        ? 'Winner Group $group'
        : 'Runner-up Group $group';
  }

  if (RegExp(r'^3[A-L](/[A-L])+$').hasMatch(upper)) {
    return 'Best 3rd Place Groups ${upper.substring(1)}';
  }

  if (RegExp(r'^[A-L][123]$').hasMatch(upper)) {
    final group = upper.substring(0, 1);
    final position = upper.substring(1);
    switch (position) {
      case '1':
        return 'Winner Group $group';
      case '2':
        return 'Runner-up Group $group';
      default:
        return '3rd Place Group $group';
    }
  }

  if (RegExp(r'^W[0-9]+$').hasMatch(upper)) {
    return 'Winner Match ${upper.substring(1)}';
  }

  if (RegExp(r'^L[0-9]+$').hasMatch(upper)) {
    return 'Loser Match ${upper.substring(1)}';
  }

  if (upper == 'TBD' || upper == 'TO BE DETERMINED') {
    return 'TBD';
  }

  if (RegExp(r'^1\.\s+').hasMatch(original)) {
    return original.replaceFirst(RegExp(r'^1\.\s+'), '');
  }

  return original;
}
