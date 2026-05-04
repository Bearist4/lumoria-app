-- Bumps the free-tier ticket cap from 5 → 10 in the enforce_ticket_cap
-- trigger so the server matches FreeCaps.baseTicketCap on the client.
-- Reward bonus (+2 with invite_reward_kind = 'tickets') is unchanged.
-- Mirrors the phase 2 signature in
-- 20260507000000_paywall_phase_2_kill_switch_and_purchase.sql.

CREATE OR REPLACE FUNCTION public.enforce_ticket_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_grandfathered_at timestamptz;
  v_is_premium       boolean;
  v_premium_expires  timestamptz;
  v_reward_kind      text;
  v_count            int;
  v_cap              int;
BEGIN
  IF NOT public.monetisation_enabled() THEN
    RETURN NEW;
  END IF;

  SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
    INTO v_grandfathered_at, v_is_premium, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  IF v_grandfathered_at IS NOT NULL THEN RETURN NEW; END IF;
  IF v_is_premium AND
     (v_premium_expires IS NULL OR v_premium_expires > now())
  THEN
    RETURN NEW;
  END IF;

  v_cap := 10 + (CASE WHEN v_reward_kind = 'tickets' THEN 2 ELSE 0 END);

  SELECT count(*) INTO v_count
    FROM public.tickets
   WHERE user_id = NEW.user_id;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'ticket_cap_exceeded' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;
