-- Paywall Phase 1 foundation: profile columns for entitlement +
-- invite-reward, generalised protect trigger, cap-enforcement triggers
-- on memories and tickets, and the claim_invite_reward RPC.

-- 1. New profile columns.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_premium               boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS premium_expires_at       timestamptz NULL,
  ADD COLUMN IF NOT EXISTS premium_product_id       text NULL,
  ADD COLUMN IF NOT EXISTS premium_transaction_id   text NULL,
  ADD COLUMN IF NOT EXISTS invite_reward_kind       text NULL
    CHECK (invite_reward_kind IN ('memory','tickets')),
  ADD COLUMN IF NOT EXISTS invite_reward_claimed_at timestamptz NULL;

-- 2. Generalised protect trigger replaces profiles_protect_grandfather.
CREATE OR REPLACE FUNCTION public.profiles_protect_managed_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF current_user = 'authenticated' THEN
    IF OLD.grandfathered_at         IS DISTINCT FROM NEW.grandfathered_at
    OR OLD.is_premium               IS DISTINCT FROM NEW.is_premium
    OR OLD.premium_expires_at       IS DISTINCT FROM NEW.premium_expires_at
    OR OLD.premium_product_id       IS DISTINCT FROM NEW.premium_product_id
    OR OLD.premium_transaction_id   IS DISTINCT FROM NEW.premium_transaction_id
    OR OLD.invite_reward_kind       IS DISTINCT FROM NEW.invite_reward_kind
    OR OLD.invite_reward_claimed_at IS DISTINCT FROM NEW.invite_reward_claimed_at
    THEN
      RAISE EXCEPTION 'managed_column_readonly';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS profiles_protect_grandfather ON public.profiles;
DROP TRIGGER IF EXISTS profiles_protect_managed_columns ON public.profiles;
CREATE TRIGGER profiles_protect_managed_columns
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.profiles_protect_managed_columns();

-- 3. Memory cap trigger.
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
  SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
    INTO v_grandfathered_at, v_is_premium, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  -- Grandfather: no cap.
  IF v_grandfathered_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Active premium (lifetime, in-trial, or paid sub): no cap.
  IF v_is_premium AND
     (v_premium_expires IS NULL OR v_premium_expires > now())
  THEN
    RETURN NEW;
  END IF;

  -- Free tier: 3 base + 1 if invite reward is 'memory'.
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

DROP TRIGGER IF EXISTS enforce_memory_cap ON public.memories;
CREATE TRIGGER enforce_memory_cap
BEFORE INSERT ON public.memories
FOR EACH ROW
EXECUTE FUNCTION public.enforce_memory_cap();

-- 4. Ticket cap trigger.
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

DROP TRIGGER IF EXISTS enforce_ticket_cap ON public.tickets;
CREATE TRIGGER enforce_ticket_cap
BEFORE INSERT ON public.tickets
FOR EACH ROW
EXECUTE FUNCTION public.enforce_ticket_cap();

-- 5. claim_invite_reward RPC.
--
-- Eligibility uses claimed_by — the column populated by the existing
-- claim_invite RPC when a friend signs up via an invite link. Both the
-- inviter (inviter_id = me, claimed_by IS NOT NULL on at least one of
-- their invites) and the invitee (claimed_by = me on at least one
-- invite) can call this independently. The claim is one-shot per
-- profile: invite_reward_kind goes from NULL to 'memory' or 'tickets'
-- and stays that way.
CREATE OR REPLACE FUNCTION public.claim_invite_reward(p_kind text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_existing text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_kind NOT IN ('memory', 'tickets') THEN
    RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22P02';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.invites
     WHERE (inviter_id = v_uid AND claimed_by IS NOT NULL)
        OR claimed_by = v_uid
  ) THEN
    RAISE EXCEPTION 'no_claimed_invite' USING ERRCODE = 'P0001';
  END IF;

  SELECT invite_reward_kind INTO v_existing
    FROM public.profiles WHERE user_id = v_uid;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'already_claimed' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
     SET invite_reward_kind     = p_kind,
         invite_reward_claimed_at = now()
   WHERE user_id = v_uid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.claim_invite_reward(text) TO authenticated;
