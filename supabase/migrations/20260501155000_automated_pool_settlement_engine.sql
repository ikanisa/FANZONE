-- Automated pool settlement engine.
--
-- The settlement RPCs below are service/admin backend surfaces. Clients stake
-- through join_match_pool; they never post settlement wallet mutations.

CREATE OR REPLACE FUNCTION public.app_config_text(
  p_key text,
  p_default text DEFAULT NULL::text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_value jsonb;
  v_text text;
BEGIN
  SELECT value
  INTO v_value
  FROM public.app_config_remote
  WHERE key = p_key
  LIMIT 1;

  IF v_value IS NULL OR v_value = 'null'::jsonb THEN
    RETURN p_default;
  END IF;

  IF jsonb_typeof(v_value) = 'string' THEN
    RETURN trim(both '"' from v_value::text);
  END IF;

  v_text := trim(v_value::text);
  IF v_text = '' THEN
    RETURN p_default;
  END IF;

  RETURN v_text;
END;
$$;

INSERT INTO public.app_config_remote (key, value, description)
VALUES
  ('pool_settlement_no_winner_rule', '"refund_all"'::jsonb, 'No-winner pool settlement rule: refund_all, roll_over, or platform_hold.'),
  ('pool_settlement_cancelled_rule', '"refund_all"'::jsonb, 'Cancelled-match pool settlement rule. Safe default is refund_all.'),
  ('pool_settlement_postponed_rule', '"hold"'::jsonb, 'Postponed-match pool settlement rule: hold or refund_all.'),
  ('pool_settlement_payout_rule', '"proportional"'::jsonb, 'Winning payout rule: proportional or equal_per_winner.')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.settle_match_pool(p_pool_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $$
DECLARE
  v_pool public.match_pools%ROWTYPE;
  v_match public.matches%ROWTYPE;
  v_result_camp public.match_pool_camps%ROWTYPE;
  v_settlement public.match_pool_settlements%ROWTYPE;
  v_settlement_found boolean := false;
  v_entry record;
  v_match_state text;
  v_settlement_key text := 'match-pool-settlement:' || p_pool_id::text;
  v_existing_result_code text;
  v_winner_count bigint := 0;
  v_winning_stake bigint := 0;
  v_total_active bigint := 0;
  v_losing_stake bigint := 0;
  v_platform_fee bigint := 0;
  v_venue_fee bigint := 0;
  v_distributable_losing bigint := 0;
  v_bonus_share bigint := 0;
  v_bonus_allocated bigint := 0;
  v_payout bigint := 0;
  v_total_paid bigint := 0;
  v_processed_entries bigint := 0;
  v_row_index bigint := 0;
  v_payout_rule text;
  v_no_winner_rule text;
  v_postponed_rule text;
  v_error text;
BEGIN
  IF p_pool_id IS NULL THEN
    RAISE EXCEPTION 'Pool id is required';
  END IF;

  BEGIN
    SELECT *
    INTO v_pool
    FROM public.match_pools
    WHERE id = p_pool_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Pool not found';
    END IF;

    SELECT *
    INTO v_match
    FROM public.matches
    WHERE id = v_pool.match_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Pool match not found';
    END IF;

    v_match_state := CASE
      WHEN lower(coalesce(v_match.status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
      WHEN lower(coalesce(v_match.match_status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
      WHEN lower(coalesce(v_match.status, '')) = 'postponed' THEN 'postponed'
      WHEN lower(coalesce(v_match.match_status, '')) = 'postponed' THEN 'postponed'
      WHEN lower(coalesce(v_match.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
      WHEN lower(coalesce(v_match.match_status, '')) = 'finished' THEN 'final'
      ELSE lower(coalesce(nullif(v_match.status, ''), nullif(v_match.match_status, ''), 'scheduled'))
    END;

    SELECT *
    INTO v_settlement
    FROM public.match_pool_settlements
    WHERE pool_id = p_pool_id
    FOR UPDATE;

    v_settlement_found := FOUND;

    IF v_settlement_found AND v_settlement.result_camp_id IS NOT NULL THEN
      SELECT result_code
      INTO v_existing_result_code
      FROM public.match_pool_camps
      WHERE id = v_settlement.result_camp_id;
    ELSE
      v_existing_result_code := NULL;
    END IF;

    IF (v_settlement_found AND v_settlement.status = 'completed') OR v_pool.status::text = 'settled' THEN
      IF v_match_state = 'final'
         AND v_match.result_code IS NOT NULL
         AND v_existing_result_code IS NOT NULL
         AND v_match.result_code <> v_existing_result_code THEN
        PERFORM public.sports_bar_write_audit(
          'pool_settlement_requires_reversal',
          'settlement',
          coalesce(v_settlement.id::text, p_pool_id::text),
          to_jsonb(v_settlement),
          jsonb_build_object(
            'pool_id', p_pool_id,
            'previous_result_code', v_existing_result_code,
            'current_result_code', v_match.result_code,
            'reason', 'match_result_changed_after_settlement'
          )
        );

        RETURN jsonb_build_object(
          'status', 'requires_reversal',
          'pool_id', p_pool_id,
          'settlement_id', v_settlement.id,
          'previous_result_code', v_existing_result_code,
          'current_result_code', v_match.result_code
        );
      END IF;

      UPDATE public.match_pools
      SET status = 'settled',
          settled_at = coalesce(settled_at, v_settlement.completed_at, timezone('utc', now())),
          updated_at = timezone('utc', now())
      WHERE id = p_pool_id
        AND status::text <> 'settled';

      RETURN jsonb_build_object(
        'status', 'already_settled',
        'pool_id', p_pool_id,
        'settlement_id', v_settlement.id,
        'settled_at', coalesce(v_pool.settled_at, v_settlement.completed_at)
      );
    END IF;

    IF v_pool.status::text = 'cancelled' THEN
      v_match_state := 'cancelled';
    END IF;

    IF v_match_state = 'postponed' THEN
      v_postponed_rule := lower(coalesce(
        nullif(v_pool.rules_json ->> 'postponed_rule', ''),
        public.app_config_text('pool_settlement_postponed_rule', 'hold')
      ));

      IF v_postponed_rule <> 'refund_all' THEN
        UPDATE public.match_pools
        SET status = 'locked',
            locked_at = coalesce(locked_at, timezone('utc', now())),
            updated_at = timezone('utc', now()),
            metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
              'postponed_hold_at', timezone('utc', now()),
              'postponed_rule', v_postponed_rule
            )
        WHERE id = p_pool_id;

        INSERT INTO public.match_pool_settlements (
          pool_id,
          match_id,
          status,
          idempotency_key,
          error_message,
          metadata
        )
        VALUES (
          p_pool_id,
          v_pool.match_id,
          'pending',
          v_settlement_key,
          NULL,
          jsonb_build_object(
            'settlement_kind', 'postponed_hold',
            'postponed_rule', v_postponed_rule,
            'match_state', v_match_state,
            'held_at', timezone('utc', now())
          )
        )
        ON CONFLICT (pool_id) DO UPDATE
        SET status = 'pending',
            match_id = excluded.match_id,
            error_message = NULL,
            metadata = coalesce(public.match_pool_settlements.metadata, '{}'::jsonb) || excluded.metadata
        RETURNING * INTO v_settlement;

        PERFORM public.sports_bar_write_audit(
          'pool_settlement_postponed_hold',
          'settlement',
          v_settlement.id::text,
          to_jsonb(v_pool),
          jsonb_build_object('pool_id', p_pool_id, 'postponed_rule', v_postponed_rule)
        );

        RETURN jsonb_build_object(
          'status', 'held',
          'reason', 'match_postponed',
          'pool_id', p_pool_id,
          'settlement_id', v_settlement.id,
          'postponed_rule', v_postponed_rule
        );
      END IF;
    ELSIF v_match_state <> 'final' AND v_match_state <> 'cancelled' THEN
      RAISE EXCEPTION 'Match is not final';
    END IF;

    IF v_match_state = 'final' THEN
      IF v_match.result_code IS NULL THEN
        RAISE EXCEPTION 'Match result is missing';
      END IF;

      SELECT *
      INTO v_result_camp
      FROM public.match_pool_camps
      WHERE pool_id = p_pool_id
        AND result_code = v_match.result_code;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'No pool camp maps to the final result';
      END IF;
    END IF;

    UPDATE public.match_pools
    SET status = 'settling',
        locked_at = coalesce(locked_at, timezone('utc', now())),
        result_camp_id = CASE WHEN v_match_state = 'final' THEN v_result_camp.id ELSE result_camp_id END,
        updated_at = timezone('utc', now())
    WHERE id = p_pool_id
    RETURNING * INTO v_pool;

    SELECT
      count(*) FILTER (WHERE v_match_state <> 'final' OR camp_id = v_result_camp.id),
      coalesce(sum(amount_fet) FILTER (WHERE v_match_state <> 'final' OR camp_id = v_result_camp.id), 0),
      coalesce(sum(amount_fet), 0)
    INTO v_winner_count, v_winning_stake, v_total_active
    FROM public.match_pool_entries
    WHERE pool_id = p_pool_id
      AND status = 'active';

    IF v_match_state <> 'final' THEN
      v_winner_count := 0;
      v_winning_stake := 0;
    END IF;

    v_losing_stake := greatest(v_total_active - v_winning_stake, 0);
    v_platform_fee := floor((v_losing_stake::numeric * greatest(coalesce(v_pool.platform_fee_bps, 0), 0)::numeric) / 10000)::bigint;
    v_venue_fee := floor((v_losing_stake::numeric * greatest(coalesce(v_pool.venue_fee_bps, 0), 0)::numeric) / 10000)::bigint;
    v_distributable_losing := greatest(v_losing_stake - v_platform_fee - v_venue_fee, 0);
    v_payout_rule := lower(coalesce(
      nullif(v_pool.rules_json ->> 'settlement_rule', ''),
      nullif(v_pool.rules_json ->> 'payout_rule', ''),
      public.app_config_text('pool_settlement_payout_rule', 'proportional')
    ));

    IF v_payout_rule NOT IN ('proportional', 'equal_per_winner') THEN
      v_payout_rule := 'proportional';
    END IF;

    INSERT INTO public.match_pool_settlements (
      pool_id,
      match_id,
      status,
      result_camp_id,
      winners_count,
      losing_stake_fet,
      payout_per_winner_fet,
      idempotency_key,
      error_message,
      metadata
    )
    VALUES (
      p_pool_id,
      v_pool.match_id,
      'running',
      CASE WHEN v_match_state = 'final' THEN v_result_camp.id ELSE NULL END,
      v_winner_count,
      v_losing_stake,
      0,
      v_settlement_key,
      NULL,
      jsonb_build_object(
        'match_state', v_match_state,
        'match_id', v_pool.match_id,
        'venue_id', v_pool.venue_id,
        'result_code', v_match.result_code,
        'payout_rule', v_payout_rule,
        'platform_fee_fet', v_platform_fee,
        'venue_fee_fet', v_venue_fee,
        'started_by', coalesce(auth.uid()::text, current_user),
        'started_at', timezone('utc', now())
      )
    )
    ON CONFLICT (pool_id) DO UPDATE
    SET match_id = excluded.match_id,
        status = 'running',
        result_camp_id = excluded.result_camp_id,
        winners_count = excluded.winners_count,
        losing_stake_fet = excluded.losing_stake_fet,
        payout_per_winner_fet = 0,
        error_message = NULL,
        completed_at = NULL,
        metadata = coalesce(public.match_pool_settlements.metadata, '{}'::jsonb) || excluded.metadata
    RETURNING * INTO v_settlement;

    IF v_total_active = 0 THEN
      UPDATE public.match_pool_settlements
      SET status = 'completed',
          completed_at = timezone('utc', now()),
          total_paid_fet = 0,
          metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
            'settlement_kind', 'empty_pool',
            'match_state', v_match_state
          )
      WHERE id = v_settlement.id
      RETURNING * INTO v_settlement;

      UPDATE public.match_pools
      SET status = CASE WHEN v_match_state = 'cancelled' THEN 'cancelled'::public.match_pool_status ELSE 'settled'::public.match_pool_status END,
          settled_at = CASE WHEN v_match_state = 'cancelled' THEN settled_at ELSE timezone('utc', now()) END,
          updated_at = timezone('utc', now())
      WHERE id = p_pool_id;

      PERFORM public.sports_bar_write_audit(
        'pool_settled_empty',
        'settlement',
        v_settlement.id::text,
        NULL,
        jsonb_build_object('pool_id', p_pool_id, 'match_id', v_pool.match_id)
      );

      RETURN jsonb_build_object(
        'status', CASE WHEN v_match_state = 'cancelled' THEN 'refunded' ELSE 'settled_empty' END,
        'pool_id', p_pool_id,
        'settlement_id', v_settlement.id,
        'reason', CASE WHEN v_match_state = 'cancelled' THEN 'match_cancelled' ELSE 'empty_pool' END
      );
    END IF;

    IF v_match_state = 'cancelled'
       OR v_match_state = 'postponed'
       OR (v_match_state = 'final' AND v_winner_count = 0) THEN
      v_no_winner_rule := CASE
        WHEN v_match_state = 'cancelled' THEN lower(public.app_config_text('pool_settlement_cancelled_rule', 'refund_all'))
        WHEN v_match_state = 'postponed' THEN 'refund_all'
        ELSE lower(coalesce(
          nullif(v_pool.rules_json ->> 'no_winner_rule', ''),
          public.app_config_text('pool_settlement_no_winner_rule', 'refund_all')
        ))
      END;

      IF v_match_state = 'cancelled' THEN
        v_no_winner_rule := 'refund_all';
      END IF;

      IF v_no_winner_rule = 'roll_over' THEN
        UPDATE public.match_pool_settlements
        SET status = 'pending',
            error_message = NULL,
            metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
              'settlement_kind', 'roll_over_pending',
              'no_winner_rule', v_no_winner_rule,
              'result_code', v_match.result_code
            )
        WHERE id = v_settlement.id
        RETURNING * INTO v_settlement;

        UPDATE public.match_pools
        SET status = 'locked',
            updated_at = timezone('utc', now()),
            metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
              'roll_over_pending_at', timezone('utc', now())
            )
        WHERE id = p_pool_id;

        RETURN jsonb_build_object(
          'status', 'roll_over_pending',
          'pool_id', p_pool_id,
          'settlement_id', v_settlement.id
        );
      END IF;

      FOR v_entry IN
        SELECT *
        FROM public.match_pool_entries
        WHERE pool_id = p_pool_id
          AND status = 'active'
        ORDER BY created_at, id
        FOR UPDATE
      LOOP
        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_stake',
          p_direction => 'debit',
          p_amount_fet => v_entry.amount_fet,
          p_balance_bucket => 'staked',
          p_idempotency_key => 'settlement_stake_release:' || v_entry.id::text,
          p_reference_type => 'match_pool_settlement',
          p_reference_id => v_settlement.id::text,
          p_title => 'Pool stake released',
          p_metadata => jsonb_build_object(
            'entry_id', v_entry.id,
            'match_state', v_match_state,
            'result_camp_id', CASE WHEN v_match_state = 'final' THEN v_result_camp.id ELSE NULL END,
            'settlement_kind', CASE WHEN v_no_winner_rule = 'platform_hold' THEN 'platform_hold' ELSE 'refund' END
          ),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id
        );

        IF v_no_winner_rule <> 'platform_hold' THEN
          PERFORM public.wallet_post_transaction(
            p_user_id => v_entry.user_id,
            p_transaction_type => 'pool_refund',
            p_direction => 'credit',
            p_amount_fet => v_entry.amount_fet,
            p_balance_bucket => 'available',
            p_idempotency_key => 'pool_refund:' || v_entry.id::text,
            p_reference_type => 'match_pool_settlement',
            p_reference_id => v_settlement.id::text,
            p_title => CASE
              WHEN v_match_state = 'cancelled' THEN 'Pool refunded because match was cancelled'
              WHEN v_match_state = 'postponed' THEN 'Pool refunded because match was postponed'
              ELSE 'Pool refunded because no winning entries joined'
            END,
            p_metadata => jsonb_build_object(
              'entry_id', v_entry.id,
              'match_state', v_match_state,
              'result_camp_id', CASE WHEN v_match_state = 'final' THEN v_result_camp.id ELSE NULL END,
              'refund_reason', CASE
                WHEN v_match_state = 'cancelled' THEN 'match_cancelled'
                WHEN v_match_state = 'postponed' THEN 'match_postponed'
                ELSE 'no_winning_entries'
              END
            ),
            p_match_id => v_pool.match_id,
            p_pool_id => p_pool_id,
            p_entry_id => v_entry.id,
            p_settlement_id => v_settlement.id,
            p_venue_id => v_pool.venue_id
          );

          UPDATE public.match_pool_entries
          SET status = 'refunded',
              payout_fet = v_entry.amount_fet,
              updated_at = timezone('utc', now())
          WHERE id = v_entry.id;

          v_total_paid := v_total_paid + v_entry.amount_fet;
        ELSE
          UPDATE public.match_pool_entries
          SET status = 'lost',
              payout_fet = 0,
              updated_at = timezone('utc', now())
          WHERE id = v_entry.id;
        END IF;

        v_processed_entries := v_processed_entries + 1;
      END LOOP;

      IF v_match_state = 'final' THEN
        UPDATE public.match_pool_camps
        SET is_winning_camp = (id = v_result_camp.id),
            updated_at = timezone('utc', now())
        WHERE pool_id = p_pool_id;
      ELSE
        UPDATE public.match_pool_camps
        SET is_winning_camp = false,
            updated_at = timezone('utc', now())
        WHERE pool_id = p_pool_id;
      END IF;

      UPDATE public.match_pool_settlements
      SET status = 'completed',
          completed_at = timezone('utc', now()),
          total_paid_fet = v_total_paid,
          payout_per_winner_fet = 0,
          metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
            'settlement_kind', CASE
              WHEN v_no_winner_rule = 'platform_hold' THEN 'platform_hold'
              ELSE 'refund_all'
            END,
            'match_state', v_match_state,
            'no_winner_rule', v_no_winner_rule,
            'refunded_entries', CASE WHEN v_no_winner_rule = 'platform_hold' THEN 0 ELSE v_processed_entries END,
            'platform_held_fet', CASE WHEN v_no_winner_rule = 'platform_hold' THEN v_total_active ELSE 0 END,
            'completed_at', timezone('utc', now())
          )
      WHERE id = v_settlement.id
      RETURNING * INTO v_settlement;

      UPDATE public.match_pools
      SET status = CASE WHEN v_match_state = 'cancelled' THEN 'cancelled'::public.match_pool_status ELSE 'settled'::public.match_pool_status END,
          settled_at = CASE WHEN v_match_state = 'cancelled' THEN settled_at ELSE coalesce(settled_at, timezone('utc', now())) END,
          updated_at = timezone('utc', now())
      WHERE id = p_pool_id;

      PERFORM public.sports_bar_write_audit(
        CASE
          WHEN v_match_state = 'cancelled' THEN 'pool_cancelled_refunded'
          WHEN v_match_state = 'postponed' THEN 'pool_postponed_refunded'
          WHEN v_no_winner_rule = 'platform_hold' THEN 'pool_settled_platform_hold'
          ELSE 'pool_settled_no_winner_refund'
        END,
        'settlement',
        v_settlement.id::text,
        NULL,
        jsonb_build_object(
          'pool_id', p_pool_id,
          'match_id', v_pool.match_id,
          'entries', v_processed_entries,
          'total_paid_fet', v_total_paid,
          'match_state', v_match_state
        )
      );

      RETURN jsonb_build_object(
        'status', CASE
          WHEN v_no_winner_rule = 'platform_hold' THEN 'platform_held'
          ELSE 'refunded'
        END,
        'pool_id', p_pool_id,
        'settlement_id', v_settlement.id,
        'entries', v_processed_entries,
        'total_paid_fet', v_total_paid,
        'reason', CASE
          WHEN v_match_state = 'cancelled' THEN 'match_cancelled'
          WHEN v_match_state = 'postponed' THEN 'match_postponed'
          ELSE 'no_winning_entries'
        END
      );
    END IF;

    FOR v_entry IN
      SELECT *
      FROM public.match_pool_entries
      WHERE pool_id = p_pool_id
        AND status = 'active'
      ORDER BY created_at, id
      FOR UPDATE
    LOOP
      PERFORM public.wallet_post_transaction(
        p_user_id => v_entry.user_id,
        p_transaction_type => 'pool_stake',
        p_direction => 'debit',
        p_amount_fet => v_entry.amount_fet,
        p_balance_bucket => 'staked',
        p_idempotency_key => 'settlement_stake_release:' || v_entry.id::text,
        p_reference_type => 'match_pool_settlement',
        p_reference_id => v_settlement.id::text,
        p_title => 'Pool stake settled',
        p_metadata => jsonb_build_object('entry_id', v_entry.id, 'result_camp_id', v_result_camp.id),
        p_match_id => v_pool.match_id,
        p_pool_id => p_pool_id,
        p_entry_id => v_entry.id,
        p_settlement_id => v_settlement.id,
        p_venue_id => v_pool.venue_id
      );

      IF v_entry.camp_id = v_result_camp.id THEN
        v_row_index := v_row_index + 1;

        IF v_payout_rule = 'equal_per_winner' THEN
          IF v_row_index = v_winner_count THEN
            v_bonus_share := v_distributable_losing - v_bonus_allocated;
          ELSE
            v_bonus_share := floor(v_distributable_losing::numeric / greatest(v_winner_count, 1)::numeric)::bigint;
          END IF;
        ELSIF v_row_index = v_winner_count THEN
          v_bonus_share := v_distributable_losing - v_bonus_allocated;
        ELSE
          v_bonus_share := floor((v_distributable_losing::numeric * v_entry.amount_fet::numeric) / greatest(v_winning_stake, 1)::numeric)::bigint;
        END IF;

        v_bonus_allocated := v_bonus_allocated + v_bonus_share;
        v_payout := v_entry.amount_fet + v_bonus_share;

        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'credit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'pending',
          p_idempotency_key => 'pool_win_pending:' || v_entry.id::text,
          p_reference_type => 'match_pool_settlement',
          p_reference_id => v_settlement.id::text,
          p_title => 'Pool win pending settlement',
          p_metadata => jsonb_build_object(
            'entry_id', v_entry.id,
            'winning_stake_returned_fet', v_entry.amount_fet,
            'losing_stake_share_fet', v_bonus_share,
            'result_camp_id', v_result_camp.id
          ),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id,
          p_status => 'pending'
        );

        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'debit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'pending',
          p_idempotency_key => 'pool_win_pending_release:' || v_entry.id::text,
          p_reference_type => 'match_pool_settlement',
          p_reference_id => v_settlement.id::text,
          p_title => 'Pool win settlement finalized',
          p_metadata => jsonb_build_object('entry_id', v_entry.id, 'result_camp_id', v_result_camp.id),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id
        );

        PERFORM public.wallet_post_transaction(
          p_user_id => v_entry.user_id,
          p_transaction_type => 'pool_win',
          p_direction => 'credit',
          p_amount_fet => v_payout,
          p_balance_bucket => 'available',
          p_idempotency_key => 'pool_win:' || v_entry.id::text,
          p_reference_type => 'match_pool_settlement',
          p_reference_id => v_settlement.id::text,
          p_title => 'Won match pool',
          p_metadata => jsonb_build_object(
            'entry_id', v_entry.id,
            'winning_stake_returned_fet', v_entry.amount_fet,
            'losing_stake_share_fet', v_bonus_share,
            'result_camp_id', v_result_camp.id,
            'payout_rule', v_payout_rule
          ),
          p_match_id => v_pool.match_id,
          p_pool_id => p_pool_id,
          p_entry_id => v_entry.id,
          p_settlement_id => v_settlement.id,
          p_venue_id => v_pool.venue_id
        );

        UPDATE public.match_pool_entries
        SET status = 'won',
            payout_fet = v_payout,
            updated_at = timezone('utc', now())
        WHERE id = v_entry.id;

        v_total_paid := v_total_paid + v_payout;
      ELSE
        UPDATE public.match_pool_entries
        SET status = 'lost',
            payout_fet = 0,
            updated_at = timezone('utc', now())
        WHERE id = v_entry.id;
      END IF;

      v_processed_entries := v_processed_entries + 1;
    END LOOP;

    UPDATE public.match_pool_camps
    SET is_winning_camp = (id = v_result_camp.id),
        updated_at = timezone('utc', now())
    WHERE pool_id = p_pool_id;

    UPDATE public.match_pool_settlements
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        total_paid_fet = v_total_paid,
        payout_per_winner_fet = CASE
          WHEN v_winner_count > 0 THEN floor(v_total_paid::numeric / v_winner_count::numeric)::bigint
          ELSE 0
        END,
        metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
          'settlement_kind', 'winner_payout',
          'total_active_stake_fet', v_total_active,
          'winning_stake_fet', v_winning_stake,
          'losing_stake_fet', v_losing_stake,
          'distributable_losing_stake_fet', v_distributable_losing,
          'platform_fee_fet', v_platform_fee,
          'venue_fee_fet', v_venue_fee,
          'payout_rule', v_payout_rule,
          'pending_settlement_rows_created', true,
          'completed_at', timezone('utc', now())
        )
    WHERE id = v_settlement.id
    RETURNING * INTO v_settlement;

    UPDATE public.match_pools
    SET status = 'settled',
        result_camp_id = v_result_camp.id,
        settled_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
    WHERE id = p_pool_id;

    PERFORM public.sports_bar_write_audit(
      'pool_settled',
      'settlement',
      v_settlement.id::text,
      NULL,
      jsonb_build_object(
        'pool_id', p_pool_id,
        'match_id', v_pool.match_id,
        'result_code', v_match.result_code,
        'winners_count', v_winner_count,
        'total_paid_fet', v_total_paid,
        'losing_stake_fet', v_losing_stake,
        'payout_rule', v_payout_rule
      )
    );

    RETURN jsonb_build_object(
      'status', 'settled',
      'pool_id', p_pool_id,
      'settlement_id', v_settlement.id,
      'winners_count', v_winner_count,
      'winning_stake_fet', v_winning_stake,
      'losing_stake_fet', v_losing_stake,
      'total_paid_fet', v_total_paid,
      'payout_rule', v_payout_rule
    );
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

      IF v_pool.id IS NULL THEN
        SELECT *
        INTO v_pool
        FROM public.match_pools
        WHERE id = p_pool_id;
      END IF;

      IF v_pool.id IS NOT NULL THEN
        INSERT INTO public.match_pool_settlements (
          pool_id,
          match_id,
          status,
          idempotency_key,
          error_message,
          metadata
        )
        VALUES (
          p_pool_id,
          v_pool.match_id,
          'failed',
          v_settlement_key,
          v_error,
          jsonb_build_object(
            'error', v_error,
            'failed_at', timezone('utc', now()),
            'match_state', v_match_state,
            'retryable', true
          )
        )
        ON CONFLICT (pool_id) DO UPDATE
        SET status = 'failed',
            match_id = excluded.match_id,
            error_message = excluded.error_message,
            metadata = coalesce(public.match_pool_settlements.metadata, '{}'::jsonb) || excluded.metadata
        RETURNING * INTO v_settlement;

        UPDATE public.match_pools
        SET status = 'locked',
            updated_at = timezone('utc', now()),
            metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
              'last_settlement_error', v_error,
              'last_settlement_failed_at', timezone('utc', now())
            )
        WHERE id = p_pool_id
          AND status::text = 'settling';

        PERFORM public.sports_bar_write_audit(
          'pool_settlement_failed',
          'settlement',
          v_settlement.id::text,
          NULL,
          jsonb_build_object(
            'pool_id', p_pool_id,
            'match_id', v_pool.match_id,
            'error', v_error,
            'retryable', true
          )
        );
      END IF;

      RETURN jsonb_build_object(
        'status', 'failed',
        'pool_id', p_pool_id,
        'settlement_id', v_settlement.id,
        'error', v_error
      );
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_pool(
  p_pool_id uuid,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN public.settle_match_pool(p_pool_id)
    || jsonb_build_object(
      'requested_idempotency_key',
      nullif(trim(coalesce(p_idempotency_key, '')), '')
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.reverse_or_refund_pool_if_match_cancelled(p_pool_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN public.settle_match_pool(p_pool_id)
    || jsonb_build_object('legacy_wrapper', 'reverse_or_refund_pool_if_match_cancelled');
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_finished_match_pools(p_limit integer DEFAULT 50)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_pool_id uuid;
  v_result jsonb;
  v_count integer := 0;
BEGIN
  FOR v_pool_id IN
    SELECT p.id
    FROM public.match_pools p
    JOIN public.matches m ON m.id = p.match_id
    WHERE p.status::text IN ('open', 'locked', 'live', 'settling', 'cancelled')
      AND (
        (
          CASE
            WHEN lower(coalesce(m.status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
            WHEN lower(coalesce(m.match_status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
            WHEN lower(coalesce(m.status, '')) = 'postponed' THEN 'postponed'
            WHEN lower(coalesce(m.match_status, '')) = 'postponed' THEN 'postponed'
            WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
            WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
            ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), 'scheduled'))
          END
        ) IN ('cancelled', 'postponed')
        OR (
          (
            CASE
              WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
              WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
              ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), 'scheduled'))
            END
          ) = 'final'
          AND m.result_code IS NOT NULL
        )
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.match_pool_settlements s
        WHERE s.pool_id = p.id
          AND s.status = 'completed'
      )
    ORDER BY m.match_date, p.created_at, p.id
    LIMIT greatest(1, least(coalesce(p_limit, 50), 250))
  LOOP
    v_result := public.settle_match_pool(v_pool_id);

    IF coalesce(v_result ->> 'status', '') NOT IN ('failed', 'held', 'roll_over_pending', 'requires_reversal') THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_run_pool_settlement(p_limit integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_user_id uuid := public.require_active_admin_user();
  v_count integer := 0;
  v_failed_count bigint := 0;
  v_pending_count bigint := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 250));
