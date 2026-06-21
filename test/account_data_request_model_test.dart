import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/auth_and_user/account_data_request_model.dart';

void main() {
  test('account data request parses support workflow fields', () {
    final request = AccountDataRequestModel.fromJson({
      'id': 'request_1',
      'status': 'in_review',
      'request_type': 'export',
      'requested_at': '2026-06-08T10:00:00Z',
      'reason': 'I need a copy of my account data.',
      'contact_email': 'fan@example.com',
      'resolution_notes': 'Queued for support review.',
      'processed_at': '2026-06-08T11:00:00Z',
    });

    expect(request.id, 'request_1');
    expect(request.status, 'in_review');
    expect(request.requestType, 'export');
    expect(request.isActive, isTrue);
    expect(request.reason, 'I need a copy of my account data.');
    expect(request.contactEmail, 'fan@example.com');
    expect(request.resolutionNotes, 'Queued for support review.');
    expect(request.processedAt, DateTime.parse('2026-06-08T11:00:00Z'));
  });

  test('completed data requests are not active', () {
    final request = AccountDataRequestModel.fromJson({
      'id': 'request_2',
      'status': 'completed',
      'created_at': '2026-06-08T10:00:00Z',
    });

    expect(request.requestType, 'export');
    expect(request.isActive, isFalse);
  });
}
