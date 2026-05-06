-- Closes the gap where an invitee who already had tickets at claim
-- time would never see their invite redeem (the trigger fires on
-- *first* ticket, but they were past that). Two parts:
--
--   1. Refactor the redemption work into a single idempotent helper
--      `fire_invite_redemption(invite_id)`. It no-ops when the invite
--      is already redeemed / revoked, so callers can fire it from
--      anywhere without double-redeeming or double-notifying.
--
--   2. Drop the "is this the user's first ticket?" gate inside
--      `fire_link_on_first_ticket` and lean on the helper's
--      idempotency instead — that lets a 5th ticket from a brand-new
--      invitee still trigger redemption if their first 4 happened
--      before they tapped the invite link.
--
--   3. Add `fire_link_on_invite_claim`, a new AFTER UPDATE OF
--      claimed_by trigger on `public.invites`. When a user just
--      claimed an invite AND already has tickets, redeem on the spot
--      — the ticket-side trigger has nothing to fire on for them.
--
-- Net effect: the inviter's APNs push goes out (and the invitee's
-- own reward sheet becomes pending) the moment the redemption
-- condition is satisfied, regardless of which side moved last.

-- Idempotent redemption helper. Stamps redeemed_at + queues the
-- inviter notification. Safe to call from any code path; bails on
-- already-redeemed / revoked invites.
CREATE OR REPLACE FUNCTION public.fire_invite_redemption(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_inviter_id uuid;
  v_already_done boolean;
BEGIN
  SELECT
    inviter_id,
    (redeemed_at IS NOT NULL OR revoked_at IS NOT NULL)
  INTO v_inviter_id, v_already_done
  FROM public.invites
  WHERE id = p_invite_id;

  IF v_already_done OR v_inviter_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.invites
     SET redeemed_at = now()
   WHERE id = p_invite_id
     AND redeemed_at IS NULL;

  INSERT INTO public.notifications (user_id, kind, title, message)
  VALUES (
    v_inviter_id,
    'link',
    'Your friend is in!',
    'Your link has been redeemed. A new collection slot is ready for you.'
  );
END;
$function$;

-- Refactored ticket-side trigger. The previous version checked
-- "is this user's first ticket"; that gate is gone — the helper
-- short-circuits on already-redeemed invites, so re-firing on later
-- tickets is a no-op.
CREATE OR REPLACE FUNCTION public.fire_link_on_first_ticket()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_invite_id uuid;
BEGIN
  SELECT i.id
    INTO v_invite_id
    FROM public.invites i
   WHERE i.claimed_by = NEW.user_id
     AND i.redeemed_at IS NULL
     AND i.revoked_at IS NULL
   ORDER BY i.claimed_at DESC NULLS LAST
   LIMIT 1;

  IF v_invite_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM public.fire_invite_redemption(v_invite_id);
  RETURN NEW;
END;
$function$;

-- Invitee-already-has-tickets path. Fires when claim_invite stamps
-- claimed_by. If the user already has a ticket, the ticket-side
-- trigger has nothing to fire on for them, so we redeem here instead.
CREATE OR REPLACE FUNCTION public.fire_link_on_invite_claim()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Only act when claimed_by transitions to a real user (NULL → uid).
  IF NEW.claimed_by IS NULL THEN
    RETURN NEW;
  END IF;
  IF OLD.claimed_by IS NOT DISTINCT FROM NEW.claimed_by THEN
    RETURN NEW;
  END IF;

  -- Already has tickets → redeem on the spot.
  IF EXISTS (
    SELECT 1 FROM public.tickets WHERE user_id = NEW.claimed_by
  ) THEN
    PERFORM public.fire_invite_redemption(NEW.id);
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS invites_fire_link_on_claim ON public.invites;
CREATE TRIGGER invites_fire_link_on_claim
AFTER UPDATE OF claimed_by ON public.invites
FOR EACH ROW
EXECUTE FUNCTION public.fire_link_on_invite_claim();