BEGIN
  v_count := public.settle_finished_match_pools(v_limit);

  SELECT count(*)::bigint
  INTO v_failed_count
  FROM public.match_pool_settlements
  WHERE status::text = 'failed';

  SELECT count(*)::bigint
  INTO v_pending_count
  FROM public.match_pool_settlements
  WHERE status::text = 'pending';

  INSERT INTO public.pool_operation_audit_logs (
    actor_user_id,
    action,
    metadata
  )
  VALUES (
    v_user_id,
    'admin_run_pool_settlement',
    jsonb_build_object(
      'limit', v_limit,
      'settled_pools', v_count,
      'failed_settlements', v_failed_count,
      'pending_settlements', v_pending_count
    )
  );

  PERFORM public.admin_log_action(
    'run_pool_settlement',
    'pools',
    'match_pool_settlement_batch',
    NULL,
    NULL,
    jsonb_build_object(
      'settled_pools', v_count,
      'failed_settlements', v_failed_count,
      'pending_settlements', v_pending_count
    ),
    jsonb_build_object('limit', v_limit)
  );

  RETURN jsonb_build_object(
    'status', 'completed',
    'settled_pools', v_count,
    'failed_settlements', v_failed_count,
    'pending_settlements', v_pending_count,
    'limit', v_limit
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_pool_operations_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_open_pools bigint := 0;
  v_locked_pools bigint := 0;
  v_settling_pools bigint := 0;
  v_settled_24h bigint := 0;
  v_failed_settlements bigint := 0;
  v_pending_final_pools bigint := 0;
  v_stale_settling_pools bigint := 0;
  v_total_open_stake bigint := 0;
  v_social_cards_missing bigint := 0;
  v_invites_7d bigint := 0;
  v_invite_rewards_7d bigint := 0;
BEGIN
  PERFORM public.require_active_admin_user();

  SELECT count(*)::bigint, coalesce(sum(total_staked_fet)::bigint, 0)
  INTO v_open_pools, v_total_open_stake
  FROM public.match_pools
  WHERE status::text = 'open';

  SELECT count(*)::bigint INTO v_locked_pools
  FROM public.match_pools
  WHERE status::text = 'locked';

  SELECT count(*)::bigint INTO v_settling_pools
  FROM public.match_pools
  WHERE status::text = 'settling';

  SELECT count(*)::bigint INTO v_settled_24h
  FROM public.match_pools
  WHERE status::text = 'settled'
    AND settled_at >= timezone('utc', now()) - interval '24 hours';

  SELECT count(*)::bigint INTO v_failed_settlements
  FROM public.match_pool_settlements
  WHERE status::text = 'failed';

  SELECT count(*)::bigint INTO v_pending_final_pools
  FROM public.match_pools p
  JOIN public.matches m ON m.id = p.match_id
  WHERE p.status::text IN ('open', 'locked', 'live', 'settling')
    AND (
      (
        CASE
          WHEN lower(coalesce(m.status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
          WHEN lower(coalesce(m.match_status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
          WHEN lower(coalesce(m.status, '')) = 'postponed' THEN 'postponed'
          WHEN lower(coalesce(m.match_status, '')) = 'postponed' THEN 'postponed'
          WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
          WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
          ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), 'scheduled'))
        END
      ) IN ('cancelled', 'postponed')
      OR (
        (
          CASE
            WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
            WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
            ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), 'scheduled'))
          END
        ) = 'final'
        AND m.result_code IS NOT NULL
      )
    );

  SELECT count(*)::bigint INTO v_stale_settling_pools
  FROM public.match_pools
  WHERE status::text = 'settling'
    AND updated_at < timezone('utc', now()) - interval '15 minutes';

  SELECT count(*)::bigint INTO v_social_cards_missing
  FROM public.match_pools
  WHERE status::text IN ('open', 'locked', 'settled')
    AND nullif(trim(coalesce(social_card_url, '')), '') IS NULL;

  SELECT count(*)::bigint INTO v_invites_7d
  FROM public.match_pool_invites
  WHERE created_at >= timezone('utc', now()) - interval '7 days';

  SELECT coalesce(sum(reward_amount_fet)::bigint, 0) INTO v_invite_rewards_7d
  FROM public.match_pool_invites
  WHERE status = 'rewarded'
    AND rewarded_at >= timezone('utc', now()) - interval '7 days';

  RETURN jsonb_build_object(
    'openPools', coalesce(v_open_pools, 0),
    'lockedPools', coalesce(v_locked_pools, 0),
    'settlingPools', coalesce(v_settling_pools, 0),
    'settled24h', coalesce(v_settled_24h, 0),
    'failedSettlements', coalesce(v_failed_settlements, 0),
    'pendingFinalPools', coalesce(v_pending_final_pools, 0),
    'staleSettlingPools', coalesce(v_stale_settling_pools, 0),
    'totalOpenStakeFet', coalesce(v_total_open_stake, 0),
    'socialCardsMissing', coalesce(v_social_cards_missing, 0),
    'invites7d', coalesce(v_invites_7d, 0),
    'inviteRewards7d', coalesce(v_invite_rewards_7d, 0)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.admin_pool_operations_queue(integer);

CREATE FUNCTION public.admin_pool_operations_queue(p_limit integer DEFAULT 50)
RETURNS TABLE(
  pool_id uuid,
  title text,
  scope text,
  country_code text,
  country_id uuid,
  venue_id uuid,
  venue_name text,
  match_id text,
  match_label text,
  competition_name text,
  kickoff_at timestamp with time zone,
  match_status text,
  result_code text,
  pool_status text,
  total_members bigint,
  total_staked_fet bigint,
  camps jsonb,
  settlement_status text,
  settlement_started_at timestamp with time zone,
  settlement_completed_at timestamp with time zone,
  settlement_error text,
  share_url text,
  social_card_url text,
  needs_settlement boolean,
  needs_social_card boolean,
  age_minutes bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
  WITH _auth AS (
    SELECT public.require_active_admin_user()
  ),
  pool_rows AS (
    SELECT
      p.*,
      v.name AS venue_name,
      coalesce(m.home_team, 'Home') || ' vs ' || coalesce(m.away_team, 'Away') AS match_label,
      m.competition_name,
      m.match_date AS kickoff_at,
      coalesce(m.match_status, m.status) AS match_status_label,
      m.result_code AS match_result_code,
      CASE
        WHEN lower(coalesce(m.status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
        WHEN lower(coalesce(m.match_status, '')) IN ('cancelled', 'canceled') THEN 'cancelled'
        WHEN lower(coalesce(m.status, '')) = 'postponed' THEN 'postponed'
        WHEN lower(coalesce(m.match_status, '')) = 'postponed' THEN 'postponed'
        WHEN lower(coalesce(m.status, '')) IN ('final', 'finished', 'complete', 'completed') THEN 'final'
        WHEN lower(coalesce(m.match_status, '')) = 'finished' THEN 'final'
        ELSE lower(coalesce(nullif(m.status, ''), nullif(m.match_status, ''), 'scheduled'))
      END AS normalized_match_status,
      coalesce(ps.camps, '[]'::jsonb) AS pool_camps,
      s.status::text AS settlement_status_text,
      s.started_at,
      s.completed_at,
      coalesce(s.error_message, s.metadata ->> 'error') AS settlement_error_text
    FROM public.match_pools p
    LEFT JOIN public.match_pool_stats ps ON ps.id = p.id
    LEFT JOIN public.app_matches m ON m.id = p.match_id
    LEFT JOIN public.venues v ON v.id = p.venue_id
    LEFT JOIN public.match_pool_settlements s ON s.pool_id = p.id
    WHERE
      p.status::text IN ('open', 'locked', 'live', 'settling')
      OR s.status::text IN ('failed', 'pending', 'running')
      OR p.created_at >= timezone('utc', now()) - interval '30 days'
  )
  SELECT
    r.id AS pool_id,
    r.title,
    r.scope::text,
    r.country_code,
    r.country_id,
    r.venue_id,
    r.venue_name,
    r.match_id,
    r.match_label,
    r.competition_name,
    r.kickoff_at,
    r.match_status_label AS match_status,
    r.match_result_code AS result_code,
    r.status::text AS pool_status,
    r.total_members,
    r.total_staked_fet,
    r.pool_camps AS camps,
    r.settlement_status_text AS settlement_status,
    r.started_at AS settlement_started_at,
    r.completed_at AS settlement_completed_at,
    r.settlement_error_text AS settlement_error,
    r.share_url,
    r.social_card_url,
    (
      r.status::text IN ('open', 'locked', 'live', 'settling')
      AND (
        r.normalized_match_status IN ('cancelled', 'postponed')
        OR (r.normalized_match_status = 'final' AND r.match_result_code IS NOT NULL)
      )
      AND coalesce(r.settlement_status_text, '') <> 'completed'
    ) AS needs_settlement,
    nullif(trim(coalesce(r.social_card_url, '')), '') IS NULL AS needs_social_card,
    floor(extract(epoch FROM (timezone('utc', now()) - r.created_at)) / 60)::bigint AS age_minutes
  FROM pool_rows r
  CROSS JOIN _auth
  ORDER BY
    CASE
      WHEN r.settlement_status_text = 'failed' THEN 0
      WHEN r.status::text = 'settling' THEN 1
      WHEN r.normalized_match_status IN ('cancelled', 'postponed') THEN 2
      WHEN r.status::text IN ('open', 'locked', 'live')
        AND r.normalized_match_status = 'final'
        AND r.match_result_code IS NOT NULL THEN 3
      WHEN nullif(trim(coalesce(r.social_card_url, '')), '') IS NULL THEN 4
      ELSE 5
    END,
    r.kickoff_at NULLS LAST,
    r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
$$;

REVOKE ALL ON FUNCTION public.app_config_text(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_match_pool(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_match_pool(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.settle_match_pool(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.settle_finished_match_pools(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_finished_match_pools(integer) FROM anon;
REVOKE ALL ON FUNCTION public.settle_finished_match_pools(integer) FROM authenticated;
REVOKE ALL ON FUNCTION public.settle_pool(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_pool(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.settle_pool(uuid, text) FROM authenticated;
REVOKE ALL ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.admin_run_pool_settlement(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_pool_operations_kpis() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_pool_operations_queue(integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_config_text(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.settle_match_pool(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.settle_finished_match_pools(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.settle_pool(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.reverse_or_refund_pool_if_match_cancelled(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_run_pool_settlement(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_pool_operations_kpis() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_pool_operations_queue(integer) TO authenticated, service_role;
