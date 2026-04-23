import { parsePushPayload } from './payload.ts';

Deno.test('parsePushPayload normalizes single user_id and stringifies data', () => {
  const payload = parsePushPayload({
    user_id: 'user-1',
    type: 'wallet_credit',
    title: 'Wallet updated',
    body: 'You received FET.',
    data: { amount: 500, featured: true },
  });

  if (payload.userIds.join(',') !== 'user-1') {
    throw new Error('Expected user_id to normalize into userIds');
  }

  if (payload.data.amount !== '500' || payload.data.featured !== 'true') {
    throw new Error('Expected data values to be stringified');
  }
});

Deno.test('parsePushPayload deduplicates and trims user_ids', () => {
  const payload = parsePushPayload({
    user_ids: [' user-1 ', 'user-2', 'user-1'],
    type: 'prediction_reward',
    title: 'Prediction reward',
    body: 'Your token reward is ready.',
  });

  if (payload.userIds.join(',') !== 'user-1,user-2') {
    throw new Error(`Expected deduplicated user ids, got ${payload.userIds.join(',')}`);
  }
});

Deno.test('parsePushPayload rejects invalid payloads', () => {
  let failed = false;

  try {
    parsePushPayload({
      user_id: 'user-1',
      type: 'prediction_reward',
      body: 'Missing title should fail',
    });
  } catch (error) {
    failed = error instanceof Error && error.message.includes('title');
  }

  if (!failed) {
    throw new Error('Expected invalid payloads to throw');
  }
});
