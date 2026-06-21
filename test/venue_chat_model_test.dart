import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/hospitality/venue_chat_model.dart';

void main() {
  test('parses venue chat thread with messages', () {
    final message = VenueChatMessageModel.fromJson({
      'id': 'message-1',
      'thread_id': 'thread-1',
      'venue_id': 'venue-1',
      'sender_user_id': 'user-1',
      'sender_role': 'customer',
      'body': 'Can staff check my order?',
      'message_type': 'text',
      'moderation_status': 'visible',
      'created_at': '2026-06-21T13:30:00Z',
    });

    final thread = VenueChatThreadModel.fromJson(
      {
        'id': 'thread-1',
        'venue_id': 'venue-1',
        'customer_user_id': 'user-1',
        'order_id': 'order-1',
        'support_request_id': null,
        'topic': 'order',
        'subject': 'Order help',
        'status': 'open',
        'assigned_to': null,
        'resolution_notes': null,
        'last_message_at': '2026-06-21T13:30:00Z',
        'closed_at': null,
        'closed_by': null,
        'created_at': '2026-06-21T13:30:00Z',
        'updated_at': '2026-06-21T13:30:00Z',
      },
      messages: [message],
    );

    expect(thread.title, 'Order help');
    expect(thread.isOpen, isTrue);
    expect(thread.lastMessage?.body, 'Can staff check my order?');
    expect(message.isCustomer, isTrue);
    expect(message.isSystem, isFalse);
  });

  test('falls back to topic title and closed state', () {
    final thread = VenueChatThreadModel.fromJson({
      'id': 'thread-2',
      'venue_id': 'venue-1',
      'customer_user_id': 'user-1',
      'topic': 'accessibility',
      'status': 'resolved',
      'last_message_at': '2026-06-21T13:30:00Z',
      'created_at': '2026-06-21T13:30:00Z',
      'updated_at': '2026-06-21T13:30:00Z',
    });

    expect(thread.title, 'accessibility chat');
    expect(thread.isOpen, isFalse);
    expect(thread.messages, isEmpty);
  });
}
