import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart scripts/generate_review_report.dart review-comments.json',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Review comments file not found: ${args.first}');
    exitCode = 66;
    return;
  }

  final decoded = jsonDecode(file.readAsStringSync());
  final rows = decoded is List ? decoded.whereType<Map>().toList() : <Map>[];
  if (rows.isEmpty) {
    stdout.writeln('# Review Comments\n\nNo review comments found.');
    return;
  }

  stdout.writeln('# Review Comments\n');
  for (final row in rows) {
    final severity = row['severity']?.toString() ?? 'medium';
    final status = row['status']?.toString() ?? 'open';
    final route = row['route']?.toString() ?? 'unknown route';
    final comment = row['comment']?.toString() ?? '';
    final device = row['device_preset']?.toString() ?? 'unknown device';
    final component = row['component_key']?.toString();
    stdout.writeln('- [$severity][$status] `$route` on $device');
    if (component != null && component.isNotEmpty) {
      stdout.writeln('  Component: `$component`');
    }
    stdout.writeln('  $comment\n');
  }
}
