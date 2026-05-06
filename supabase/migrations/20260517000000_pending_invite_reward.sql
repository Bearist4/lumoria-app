-- Lookup helper for the new "pick your invite reward" sheets. The
-- referree (invitee) and referrer both land on a sheet once the
-- invitee creates their first ticket — this RPC tells the client
-- which role applies to the signed-in user, or that no reward is
-- pending (already claimed, or no qualifying invite).
--
-- Returns one of: 'referrer' | 'referree' | NULL.
--   - referrer: this user sent an invite that has been redeemed
--   - referree: this user's claimed_by row was redeemed (their first
--               ticket has been persisted by the
--               fire_link_on_first_ticket trigger)
--   - NULL:     no qualifying invite, OR the user already picked
--               their invite_reward_kind (one-shot reward).
--
-- Wrapped in SECURITY DEFINER so it bypasses RLS — the caller can
-- safely peek at invite rows where they're the claimed_by user
-- without needing a SELECT policy that exposes that column.

CREATE OR REPLACE FUNCTION public.pending_invite_reward()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
STABLE
AS $function$
DECLARE
  v_uid             uuid := auth.uid();
  v_already_claimed boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT (invite_reward_kind IS NOT NULL)
    INTO v_already_claimed
    FROM public.profiles
   WHERE user_id = v_uid;

  -- One-shot reward — once the user picks, no more sheets.
  IF v_already_claimed THEN
    RETURN NULL;
  END IF;

  -- Inviter side: any non-revoked invite of mine has been redeemed.
  IF EXISTS (
    SELECT 1
      FROM public.invites
     WHERE inviter_id  = v_uid
       AND redeemed_at IS NOT NULL
       AND revoked_at  IS NULL
  ) THEN
    RETURN 'referrer';
  END IF;

  -- Invitee side: an invite where I'm claimed_by has been redeemed
  -- (which the fire_link_on_first_ticket trigger sets after I
  -- persist my first ticket).
  IF EXISTS (
    SELECT 1
      FROM public.invites
     WHERE claimed_by  = v_uid
       AND redeemed_at IS NOT NULL
       AND revoked_at  IS NULL
  ) THEN
    RETURN 'referree';
  END IF;

  RETURN NULL;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.pending_invite_reward() TO authenticated;
