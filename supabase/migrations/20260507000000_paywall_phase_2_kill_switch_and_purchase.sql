-- Paywall Phase 2: monetisation kill-switch + set_premium_from_transaction.
-- The kill-switch makes every Phase 1 cap trigger no-op until the
-- developer flips it on with:
--
--   UPDATE public.app_settings SET monetisation_enabled = true
--    WHERE id = 'singleton';

-- 1. app_settings singleton + RLS.
CREATE TABLE IF NOT EXISTS public.app_settings (
  id                   text PRIMARY KEY,
  monetisation_enabled boolean NOT NULL DEFAULT false,
  updated_at           timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.app_settings (id) VALUES ('singleton')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_read_all ON public.app_settings;
CREATE POLICY app_settings_read_all
  ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT / UPDATE / DELETE policies for authenticated. Updates land
-- via the service role only (Supabase dashboard or admin SQL).

-- 2. Helper: monetisation_enabled() — single source of truth for both
--    cap triggers and the purchase RPC. STABLE so the planner caches
--    per-statement.
CREATE OR REPLACE FUNCTION public.monetisation_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT monetisation_enabled
    FROM public.app_settings
   WHERE id = 'singleton'
   LIMIT 1;
$function$;

GRANT EXECUTE ON FUNCTION public.monetisation_enabled() TO authenticated;

-- 3. Update cap triggers to honour the kill switch.
--    Same body as Phase 1, with an early return when the flag is off.
CREATE OR REPLACE FUNCTION public.enforce_memory_cap()
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
  -- Kill switch: caps don't fire while monetisation is off.
  IF NOT public.monetisation_enabled() THEN
    RETURN NEW;
  END IF;

  SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
    INTO v_grandfathered_at, v_is_premium, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  IF v_grandfathered_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF v_is_premium AND
     (v_premium_expires IS NULL OR v_premium_expires > now())
  THEN
    RETURN NEW;
  END IF;

  v_cap := 3 + (CASE WHEN v_reward_kind = 'memory' THEN 1 ELSE 0 END);

  SELECT count(*) INTO v_count
    FROM public.memories
   WHERE user_id = NEW.user_id;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'memory_cap_exceeded' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;

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

  v_cap := 5 + (CASE WHEN v_reward_kind = 'tickets' THEN 2 ELSE 0 END);

  SELECT count(*) INTO v_count
    FROM public.tickets
   WHERE user_id = NEW.user_id;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'ticket_cap_exceeded' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;

-- 4. set_premium_from_transaction RPC.
--
-- Phase 2 trusts the iOS-side StoreKit verification. The iOS app passes
-- through productId, transactionId, and expiresAt fields that the
-- Transaction.payloadValue has already authenticated locally. Phase 5
-- (ASSN2) layers server-side push verification on top so the client
-- can never lie post-go-live.
--
-- While the kill-switch is off, this RPC raises immediately — even a
-- compromised client can't promote a profile to premium until you flip
-- the flag.
CREATE OR REPLACE FUNCTION public.set_premium_from_transaction(
  p_product_id     text,
  p_transaction_id text,
  p_expires_at     timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF NOT public.monetisation_enabled() THEN
    RAISE EXCEPTION 'monetisation_disabled' USING ERRCODE = 'P0001';
  END IF;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_product_id IS NULL OR length(p_product_id) = 0
     OR p_transaction_id IS NULL OR length(p_transaction_id) = 0
  THEN
    RAISE EXCEPTION 'invalid_arguments' USING ERRCODE = '22P02';
  END IF;

  UPDATE public.profiles
     SET is_premium             = true,
         premium_expires_at     = p_expires_at,
         premium_product_id     = p_product_id,
         premium_transaction_id = p_transaction_id
   WHERE user_id = v_uid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_premium_from_transaction(text, text, timestamptz)
  TO authenticated;
